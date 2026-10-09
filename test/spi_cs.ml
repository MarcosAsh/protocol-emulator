open! Core

module Mode = struct
  type t =
    { cpol : bool
    ; cpha : bool
    }
  [@@deriving sexp_of, equal]

  let of_int n = { cpol = n land 2 <> 0; cpha = n land 1 <> 0 }
  let to_int { cpol; cpha } = (Bool.to_int cpol * 2) + Bool.to_int cpha
  let all = List.init 4 ~f:of_int
end

let mosi_pin = Firmware.mosi_pin
let sck_pin = Firmware.sck_pin
let cs_pin = sck_pin + 1
let miso_pin = Firmware.miso_pin
let last = 0x100

let config =
  { Firmware.spi_config with side_set_count = 2; autopush = true; push_threshold = 8 }
;;

let shortest_half = 4
let shortest_setup = 3
let longest_setup = 30
let shortest_hold = 7
let longest_hold = 36

(* Side-set is SCK in bit 0 and CS in bit 1. Each wait carries the levels the pins already
   have, so every edge is the instruction after a wait. CPHA 0 puts a byte's first bit on
   MOSI before its leading edge, and its last trailing edge leaves MOSI be. The eighth
   [in] autopushes. *)
let master ~(mode : Mode.t) ~half_period ~setup ~hold ~deselect =
  if setup < shortest_setup || setup > longest_setup
  then raise_s [%message "BUG: setup out of range" (setup : int)];
  if hold < shortest_hold || hold > longest_hold
  then raise_s [%message "BUG: hold out of range" (hold : int)];
  if deselect > 248 then raise_s [%message "BUG: deselect out of range" (deselect : int)];
  let idle = Bool.to_int mode.cpol in
  let active = 1 - idle in
  let deselected = 2 lor idle in
  (* CS high [deselect] cycles from its rise, when the 9 back to idle are short: no loop,
     which would hide the time from the kernel's spacing, but adds of up to 31 through x *)
  let rest_while_deselected =
    if deselect <= 9
    then ""
    else (
      let parts = (deselect + 30) / 31 in
      let part = deselect / parts in
      let rec small n = if n = 0 then [] else Int.min n 7 :: small (n - Int.min n 7) in
      [ "    mov t, now"; [%string "    set x, %{part#Int}"] ]
      @ List.init parts ~f:(fun _ -> "    add t, x")
      @ List.map (small (deselect - (parts * part))) ~f:(sprintf "    add t, %d")
      @ [ "    wait t" ]
      |> List.map ~f:(fun line -> [%string "%{line} side %{deselected#Int}\n"])
      |> String.concat)
  in
  let first, leading, trailing, last_trailing =
    if mode.cpha
    then "nop", "out pins, 1", "in pins, 1", "in pins, 1"
    else "out pins, 1", "in pins, 1", "out pins, 1", "nop"
  in
  [%string
    {|
    .side_set 2
    set p, %{half_period#Int} side %{deselected#Int}
idle:
    wait tx side %{deselected#Int}
    pull side %{deselected#Int}
    out y, 8 side %{deselected#Int}        ; nonzero: CS rises after this byte
    set x, %{setup + 1#Int} side %{deselected#Int}
    mov t, now side %{deselected#Int}
    add t, x side %{deselected#Int}
    %{first} side %{idle#Int}              ; CS falls
    set x, 6 side %{idle#Int}
bit:
    wait t+ side %{idle#Int}
    %{leading} side %{active#Int}          ; leading edge
    wait t+ side %{active#Int}
    %{trailing} side %{idle#Int}           ; trailing edge
    jmp x--, bit
    wait t+ side %{idle#Int}
    %{leading} side %{active#Int}
    wait t+ side %{active#Int}
    %{last_trailing} side %{idle#Int}
    set x, %{hold - 5#Int} side %{idle#Int}
    jmp y--, deselect
    wait tx side %{idle#Int}               ; CS held for the next byte
    pull side %{idle#Int}
    out y, 8 side %{idle#Int}
    %{first} side %{idle#Int}
    set x, 6 side %{idle#Int}
    mov t, now side %{idle#Int}
    add t, p side %{idle#Int}
    jmp bit
deselect:
    mov t, now side %{idle#Int}
    add t, x side %{idle#Int}
    wait t side %{idle#Int}
    nop side %{deselected#Int}             ; CS rises
%{rest_while_deselected}    jmp idle
|}]
;;

let words bytes =
  List.mapi bytes ~f:(fun i byte ->
    if i = List.length bytes - 1 then byte lor last else byte)
;;

module Device = struct
  type t =
    { mode : Mode.t
    ; first : int
    ; cs : int
    ; sck : int
    ; miso : int
    ; bits : int
    ; shift_in : int
    ; shift_out : int
    ; frame : int list
    ; frames : int list list
    ; cycle : int
    ; cs_edge : int
    ; sck_edge : int option
    ; measured : Measured.t
    ; violations : string list
    }

  let create ~mode ~first =
    { mode
    ; first
    ; cs = 1
    ; sck = Bool.to_int mode.cpol
    ; miso = 1
    ; bits = 0
    ; shift_in = 0
    ; shift_out = 0
    ; frame = []
    ; frames = []
    ; cycle = 0
    ; cs_edge = 0
    ; sck_edge = None
    ; measured = Measured.empty
    ; violations = []
    }
  ;;

  let miso t = t.miso
  let frames t = List.rev t.frames
  let measured t = t.measured
  let violations t = List.rev t.violations

  let violate t why =
    { t with violations = [%string "%{why} at %{t.cycle#Int}"] :: t.violations }
  ;;

  let measure t name cycles =
    { t with measured = Measured.add t.measured ~name ~ns:cycles }
  ;;

  (* at a byte's start: [first], or the complement of the byte just taken *)
  let load t =
    match t.frame with
    | [] -> { t with shift_out = t.first }
    | byte :: _ -> { t with shift_out = lnot byte land 0xff }
  ;;

  let shift_out t =
    let t = if t.bits % 8 = 0 then load t else t in
    { t with
      miso = (t.shift_out lsr 7) land 1
    ; shift_out = (t.shift_out lsl 1) land 0xff
    }
  ;;

  let sample t ~mosi =
    let shift_in = (t.shift_in lsl 1) lor mosi land 0xff in
    let bits = t.bits + 1 in
    if bits % 8 = 0
    then { t with bits; shift_in = 0; frame = shift_in :: t.frame }
    else { t with bits; shift_in }
  ;;

  let select t =
    let t =
      if List.is_empty t.frames then t else measure t "CS high" (t.cycle - t.cs_edge)
    in
    let t = { t with cs = 0; cs_edge = t.cycle; bits = 0; frame = []; sck_edge = None } in
    if t.mode.cpha then t else shift_out t
  ;;

  let deselect t =
    let t =
      match t.sck_edge with
      | None -> violate t "a frame with no SCK edge"
      | Some edge -> measure t "hold" (t.cycle - edge)
    in
    let t = if t.bits % 8 <> 0 then violate t "CS rose inside a byte" else t in
    let t = measure t "CS low" (t.cycle - t.cs_edge) in
    { t with cs = 1; cs_edge = t.cycle; miso = 1; frames = List.rev t.frame :: t.frames }
  ;;

  let clock t ~sck ~mosi =
    let leading = sck <> Bool.to_int t.mode.cpol in
    let t =
      match t.sck_edge with
      | None -> measure t "setup" (t.cycle - t.cs_edge)
      | Some edge -> measure t (if sck = 1 then "SCK low" else "SCK high") (t.cycle - edge)
    in
    let t = { t with sck; sck_edge = Some t.cycle } in
    match leading, t.mode.cpha with
    | true, false | false, true -> sample t ~mosi
    | true, true -> shift_out t
    | false, false -> shift_out t
  ;;

  let step t ~cs ~sck ~mosi =
    let t = { t with cycle = t.cycle + 1 } in
    let t =
      match t.cs, cs with
      | 1, 0 -> select t
      | 0, 1 -> deselect t
      | _ -> t
    in
    if sck = t.sck
    then t
    else if cs = 1
    then violate { t with sck } "SCK moved with CS high"
    else clock t ~sck ~mosi
  ;;
end
