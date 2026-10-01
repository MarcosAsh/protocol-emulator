open! Core
open Protocol_emulator

let pin = 5
let cycle_ns = 20

(* [zero_high] at most 31, and [bit] between [2 * zero_high] and [3 * zero_high]: what the
   firmware can be written for; whether it holds its deadlines is the kernel's to say. [t]
   is the next rise on entry to [bit]; three deadlines on from it is past the next, so the
   tail comes off in steps of the largest immediate. *)
let firmware ~zero_high ~bit =
  let tail = (3 * zero_high) - bit in
  if zero_high < 1 || zero_high > 31 || tail < 0 || tail > zero_high
  then raise_s [%message "BUG: no such bit" (zero_high : int) (bit : int)];
  let subs =
    List.init ((tail + 6) / 7) ~f:(fun i -> Int.min 7 (tail - (7 * i)))
    |> List.map ~f:(sprintf "    sub t, %d")
    |> String.concat ~sep:"\n"
  in
  [%string
    {|
    mov t, now
    set pins, 0
    set p, %{zero_high#Int}
frame:
    wait tx
    pull
    set x, 15
    mov t, now
    add t, p
bit:
    wait t+
    set pins, 1              ; rise
    wait t+
    out pins, 1              ; a zero falls here
    wait t+
    set pins, 0              ; a one falls here
%{subs}
    jmp x--, bit
    set y, 7
gap:
    wait t+
    jmp y--, gap             ; low between frames
    jmp frame
|}]
;;

let dshot600 = firmware ~zero_high:31 ~bit:83
let dshot1200 = firmware ~zero_high:16 ~bit:42

let config =
  { Program_config.default with
    out_base = pin
  ; out_count = 1
  ; set_base = pin
  ; set_count = 1
  ; out_shift = Left
  }
;;

let checksum value = value lxor (value lsr 4) lxor (value lsr 8) land 0xf

let frame ~throttle ~telemetry =
  if throttle < 0 || throttle >= 1 lsl 11
  then raise_s [%message "BUG: throttle is 11 bits" (throttle : int)];
  let value = (throttle lsl 1) lor Bool.to_int telemetry in
  (value lsl 4) lor checksum value
;;

module Rate = struct
  type t =
    { bit_ns : int
    ; zero_high_ns : int
    ; one_high_ns : int
    }
  [@@deriving sexp_of]

  let dshot600 = { bit_ns = 1667; zero_high_ns = 625; one_high_ns = 1250 }
  let dshot1200 = { bit_ns = 833; zero_high_ns = 313; one_high_ns = 625 }
end

let runs levels =
  List.group levels ~break:Bool.( <> )
  |> List.map ~f:(fun run -> List.hd_exn run, List.length run)
;;

let decode (rate : Rate.t) ~cycle_ns levels =
  let open Or_error.Let_syntax in
  let within ns ~nominal ~name =
    if abs (ns - nominal) * 20 <= nominal
    then return ()
    else Or_error.error_s [%message "out of spec" name (ns : int) (nominal : int)]
  in
  (* each high with the low after it, in ns; a frame ends at a long low or the end *)
  let pulses =
    List.drop_while (runs levels) ~f:(fun (level, _) -> not level)
    |> List.chunks_of ~length:2
    |> List.map ~f:(function
      | [ (_, high); (_, low) ] -> high * cycle_ns, Some (low * cycle_ns)
      | [ (_, high) ] -> high * cycle_ns, None
      | _ -> raise_s [%message "BUG: chunks of two"])
  in
  let frames =
    List.group pulses ~break:(fun (_, low) _ ->
      Option.value_map low ~default:true ~f:(fun low -> low > 2 * rate.bit_ns))
  in
  let%bind decoded =
    List.fold_result
      frames
      ~init:([], Measured.empty)
      ~f:(fun (decoded, measured) frame ->
        let%bind () =
          if List.length frame = 16
          then return ()
          else Or_error.error_s [%message "not 16 bits" (List.length frame : int)]
        in
        let%bind bits, measured =
          List.foldi
            frame
            ~init:(return ([], measured))
            ~f:(fun i acc (high, low) ->
              let%bind bits, measured = acc in
              let one = high * 2 > rate.zero_high_ns + rate.one_high_ns in
              let name, nominal =
                if one then "T1H", rate.one_high_ns else "T0H", rate.zero_high_ns
              in
              let%bind () = within high ~nominal ~name in
              let measured = Measured.add measured ~name ~ns:high in
              match low with
              | Some low when i < 15 ->
                let%map () = within (high + low) ~nominal:rate.bit_ns ~name:"bit" in
                one :: bits, Measured.add measured ~name:"bit" ~ns:(high + low)
              | _ -> return (one :: bits, measured))
        in
        let word =
          List.fold (List.rev bits) ~init:0 ~f:(fun w b -> (w lsl 1) lor Bool.to_int b)
        in
        let value = word lsr 4 in
        let%map () =
          if checksum value = word land 0xf
          then return ()
          else Or_error.error_s [%message "checksum" (word : Int.Hex.t)]
        in
        (value lsr 1, value land 1 = 1) :: decoded, measured)
  in
  let frames, measured = decoded in
  return (List.rev frames, measured)
;;
