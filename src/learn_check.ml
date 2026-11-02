open! Core

module Crc_model = struct
  type t =
    { width : int
    ; poly : int
    ; init : int
    ; xorout : int
    ; start : int
    ; check_lsb_first : bool
    ; init_known : bool
    }
  [@@deriving sexp_of, equal]
end

let crc ~width ~poly ~init bits =
  Array.fold bits ~init ~f:(fun crc bit ->
    Crc.step ~width ~poly ~reflect:false crc ~bit:(Bool.to_int bit))
;;

let mask width = (1 lsl width) - 1

(* Only catalogue entries whose init and final XOR read the same either way round, so the
   name does not hang on how a reflected model states them. RevEng's catalogue. *)
let catalogue =
  [ "CRC-16/MODBUS", 16, 0x8005, 0xffff, true, 0
  ; "CRC-16/ARC", 16, 0x8005, 0, true, 0
  ; "CRC-16/USB", 16, 0x8005, 0xffff, true, 0xffff
  ; "CRC-16/MAXIM-DOW", 16, 0x8005, 0, true, 0xffff
  ; "CRC-16/UMTS", 16, 0x8005, 0, false, 0
  ; "CRC-16/IBM-3740", 16, 0x1021, 0xffff, false, 0
  ; "CRC-16/XMODEM", 16, 0x1021, 0, false, 0
  ; "CRC-16/GSM", 16, 0x1021, 0, false, 0xffff
  ; "CRC-16/KERMIT", 16, 0x1021, 0, true, 0
  ; "CRC-16/IBM-SDLC", 16, 0x1021, 0xffff, true, 0xffff
  ; "CRC-16/MCRF4XX", 16, 0x1021, 0xffff, true, 0
  ; "CRC-8/SMBUS", 8, 0x07, 0, false, 0
  ; "CRC-8/ROHC", 8, 0x07, 0xff, true, 0
  ; "CRC-8/MAXIM-DOW", 8, 0x31, 0, true, 0
  ; "CRC-8/AUTOSAR", 8, 0x2f, 0xff, false, 0xff
  ; "CRC-8/OPENSAFETY", 8, 0x2f, 0, false, 0
  ; "CRC-8/SAE-J1850", 8, 0x1d, 0xff, false, 0xff
  ; "CRC-8/GSM-A", 8, 0x1d, 0, false, 0
  ; "CRC-8/HITAG", 8, 0x1d, 0xff, false, 0
  ; "CRC-8/TECH-3250", 8, 0x1d, 0xff, true, 0
  ; "CRC-8/CDMA2000", 8, 0x9b, 0xff, false, 0
  ; "CRC-8/LTE", 8, 0x9b, 0, false, 0
  ; "CRC-8/WCDMA", 8, 0x9b, 0, true, 0
  ; "CRC-8/DVB-S2", 8, 0xd5, 0, false, 0
  ; "CRC-8/BLUETOOTH", 8, 0xa7, 0, true, 0
  ]
;;

module Rule = struct
  type t =
    | Inverse of
        { source : int
        ; target : int
        }
    | Xor of
        { first : int
        ; target : int
        }
    | Sum of
        { first : int
        ; target : int
        ; lsb_first : bool
        ; negate : bool
        }
    | Crc of Crc_model.t
  [@@deriving sexp_of, equal]

  (* A CRC over LSB-first bytes is reflected, and its check reads reflected when sent the
     other way round to the bytes. *)
  let crc_name ~lsb_first (m : Crc_model.t) =
    let refout = Bool.( <> ) lsb_first m.check_lsb_first in
    List.find_map catalogue ~f:(fun (name, width, poly, init, reflect, xorout) ->
      Option.some_if
        (width = m.width
         && poly = m.poly
         && init = m.init
         && xorout = m.xorout
         && Bool.equal reflect lsb_first
         && Bool.equal reflect refout
         && m.start = 0)
        name)
  ;;

  let to_string ~lsb_first = function
    | Inverse { source; target } -> sprintf "byte %d = ~byte %d" target source
    | Xor { first; target } ->
      sprintf "byte %d = xor of bytes %d..%d" target first (target - 1)
    | Sum { first; target; lsb_first; negate } ->
      sprintf
        "byte %d = %ssum of bytes %d..%d (%s first)"
        target
        (if negate then "-" else "")
        first
        (target - 1)
        (if lsb_first then "LSB" else "MSB")
    | Crc m ->
      let hex v = sprintf "0x%0*x" ((m.width + 3) / 4) v in
      sprintf
        "crc-%d poly %s init %s%s xorout %s over bits %d.., check sent %s first%s"
        m.width
        (hex m.poly)
        (hex m.init)
        (if m.init_known then "" else " (with xorout, from frames of one length)")
        (hex m.xorout)
        m.start
        (if m.check_lsb_first then "low bit" else "high bit")
        (match crc_name ~lsb_first m with
         | Some name -> sprintf ", which is %s" name
         | None -> "")
  ;;

  let targets t ~frame_bits =
    match t with
    | Inverse { target; _ } | Xor { target; _ } | Sum { target; _ } ->
      List.init 8 ~f:(fun i -> (8 * target) + i)
    | Crc m -> List.init m.width ~f:(fun i -> frame_bits - m.width + i)
  ;;
end

module Evidence = struct
  type t =
    { bits : int
    ; hypotheses : float
    }
  [@@deriving sexp_of]
end

let byte_of ~lsb_first bits ~at =
  List.init 8 ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun acc i ->
    let bit = Bool.to_int bits.((8 * at) + i) in
    if lsb_first then acc lor (bit lsl i) else (acc lsl 1) lor bit)
