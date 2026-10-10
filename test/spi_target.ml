open! Core
open Protocol_emulator

module Pins = struct
  type t =
    { mosi : int
    ; sck : int
    ; cs : int
    ; miso : int
    }
end

let pads = { Pins.mosi = 1; sck = 2; cs = 3; miso = Isa.first_output_pin }

let config (pins : Pins.t) =
  if pins.sck <> pins.mosi + 1
  then raise_s [%message "BUG: SCK has to follow MOSI" (pins.mosi : int) (pins.sck : int)];
  { Program_config.default with
    in_base = pins.mosi
  ; in_count = 2
  ; out_base = pins.miso
  ; out_count = 1
  ; set_base = pins.miso
  ; set_count = 1
  ; jmp_pin = pins.cs
  ; in_shift = Left
  ; out_shift = Left
  ; autopush = true
  ; push_threshold = 8
  }
;;

let shortest_half = 14

(* the next reply into y *)
let fetch label =
  [%string
    {|
    jmp !tx, none_%{label}
    pull
    mov y, osr               ; the next reply
    jmp got_%{label}
none_%{label}:
    mov y, !null             ; none queued: 0xff
got_%{label}:|}]
;;

(* Between bytes, x reads MOSI in bit 0 and SCK in bit 1, so x is 2 or more while SCK is
   high: [lead] at the next byte's leading edge, [deselected] once CS rises. *)
let gap ~(mode : Spi_cs.Mode.t) =
  if mode.cpol
  then
    {|
gap:
    jmp pin, deselected      ; CS high: the frame is over
    mov x, pins
    jmp x--, gap_one
    jmp lead                 ; SCK low
gap_one:
    jmp x--, gap             ; SCK high, idle still
    jmp lead|}
  else
    {|
gap:
    jmp pin, deselected      ; CS high: the frame is over
    mov x, pins
    jmp x--, gap_one
    jmp gap                  ; SCK low, idle still
gap_one:
    jmp x--, lead            ; SCK high
    jmp gap|}
;;

(* CPHA 0 shows a byte's first bit before its leading edge, so the next reply's first bit
   goes out as a byte ends, and again at the next select should CS rise instead *)
let firmware ~(mode : Spi_cs.Mode.t) (pins : Pins.t) =
  let leading = Bool.to_int (not mode.cpol) in
  let trailing = 1 - leading in
  let sck = pins.sck
  and cs = pins.cs in
  let select =
    [%string
      {|
deselected:
    set pins, 0              ; MISO let go
    wait 1 pin %{cs#Int}
    wait 0 pin %{cs#Int}             ; selected
    mov isr, null            ; no bits from before, a byte cut short or another program's
    mov osr, y               ; this byte's reply|}]
  in
  if mode.cpha
  then
    [%string
      {|%{fetch "first"}%{select}
    set x, 7
bit:
    wait %{leading#Int} pin %{sck#Int}             ; leading edge
    out pins, 1
    wait %{trailing#Int} pin %{sck#Int}             ; trailing edge
    in pins, 1               ; the eighth pushes the byte
    jmp x--, bit
%{fetch "next"}
    mov osr, y%{gap ~mode}
lead:
    out pins, 1
    set x, 6
    wait %{trailing#Int} pin %{sck#Int}
    in pins, 1
    jmp bit
|}]
  else
    [%string
      {|%{fetch "first"}%{select}
    out pins, 1              ; its first bit, before the leading edge
    set x, 6
bit:
    wait %{leading#Int} pin %{sck#Int}             ; leading edge
    in pins, 1
    wait %{trailing#Int} pin %{sck#Int}             ; trailing edge
    out pins, 1
    jmp x--, bit
    wait %{leading#Int} pin %{sck#Int}
    in pins, 1               ; the eighth pushes the byte
%{fetch "next"}
    wait %{trailing#Int} pin %{sck#Int}
    mov osr, y
    out pins, 1              ; the next reply's first bit, should the frame go on%{gap ~mode}
lead:
    in pins, 1
    set x, 5
    wait %{trailing#Int} pin %{sck#Int}
    out pins, 1
    jmp bit
|}]
;;

let protocol =
  { Protocol.name = "spi_target"
  ; certified =
      List.map Spi_cs.Mode.all ~f:(fun mode ->
        Certified.plain
          [%string "spi_target_mode%{Spi_cs.Mode.to_int mode#Int}"]
          (firmware ~mode pads)
          (config pads))
  ; time_triggered = []
  ; bench = []
  ; loaded_from_hex = []
  ; limits = []
  ; unlimited = []
  ; swept = []
  ; not_swept =
      List.map Spi_cs.Mode.all ~f:(fun mode ->
        ( [%string "spi_target_mode%{Spi_cs.Mode.to_int mode#Int}"]
        , "a target: the controller's clock moves it" ))
  ; scenarios = []
  ; decoded = []
  }
;;
