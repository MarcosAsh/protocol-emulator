open! Core
open Protocol_emulator
module Reg = Host_port.Reg

let certify
  m
  ~(watch @ local)
  ~(assumptions : System_lockstep.Assumptions.t)
  ~config
  program
  =
  let loaded = System_lockstep.Assumptions.loaded assumptions in
  Spi_master.write m ~watch Reg.data_addr [ 0 ];
  Spi_master.write
    m
    ~watch
    Reg.data
    (System_lockstep.Assumptions.certificate assumptions ~config program);
  Spi_master.write m ~watch Reg.check_base [ 0 ];
  Spi_master.write m ~watch Reg.check_loaded [ Option.value loaded ~default:0 ];
  Spi_master.write
    m
    ~watch
    Reg.check_flags
    [ Bool.to_int (Option.is_some loaded)
      lor (Bool.to_int assumptions.single_capture_edge lsl 1)
      lor (Bool.to_int (Option.is_some assumptions.period_floor) lsl 2)
    ];
  Spi_master.write m ~watch Reg.control [ 0x10 ];
  let status () = List.hd_exn (Spi_master.read m ~watch Reg.check_status ~count:1) in
  let rec settle () =
    let status = status () in
    if status land 1 = 1 then settle () else status
  in
  let status = settle () in
  if status land 0b100 = 0
  then (
    let pc = Spi_master.read m ~watch Reg.reject_pc ~count:1 in
    let reason = Spi_master.read m ~watch Reg.reject_reason ~count:1 in
    raise_s
      [%message
        "the load checker refused the program" (pc : int list) (reason : int list)])
;;
