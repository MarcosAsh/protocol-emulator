open! Core

(* what the rest of the library still lists in [Certified], [Bench] and [Datasheet] *)
let rest =
  { Protocol.name = "rest"
  ; certified = Certified.others
  ; time_triggered = []
  ; bench = Bench.others
  ; loaded_from_hex = []
  ; limits = Datasheet.others
  ; unlimited = Datasheet.exempt
  ; scenarios = []
  }
;;

let protocols = [ Uart.protocol; Spi.protocol; I2c.protocol; rest; Spi_cs.protocol ]
let each f = List.concat_map protocols ~f
let certified = each (fun p -> p.certified)
let time_triggered = each (fun p -> p.time_triggered)
let stamped = Uart.stamped

let find_certified_exn name =
  match
    List.find
      ((stamped :: certified) @ time_triggered)
      ~f:(fun t -> String.equal t.name name)
  with
  | Some t -> t
  | None -> raise_s [%message "no such firmware" (name : string)]
;;

let bench = each (fun p -> p.bench)

let find_bench_exn name =
  match
    List.find
      (each (fun p -> p.loaded_from_hex) @ bench)
      ~f:(fun t -> String.equal t.name name)
  with
  | Some t -> t
  | None -> raise_s [%message "no such bench firmware" (name : string)]
;;

let limits = each (fun p -> p.limits)
let exempt = each (fun p -> p.unlimited)
let scenarios = each (fun p -> p.scenarios)
