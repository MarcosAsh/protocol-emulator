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
  ; pull_threshold = 8
  }
;;

let shortest_half = 16

(* the next reply into y, or 0xff with none queued; [preset] where y is 0xff already *)
let fetch ?(preset = false) label =
  let default =
    if preset then "" else "\n    mov y, !null             ; none queued: 0xff"
  in
  [%string
    {|%{default}
    jmp !tx, got_%{label}
    pull
    mov y, osr               ; the next reply
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

(* Inside a byte the same read finds the leading edge at [label]_edge, and CS rising cuts
   the byte short. SCK is tested first, so a poll that finds the edge there takes five
   cycles. With CPOL 1 the idle branch goes after the program, so both low readings fall
   through. *)
let poll ~(mode : Spi_cs.Mode.t) label =
  if mode.cpol
  then
    ( [%string
        {|
%{label}:
    mov x, pins
    jmp x--, %{label}_one
    jmp %{label}_edge          ; SCK low
%{label}_one:
    jmp x--, %{label}_idle
%{label}_edge:|}]
    , [%string
        {|
%{label}_idle:
    jmp pin, cut             ; SCK high, and CS high cuts the byte short
    jmp %{label}|}]
    )
  else
    ( [%string
        {|
%{label}:
    mov x, pins
    jmp x--, %{label}_one
    jmp pin, cut             ; SCK low, and CS high cuts the byte short
    jmp %{label}
%{label}_one:
    jmp x--, %{label}_edge     ; SCK high
    jmp pin, cut
    jmp %{label}
%{label}_edge:|}]
    , "" )
;;

(* [osr] counts the byte's bits out, so x is free for the polls. A byte cut short goes
   back to [cut], which drops the bits it took and takes the next reply. CPHA 0 shows a
   byte's first bit before its leading edge, so the next reply's first bit goes out as a
   byte ends, and again at the next select should CS rise instead. *)
let firmware ~(mode : Spi_cs.Mode.t) (pins : Pins.t) =
  let leading = Bool.to_int (not mode.cpol) in
  let trailing = 1 - leading in
  let sck = pins.sck
  and cs = pins.cs in
  let select =
    [%string
      {|
cut:%{fetch "first"}
deselected:
    set pins, 0              ; MISO let go
    wait 1 pin %{cs#Int}
    wait 0 pin %{cs#Int}             ; selected
    mov isr, null            ; no bits from before, a byte cut short or another program's
    mov osr, y               ; this byte's reply|}]
  in
  let bit, bit_idle = poll ~mode "bit" in
  if mode.cpha
  then
    [%string
      {|%{select}%{gap ~mode}
lead:
    out pins, 1
    wait %{trailing#Int} pin %{sck#Int}             ; trailing edge
    in pins, 1%{bit}
    out pins, 1
    wait %{trailing#Int} pin %{sck#Int}
    in pins, 1               ; the eighth pushes the byte
    jmp !osre, bit%{fetch "next"}
    mov osr, y
    jmp gap%{bit_idle}
|}]
  else (
    let last, last_idle = poll ~mode "last" in
    [%string
      {|%{select}
    out pins, 1              ; its first bit, before the leading edge
    jmp gap%{bit}
    in pins, 1
    wait %{trailing#Int} pin %{sck#Int}             ; trailing edge
    out pins, 1
    jmp !osre, bit           ; to the seventh bit%{last}
    in pins, 1               ; the eighth pushes the byte%{fetch ~preset:true "next"}
    wait %{trailing#Int} pin %{sck#Int}
    mov osr, y
    out pins, 1              ; the next reply's first bit, should the frame go on%{gap ~mode}
lead:
    in pins, 1
    wait %{trailing#Int} pin %{sck#Int}
    out pins, 1
    mov y, !null             ; for the fetch after the eighth bit
    jmp bit%{bit_idle}%{last_idle}
|}])
;;

let fast_config (pins : Pins.t) =
  if pins.cs <> pins.mosi + 2
  then raise_s [%message "BUG: CS has to follow SCK" (pins.mosi : int) (pins.cs : int)];
  { (config pins) with in_count = 3 }
;;

let fast_shortest_half = 9

(* the next reply into osr, which is free once its eighth bit is out *)
let fetch_osr label =
  [%string
    {|
    mov osr, !null           ; none queued: 0xff
    jmp !tx, %{label}
    pull
%{label}:|}]
;;

(* Between bytes y holds MOSI, SCK and CS as they read with SCK idle, and the wrap polls
   them every three cycles. A change other than MOSI alone is a leading edge, or CS
   rising. The reply's first bit is shown by [mov pins, ::osr], so osr keeps the whole
   reply for a select that does not clock it. Each later bit goes out once the controller
   has sampled the one before, which leaves it a whole period to reach MISO. *)
let fast ~(mode : Spi_cs.Mode.t) (pins : Pins.t) =
  let leading = Bool.to_int (not mode.cpol) in
  let trailing = 1 - leading in
  let sample, shift = if mode.cpha then trailing, leading else leading, trailing in
  let sck = pins.sck
  and cs = pins.cs in
  let first =
    if mode.cpha
    then [%string {|
    wait %{sample#Int} pin %{sck#Int}
    in pins, 1|}]
    else {|
    in x, 1                  ; MOSI as the poll read it, at the leading edge|}
  in
  let idle_y = if mode.cpol then {|
    xor y, 2|} else "" in
  let idle =
    if mode.cpha then "" else [%string {|
    wait %{trailing#Int} pin %{sck#Int}|}]
  in
  [%string
    {|%{fetch_osr "start"}
    wait 1 pin %{cs#Int}             ; not part way into a frame
deselected:
    set pins, 0              ; MISO let go
    wait 0 pin %{cs#Int}             ; selected
    mov pins, ::osr          ; the reply's first bit
    mov isr, null
    in pins, 1
    mov y, isr               ; MOSI, with CS low and SCK idle, should SCK have moved%{idle_y}
    mov isr, null            ; no bits from before
.wrap_target
watch:
    mov x, pins
    jmp x!=y, changed
.wrap
changed:
    xor y, 1                 ; what MOSI moving alone reads
    jmp x!=y, edge
    jmp watch
edge:
    jmp pin, deselected      ; CS rose instead%{first}
    out null, 1              ; the first bit, shown already
    out pins, 1
    set x, 5
bit:
    wait %{shift#Int} pin %{sck#Int}
    wait %{sample#Int} pin %{sck#Int}
    in pins, 1
    out pins, 1              ; the next bit, once the controller has this one
    jmp x--, bit%{fetch_osr "fetched"}
    wait %{shift#Int} pin %{sck#Int}
    wait %{sample#Int} pin %{sck#Int}             ; the eighth
    in pins, 1               ; pushes the byte
    mov pins, ::osr          ; the next reply's first bit%{idle}
    mov y, pins
    jmp watch
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
      @ List.map Spi_cs.Mode.all ~f:(fun mode ->
        Certified.plain
          [%string "spi_target_fast_mode%{Spi_cs.Mode.to_int mode#Int}"]
          (fast ~mode pads)
          (fast_config pads))
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
      @ List.map Spi_cs.Mode.all ~f:(fun mode ->
        ( [%string "spi_target_fast_mode%{Spi_cs.Mode.to_int mode#Int}"]
        , "a target: the controller's clock moves it" ))
  ; scenarios = []
  ; decoded = []
  }
;;
