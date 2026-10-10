open! Core

type t =
  { bench : Bench.t
  ; limits : Datasheet.t list
  ; stimulus : Datasheet.Stimulus.t option
  }

let bauds = [ 9600; 19200; 38400; 57600; 115200; 230400 ]

let uart =
  List.map bauds ~f:(fun baud ->
    let name = [%string "uart_tx_%{baud#Int}"] in
    let period = (Bench.clock_hz + (baud / 2)) / baud in
    { bench =
        { Bench.uart_log with
          name
        ; what =
            [%string
              "Firmware.uart_tx_host_rate: the host sends the bit period, %{period#Int} \
               cycles for %{Bench.rate ~unit:\"baud\" period}, on OUT0"]
        ; load = Some period
        }
    ; limits = Datasheet.uart ~baud name
    ; stimulus =
        Some { bursts = [ [ period; 0x55; 0x55 ] ]; quiet = 0; cycles = 25 * period }
    })
;;

let i2c =
  List.map
    [ "i2c_standard", Datasheet.I2c_mode.Standard, 121; "i2c_fast", Fast, 32 ]
    ~f:(fun (name, mode, quarter) ->
      let master = Bench.find_exn "i2c_master" in
      let quarters =
        match mode with
        | Standard -> 3
        | Fast -> 2
      in
      let words =
        let word = Firmware.i2c_word in
        [ quarter
        ; word ~start:true 0xa0
        ; word 0x00
        ; word ~stop:true 0x10
        ; word ~start:true 0xa0
        ; word 0x00
        ; word ~start:true 0xa1
        ; word ~read:true 0
        ; word ~read:true ~stop:true 0
        ]
      in
      { bench =
          { master with
            name
          ; what =
              [%string
                "Firmware.i2c_master_host_rate_held ~quarters:%{quarters#Int}: the host \
                 sends the quarter, %{quarter#Int} cycles for %{Bench.rate (4 * \
                 quarter)}, SDA on IO2, SCL on IO3"]
          ; source = Firmware.i2c_master_host_rate_held ~quarters ()
          ; load = Some quarter
          }
      ; limits = Datasheet.um10204 mode name
      ; stimulus = Some { bursts = [ words ]; quiet = 0; cycles = 100 * 4 * quarter }
      })
;;

let spi =
  List.map Spi_cs.Mode.all ~f:(fun mode ->
    let bench = Bench.find_exn [%string "spi_cs_mode%{Spi_cs.Mode.to_int mode#Int}"] in
    { bench
    ; limits = List.filter Datasheet.all ~f:(fun t -> String.equal t.firmware bench.name)
    ; stimulus = None
    })
;;

let all = uart @ i2c @ spi
let check t = Datasheet.check ~limits:t.limits ?stimulus:t.stimulus t.bench
