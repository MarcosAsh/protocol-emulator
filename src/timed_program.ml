open! Core

type t =
  { program : Asm.Program.t
  ; config : Program_config.t
  ; words : int list
  ; rows : Analyser.Row.t list
  ; verdict : Analyser.Verdict.t
  }
[@@deriving sexp_of, fields ~getters]

module Refusal = struct
  type t =
    { pcs : int list
    ; verdict : Analyser.Verdict.t option
    ; error : Error.t
    }
  [@@deriving sexp_of]
end

let check ?period ?period_floor ?single_capture_edge ~config (program : Asm.Program.t) =
  let open Result.Let_syntax in
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
      { Refusal.pcs =
          List.filter_map rows ~f:(fun row ->
            Option.some_if (row.may_miss || row.may_underrun) row.pc)
      ; verdict = None
      ; error
      })
  in
  let refused ~pcs error = { Refusal.pcs; verdict = Some verdict; error } in
  let%bind words = Asm.Program.words program |> Result.map_error ~f:(refused ~pcs:[]) in
  let table = Kernel.Table.of_analyser rows in
  let kernel period =
    Kernel.check ?period ?single_capture_edge ~config:configured ~words table
    |> Result.map_error ~f:(fun error ->
      let rejections =
        Kernel.rejections ?period ?single_capture_edge ~config:configured ~words table
      in
      refused
        ~pcs:
          (List.map rejections ~f:(fun (rejection : Kernel.Rejection.t) -> rejection.pc))
        error)
  in
  (* A load enters [accepts] only as a value some row's period interval must hold, so the
     loads it accepts are an interval, and a floor needs only its two ends;
     test_self_check.ml proves every load between by checked SAT. *)
  let%map () =
    match period_floor with
    | None -> kernel period
    | Some floor ->
      Result.combine_errors_unit
        [ kernel (Some floor); kernel (Some ((1 lsl Isa.data_bits) - 1)) ]
      |> Result.map_error ~f:(fun (refusals : Refusal.t list) ->
        refused
          ~pcs:
            (List.concat_map refusals ~f:(fun refusal -> refusal.pcs)
             |> List.dedup_and_sort ~compare:Int.compare)
          (Error.of_list (List.map refusals ~f:(fun refusal -> refusal.error))))
  in
  { program; config = configured; words; rows; verdict }
;;

let of_source_exn ?period ?period_floor ?single_capture_edge ~config source =
  let program = Asm.assemble source |> ok_exn in
  match check ?period ?period_floor ?single_capture_edge ~config program with
  | Ok t -> t
  | Error { pcs = _; verdict = _; error } -> Error.raise error
;;