;;

let bytes ~lsb_first bits =
  Array.init (Array.length bits / 8) ~f:(fun at -> byte_of ~lsb_first bits ~at)
;;

let write_byte ~lsb_first bits ~at value =
  for i = 0 to 7 do
    let bit = if lsb_first then (value lsr i) land 1 else (value lsr (7 - i)) land 1 in
    bits.((8 * at) + i) <- bit = 1
  done
;;

let check_value (m : Crc_model.t) bits =
  let n = Array.length bits in
  List.init m.width ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun acc i ->
    let bit = Bool.to_int bits.(n - m.width + i) in
    if m.check_lsb_first then acc lor (bit lsl i) else (acc lsl 1) lor bit)
;;

let covered (m : Crc_model.t) bits =
  Array.sub bits ~pos:m.start ~len:(Array.length bits - m.width - m.start)
;;

let crc_of (m : Crc_model.t) bits =
  crc ~width:m.width ~poly:m.poly ~init:m.init (covered m bits) lxor m.xorout
;;

let sum bytes ~first ~target =
  List.range first target |> List.fold ~init:0 ~f:(fun acc i -> acc + bytes.(i))
;;

let apply_one bits (rule : Rule.t) =
  let n = Array.length bits in
  match rule with
  | Inverse { source; target } ->
    write_byte
      ~lsb_first:true
      bits
      ~at:target
      (lnot (byte_of ~lsb_first:true bits ~at:source) land 0xff)
  | Xor { first; target } ->
    let b = bytes ~lsb_first:true bits in
    write_byte
      ~lsb_first:true
      bits
      ~at:target
      (List.range first target |> List.fold ~init:0 ~f:(fun acc i -> acc lxor b.(i)))
  | Sum { first; target; lsb_first; negate } ->
    let b = bytes ~lsb_first bits in
    let s = sum b ~first ~target in
    write_byte ~lsb_first bits ~at:target ((if negate then -s else s) land 0xff)
  | Crc m ->
    let value = crc_of m bits in
    for i = 0 to m.width - 1 do
      let bit =
        if m.check_lsb_first
        then (value lsr i) land 1
        else (value lsr (m.width - 1 - i)) land 1
      in
      bits.(n - m.width + i) <- bit = 1
    done
;;

let apply rules frame =
  let bits = Array.copy frame in
  List.iter rules ~f:(apply_one bits);
  bits
;;

let holds rules frame = Array.equal Bool.equal (apply rules frame) frame

(* Rows reduced over GF(2), each a bool array: how many are independent. *)
let rank rows =
  let rows = List.map rows ~f:Array.copy |> Array.of_list in
  let n = if Array.is_empty rows then 0 else Array.length rows.(0) in
  let rank = ref 0 in
  for column = 0 to n - 1 do
    match
      Array.find_mapi rows ~f:(fun i row -> Option.some_if (i >= !rank && row.(column)) i)
    with
    | None -> ()
    | Some pivot ->
      let p = rows.(pivot) in
      rows.(pivot) <- rows.(!rank);
      rows.(!rank) <- p;
      Array.iteri rows ~f:(fun i row ->
        if i <> !rank && row.(column)
        then Array.iteri row ~f:(fun j b -> row.(j) <- Bool.( <> ) b p.(j)));
      incr rank
  done;
  !rank
;;

let xor_bits a b = Array.map2_exn a b ~f:Bool.( <> )
let log2 x = Float.log x /. Float.log 2.
let margin = 12
let crc_widths = [ 16; 8 ]
let crc_starts = [ 0; 8; 16 ]

(* Every CRC the search tries, counted once whatever the frames, so the evidence asked of
   a match does not shrink with the frames. *)
let crc_hypotheses =
  List.sum (module Int) crc_widths ~f:(fun w ->
    (1 lsl (w - 1)) * List.length crc_starts * 2)
  |> Float.of_int
;;

let enough ~bits ~hypotheses =
  Float.( >= ) (Float.of_int bits) (log2 hypotheses +. Float.of_int margin)
;;

(* Inverse pairs: a byte the other inverted in every frame, the source taking more than
   one value so the pair is not two constants. *)
