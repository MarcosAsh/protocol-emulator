open! Core
open Protocol_emulator

type t =
  { k : float
  ; why : string
  ; place : Translate.Setup.t -> Translate.Setup.t
  }

let pin name =
  (List.find_exn Bench_wiring.all ~f:(fun (w : Bench_wiring.t) ->
     String.equal w.name name))
    .pin
;;

(* spi_cpha0_cs's side-set is SCK, then CSn *)
let () =
  if pin "OUT6" <> pin "OUT5" + 1
  then raise_s [%message "BUG: the carrier's flash CS is not the pin after its CLK"]
;;

let own_rate program = Option.value_exn (Census.real_time program)

let find (program : Pioasm.Program.t) =
  let only name (s : Translate.Setup.t) =
    { s with side_set_base = pin name; set_base = pin name; out_base = pin name }
  in
  match program.name with
  | "ws2812" ->
    Some { k = own_rate program; why = "ws2812.c's 800 kHz"; place = only "OUT3" }
  | "uart_tx" ->
    Some { k = own_rate program; why = "uart_tx.c's 115200 baud"; place = only "OUT0" }
  | "spi_cpha0_cs" ->
    Some
      { k = 12.
      ; why = "the 1 MHz SCK spi_flash.c runs spi_cpha0 at"
      ; place =
          (fun s ->
            { s with
              side_set_base = pin "OUT5"
            ; set_base = pin "OUT4"
            ; out_base = pin "OUT4"
            ; in_base = pin "IN0"
            ; jmp_pin = pin "IN0"
            })
      }
  | _ -> None
;;
