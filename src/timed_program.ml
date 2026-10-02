open! Core

type t =
  { source : string
  ; program : Asm.Program.t
  ; config : Program_config.t
  ; words : int list
  ; rows : Analyser.Row.t list
  ; verdict : Analyser.Verdict.t
  }
[@@deriving sexp_of, fields ~getters]

module Fault = struct
  type t =
    { line : int
    ; pc : int option
    ; reason : string
    }
  [@@deriving sexp_of]
end

module Refusal = struct
  type t =
    { faults : Fault.t list
    ; verdict : Analyser.Verdict.t option
    ; error : Error.t
    }
  [@@deriving sexp_of]
end

let cycles n = [%string "%{n#Int} %{if n = 1 then \"cycle\" else \"cycles\"}"]

(* For a deadline wait that is the only wait in the innermost loop round it, a [jmp] or
   [jmp x--] back over a straight run: the cycles a pass takes and what it adds to [t].
   Once late the wait does not stall, so a pass that takes more than it adds leaves it
   that much later each time round. A [jmp x--] reached with x zero never jumps back, so
   closes no loop. *)
let late_pass ~(config : Program_config.t) (rows : Analyser.Row.t list) ~pc =
  let open Option.Let_syntax in
  let known (i : Interval.t) =
    match i.lo, i.hi with
    | Some lo, Some hi when lo = hi -> Some lo
    | _ -> None
  in
  let%bind first, last =
    List.find_map rows ~f:(fun row ->
      let round target = Option.some_if (target <= pc && row.pc >= pc) (target, row.pc) in
      match row.instruction with
      | Jmp { cond = Always; target } -> round target
      | Jmp { cond = X_dec; target }
        when not ([%equal: Interval.t] row.x (Interval.exactly 0)) -> round target
      | Jmp _ | Op _ -> None)
  in
  let at = Map.of_alist_exn (module Int) (List.map rows ~f:(fun row -> row.pc, row)) in
  (* a fractional period carries a cycle into some of the steps and not others *)
  let p (row : Analyser.Row.t) =
    Option.bind (known row.period) ~f:(fun p ->
      Option.some_if (config.period_fraction = 0) p)
  in
  let pass (row : Analyser.Row.t) =
    match row.instruction with
    | _ when row.pc = config.wrap_top -> None
    | Jmp { cond = Always | X_dec; _ } -> None
    | Jmp { target; _ } ->
      Option.some_if (target < first || target > last) (Isa.jmp_cycles, 0)
    | Op { op; delay; _ } ->
      let cycles = 1 + delay in
      (match op with
       | Wait (Deadline { advance }) when row.pc = pc ->
         if advance then Option.map (p row) ~f:(fun p -> cycles, p) else Some (cycles, 0)
       | Wait _ | Sys Halt -> None
       | Alu { dest = T; op = (Add | Sub) as op; operand } ->
         let%map amount =
           match operand with
           | Imm n -> Some n
           | Reg P -> p row
           | Reg Y -> known row.y
           | Reg (X | Isr | Osr) -> None
         in
         ( cycles
         , (match op with
            | Sub -> -amount
            | Add | Xor -> amount) )
       | Alu { dest = T; op = Xor; _ } | Mov { dest = T; _ } | Out { dest = T; _ } -> None
       | _ -> Some (cycles, 0))
  in
  let%map passes =
    List.range first last
    |> List.map ~f:(fun b -> Option.bind (Map.find at b) ~f:pass)
    |> Option.all
  in
  ( List.sum (module Int) passes ~f:fst + Isa.jmp_cycles
  , List.sum (module Int) passes ~f:snd )
;;