let inverses frames =
  let b = List.map frames ~f:(bytes ~lsb_first:true) in
  let count = Array.length (List.hd_exn b) in
  let hypotheses = Float.of_int (count * count) in
  List.concat_map (List.range 0 count) ~f:(fun source ->
    List.filter_map
      (List.range (source + 1) count)
      ~f:(fun target ->
        let distinct =
          List.map b ~f:(fun b -> b.(source))
          |> List.dedup_and_sort ~compare
          |> List.length
        in
        let bits = 8 * distinct in
        Option.some_if
          (List.for_all b ~f:(fun b -> b.(target) = lnot b.(source) land 0xff)
           && enough ~bits ~hypotheses)
          (Rule.Inverse { source; target }, { Evidence.bits; hypotheses })))
;;

(* The last byte from the ones before it, from byte 0 or 1. *)
let sums frames =
  let count = Array.length (List.hd_exn frames) / 8 in
  let candidates =
    List.concat_map [ 0; 1 ] ~f:(fun first ->
      if count - first < 3
      then []
      else (
        let target = count - 1 in
        Rule.Xor { first; target }
        :: List.concat_map [ true; false ] ~f:(fun lsb_first ->
          List.map [ false; true ] ~f:(fun negate ->
            Rule.Sum { first; target; lsb_first; negate }))))
  in
  let hypotheses = Float.of_int (List.length candidates) in
  let bits = 8 * (List.length frames - 1) in
  List.filter_map candidates ~f:(fun rule ->
    Option.some_if
      (List.for_all frames ~f:(holds [ rule ]) && enough ~bits ~hypotheses)
      (rule, { Evidence.bits; hypotheses }))
;;

let undo_zero_step ~width ~poly crc =
  (* The register before a step that took a 0, for an odd polynomial: the low bit says
     whether the polynomial went in. *)
  let fed = crc land 1 = 1 in
  ((if fed then crc lxor poly else crc) lsr 1) lor (Bool.to_int fed lsl (width - 1))
;;

let init_and_xorout ~width ~poly ~length ~constant =
  let ones = mask width in
  let zeros = Array.create ~len:length false in
  let pairs = [ 0, 0; ones, 0; ones, ones; 0, ones ] in
  match
    List.find pairs ~f:(fun (init, xorout) ->
      crc ~width ~poly ~init zeros lxor xorout = constant)
  with
  | Some pair -> pair
  | None -> Fn.apply_n_times ~n:length (undo_zero_step ~width ~poly) constant, 0
;;

let crcs frames =
  let n = Array.length (List.hd_exn frames) in
  List.find_map crc_widths ~f:(fun width ->
    List.find_map crc_starts ~f:(fun start ->
      if n - width - start < 8
      then None
      else
        List.find_map [ false; true ] ~f:(fun check_lsb_first ->
          let model =
            { Crc_model.width
            ; poly = 0
            ; init = 0
            ; xorout = 0
            ; start
            ; check_lsb_first
            ; init_known = false
            }
          in
          let first = List.hd_exn frames in
          let data =
            List.map frames ~f:(fun f -> xor_bits (covered model f) (covered model first))
          in
          let checks =
            List.map frames ~f:(fun f -> check_value model f lxor check_value model first)
          in
          let independent = rank data in
          let bits = independent * width in
          if not (enough ~bits ~hypotheses:crc_hypotheses)
          then None
          else (
            let rows = List.zip_exn data checks in
            List.find_map
              (List.init (1 lsl (width - 1)) ~f:(fun i -> (2 * i) + 1))
              ~f:(fun poly ->
                if List.for_all rows ~f:(fun (d, c) -> crc ~width ~poly ~init:0 d = c)
                then (
                  let constant =
                    check_value model first
                    lxor crc ~width ~poly ~init:0 (covered model first)
                  in
                  let init, xorout =
                    init_and_xorout ~width ~poly ~length:(n - width - start) ~constant
                  in
                  Some
                    ( Rule.Crc { model with poly; init; xorout }
                    , { Evidence.bits; hypotheses = crc_hypotheses } ))
                else None)))))
;;

let find ~lsb_first:_ frames =
  let frames = List.dedup_and_sort frames ~compare:(Array.compare Bool.compare) in
  match frames with
  | [] -> []
  | first :: _ ->
    let n = Array.length first in
    if List.exists frames ~f:(fun f -> Array.length f <> n)
    then []
    else (
      let found = inverses frames in
      let last = (n / 8) - 1 in
      let last_taken =
        List.exists found ~f:(fun (rule, _) ->
          List.mem (Rule.targets rule ~frame_bits:n) (8 * last) ~equal)
      in
      let found =
        if last_taken || n < 24 then found else found @ List.take (sums frames) 1
      in
      if List.exists found ~f:(fun (rule, _) ->
           match rule with
           | Xor _ | Sum _ -> true
           | Inverse _ | Crc _ -> false)
         || last_taken
      then found
      else found @ Option.to_list (crcs frames))
;;
