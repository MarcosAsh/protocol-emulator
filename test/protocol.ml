open! Core

type t =
  { name : string
  ; certified : Certified.t list
  ; time_triggered : Certified.t list
  ; bench : Bench.t list
  ; loaded_from_hex : Bench.t list
  ; limits : Datasheet.t list
  ; unlimited : (string * string) list
  ; scenarios : Pin_trace.Scenario.t list
  }
