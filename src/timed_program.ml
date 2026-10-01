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

let analyser_reason (row : Analyser.Row.t) =
  match row.slack with
  | Some slack ->
    let late =
      match slack.lo with
      | Some lo -> [%string "%{cycles (-lo)} late (slack %{Interval.to_string slack})"]
      | None when row.slope < 0 -> "late"
      | None -> "late, by more on each pass of a loop or after an untimed wait"
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

let kernel_reason fails =
  [%string
    "the analyser passed this row, and the kernel refuses it: %{String.concat ~sep:\", \
     \" fails}"]
;;

let check ?period ?period_floor ?single_capture_edge ~config source =
  let open Result.Let_syntax in
  let%bind program, lines =
    Asm.assemble_with_lines source
    |> Result.map_error ~f:(fun (line, error) ->
      let reason =
        match Error.sexp_of_t error with
        | List [ List (Atom "line" :: _); List (Atom what :: detail) ] ->
          String.concat ~sep:" " (what :: List.map detail ~f:Sexp.to_string_hum)
        | sexp -> Sexp.to_string_hum sexp
      in
      { Refusal.faults = [ { line; pc = None; reason } ]; verdict = None; error })
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
              (fault row.pc (analyser_reason row)))
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
