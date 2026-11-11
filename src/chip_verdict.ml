open! Core

type t =
  | Accepted of { certificate : int list }
  | Refused of
      { certificate : int list
      ; rejection : Load_check.Rejection.t
      }
  | No_certificate of Error.t

let check ?period ?period_floor ~single_capture_edge ~config ~words rows =
  match Load_check.of_table ~config ~words (Kernel.Table.of_analyser rows) with
  | Error e -> No_certificate e
  | Ok certificate ->
    let certificate = Load_check.to_words certificate in
    let memory = Array.of_list certificate in
    (match
       Load_check.walk
         ?loaded:(Option.first_some period_floor period)
         ~floor:(Option.is_some period_floor)
         ~single_capture_edge
         ~config
         ~words
         ~memory:(fun at -> if at < Array.length memory then memory.(at) else 0)
         ~base:0
         ()
     with
     | Ok _ -> Accepted { certificate }
     | Error rejection -> Refused { certificate; rejection })
;;

let of_timed timed =
  check
    ?period:(Timed_program.period timed)
    ?period_floor:(Timed_program.period_floor timed)
    ~single_capture_edge:(Timed_program.single_capture_edge timed)
    ~config:(Timed_program.config timed)
    ~words:(Timed_program.words timed)
    (Timed_program.rows timed)
;;

let to_string = function
  | Accepted { certificate } ->
    sprintf
      "chip: its load check accepts the %d-word certificate"
      (List.length certificate)
  | Refused { rejection = { pc; reason }; _ } ->
    sprintf
      "chip: its load check refuses this at pc %d (%s), so the chip won't start it"
      pc
      reason
  | No_certificate e ->
    sprintf
      "chip: no certificate its load check can read, so the chip won't start it: %s"
      (Error.to_string_hum e)
;;