let analyser_reason ~config rows (row : Analyser.Row.t) =
  match row.slack with
  | Some slack ->
    let late =
      match slack.lo with
      | Some lo when lo >= 0 ->
        [%string
          "more than half the timer early, which the wait reads as passed (slack \
           %{Interval.to_string slack})"]
      | Some lo -> [%string "%{cycles (-lo)} late (slack %{Interval.to_string slack})"]
      | None when row.slope < 0 -> "late"
      | None ->
        (match late_pass ~config rows ~pc:row.pc, slack.hi with
         | Some (takes, moves), _ when takes > moves ->
           [%string
             "late, as a pass of its loop takes %{cycles takes} and moves the deadline \
              by %{moves#Int}, so the wait falls %{cycles (takes - moves)} further \
              behind each pass"]
         | _, Some hi when hi < 0 -> [%string "%{cycles (-hi)} or more late"]
         | _ -> "late, by more on each pass of a loop or after an untimed wait")
    in
    (* a counted loop's slope is less the cycles it falls behind on each pass *)
    let drift =
      if row.slope < 0
      then [%string ", as its loop falls %{cycles (-row.slope)} further behind each pass"]
      else ""
    in
    [%string "this deadline wait can be reached %{late}%{drift}"]
  | None ->
    [%string
      "this out may autopull data within %{cycles (Isa.data_settle - 1)} of the data \
       pointer moving"]
;;

(* the assembler tags an error with its line, which the fault has already *)
let assembler_reason error =
  match Error.sexp_of_t error with
  | List [ List (Atom "line" :: _); Atom what ] -> what
  | List [ List (Atom "line" :: _); List (Atom what :: detail) ] ->
    String.concat ~sep:" " (what :: List.map detail ~f:Sexp.to_string_hum)
  | sexp -> Sexp.to_string_hum sexp
;;

let kernel_reason fails =
  [%string
    "the analyser passed this row, and the kernel refuses it: %{String.concat ~sep:\", \
     \" fails}"]
;;

let check ?period ?period_floor ?single_capture_edge ~config source =
  let open Result.Let_syntax in
  let%bind program, lines =
    Asm.assemble_with_lines source
    |> Result.map_error ~f:(fun errors ->
      { Refusal.faults =
          List.map errors ~f:(fun (line, error) ->
            { Fault.line; pc = None; reason = assembler_reason error })
      ; verdict = None
      ; error =
          (match errors with
           | [ (_, error) ] -> error
           | errors -> Error.of_list (List.map errors ~f:snd))
      })
  in
  let fault pc reason = { Fault.line = List.nth_exn lines pc; pc = Some pc; reason } in
  let configured = Asm.Program.configure program config in
  let rows =
    Analyser.analyse
      ?period
      ?period_floor
      ?single_capture_edge
      ~config:configured
      program.instructions
  in
  let%bind verdict =
    Analyser.check ?period ?period_floor ?single_capture_edge ~config program
    |> Result.map_error ~f:(fun error ->
      { Refusal.faults =
          List.filter_map rows ~f:(fun row ->
            Option.some_if
              (row.may_miss || row.may_underrun)
              (fault row.pc (analyser_reason ~config:configured rows row)))
      ; verdict = None
      ; error
      })
  in
  let refused ~faults error = { Refusal.faults; verdict = Some verdict; error } in
  let%bind words =
    Asm.Program.words program |> Result.map_error ~f:(refused ~faults:[])
  in
  let table = Kernel.Table.of_analyser rows in
  let kernel period =
    Kernel.check ?period ?single_capture_edge ~config:configured ~words table
    |> Result.map_error ~f:(fun error ->
      ( Kernel.rejections ?period ?single_capture_edge ~config:configured ~words table
      , error ))
  in
  (* A load enters [accepts] only as a value some row's period interval must hold, so the
     loads it accepts are an interval, and a floor needs only its two ends;
     test_self_check.ml proves every load between by checked SAT. *)
  let%map () =
    (match period_floor with
     | None -> kernel period |> Result.map_error ~f:List.return
     | Some floor ->
       Result.combine_errors_unit
         [ kernel (Some floor); kernel (Some ((1 lsl Isa.data_bits) - 1)) ])
    |> Result.map_error ~f:(fun refusals ->
      let faults =
        List.concat_map refusals ~f:(fun (rejections, _) ->
          List.map rejections ~f:(fun ({ pc; fails } : Kernel.Rejection.t) -> pc, fails))
        |> List.Assoc.sort_and_group ~compare:Int.compare
        |> List.map ~f:(fun (pc, fails) ->
          List.concat fails
          |> List.dedup_and_sort ~compare:String.compare
          |> kernel_reason
          |> fault pc)
      in
      refused ~faults (Error.of_list (List.map refusals ~f:snd)))
  in
  { source; program; config = configured; words; rows; verdict }
;;

let of_source_exn ?period ?period_floor ?single_capture_edge ~config source =
  match check ?period ?period_floor ?single_capture_edge ~config source with
  | Ok t -> t
  | Error { faults = _; verdict = _; error } -> Error.raise error
;;
