open! Core
open! Hardcaml
open! Signal

module I = struct
  type 'a t =
    { clock : 'a
    ; men : 'a
    ; wen : 'a
    ; ren : 'a
    ; addr : 'a [@bits Isa.pc_bits]
    ; din : 'a [@bits Isa.word_bits]
    ; bm : 'a [@bits Isa.word_bits]
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { dout : 'a [@bits Isa.word_bits] } [@@deriving hardcaml]
end

let create (scope : Scope.t) (i : Signal.t I.t) =
  let spec = Reg_spec.create ~clock:i.clock () in
  let%hw write = i.men &: i.wen in
  let%hw read = i.men &: i.ren in
  let write_data = wire Isa.word_bits in
  let stored =
    multiport_memory
      (1 lsl Isa.pc_bits)
      ~write_ports:
        [| { write_clock = i.clock
           ; write_address = i.addr
           ; write_enable = write
           ; write_data
           }
        |]
      ~read_addresses:[| i.addr |]
  in
  let%hw stored = stored.(0) in
  let%hw merged = stored &: ~:(i.bm) |: (i.din &: i.bm) in
  write_data <-- merged;
  let%hw dout = reg spec ~enable:read (mux2 write merged stored) in
  { O.dout }
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"program_memory" create i
;;
