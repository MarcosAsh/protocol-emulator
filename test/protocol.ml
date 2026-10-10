open! Core
open Hardcaml
open Protocol_emulator
open Pin_trace
module Reg = Host_port.Reg

type t =
  { name : string
  ; certified : Certified.t list
  ; time_triggered : Certified.t list
  ; bench : Bench.t list
  ; loaded_from_hex : Bench.t list
  ; limits : Datasheet.t list
  ; unlimited : (string * string) list
  ; swept : Swept.t list
  ; not_swept : (string * string) list
  ; scenarios : Pin_trace.Scenario.t list
  ; decoded : Pin_trace.Scenario.t list
  }

let configured (c : Certified.t) =
  let program = Asm.assemble c.source |> ok_exn in
  let config = Asm.Program.configure program c.config in
  ( Engine.Config.of_program_config config
    |> Engine.Config.map ~f:Bits.to_unsigned_int
    |> Engine.Config.to_list
  , Asm.Program.words program |> ok_exn )
;;

(* what [Scenario.load] wrote: the config registers in order, then the program *)
let loaded (scenario : Scenario.t) =
  let is_config reg = List.mem Reg.configs reg ~equal:Int.equal in
  ( List.filter_map scenario.script ~f:(function
      | Write (reg, [ value ]) when is_config reg -> Some value
      | _ -> None)
  , List.find_map scenario.script ~f:(function
      | Write (reg, words) when reg = Reg.program -> Some words
      | _ -> None) )
;;

let firmware t (scenario : Scenario.t) =
  let loaded = loaded scenario in
  List.find (t.certified @ t.time_triggered) ~f:(fun c ->
    let config, words = configured c in
    [%equal: int list * int list option] loaded (config, Some words))
;;

(* the configuration the registers hold, which [Scenario.load] wrote *)
let of_registers values : Program_config.t =
  let c =
    let rest = ref values in
    Engine.Config.map Engine.Config.port_names ~f:(fun _ ->
      match !rest with
      | value :: tail ->
        rest := tail;
        value
      | [] -> raise_s [%message "BUG: too few config registers" (values : int list)])
  in
  let bool v = v <> 0 in
  let shift v : Program_config.Shift_direction.t = if bool v then Right else Left in
  let config : Program_config.t =
    { side_set_count = c.side_set_count
    ; side_set_base = c.side_set_base
    ; side_set_pindirs = bool c.side_set_pindirs
    ; in_base = c.in_base
    ; in_count = c.in_count
    ; out_base = c.out_base
    ; out_count = c.out_count
    ; set_base = c.set_base
    ; set_count = c.set_count
    ; jmp_pin = c.jmp_pin
    ; capture_pin = c.capture_pin
    ; capture_rising = bool c.capture_rising
    ; in_shift = shift c.in_shift_right
    ; out_shift = shift c.out_shift_right
    ; autopush = bool c.autopush
    ; push_threshold = c.push_threshold
    ; autopull = bool c.autopull
    ; pull_threshold = c.pull_threshold
    ; crc_width = c.crc_width
    ; crc_poly = c.crc_poly
    ; crc_init = c.crc_init
    ; crc_reflect = bool c.crc_reflect
    ; stuff_threshold = c.stuff_threshold
    ; stuff_level = bool c.stuff_level
    ; wrap_bottom = c.wrap_bottom
    ; wrap_top = c.wrap_top
    ; period_fraction = c.period_fraction
    ; autopull_data = bool c.autopull_data
    ; manchester = bool c.manchester
    }
  in
  let written =
    Engine.Config.of_program_config config
    |> Engine.Config.map ~f:Bits.to_unsigned_int
    |> Engine.Config.to_list
  in
  if not ([%equal: int list] written values)
  then raise_s [%message "BUG: the registers do not read back" (values : int list)];
  config
;;

(* The script against the engine's own cycles, from the start: each tx word with the cycle
   it may go in from, the levels [Drive] puts on a pin, and the cycles it runs. *)
module Plan = struct
  type t =
    { tx : (int * int) list
    ; driven : (int * (int * int)) list
    ; cycles : int
    }

  let of_script script =
    let started = ref false in
    let plan =
      List.fold script ~init:{ tx = []; driven = []; cycles = 0 } ~f:(fun plan step ->
        match (step : Step.t) with
        | Write (reg, [ 1 ]) when reg = Reg.control ->
          started := true;
          plan
        | Write (reg, words) when reg = Reg.tx ->
          { plan with
            tx = List.rev_map words ~f:(fun word -> plan.cycles, word) @ plan.tx
          }
        | Write (reg, _)
          when (not !started)
               && (reg = Reg.program_addr
                   || reg = Reg.program
                   || List.mem Reg.configs reg ~equal:Int.equal) -> plan
        | Write (reg, words) ->
          raise_s
            [%message
              "a host write the lockstep does not make" (reg : int) (words : int list)]
        | Read _ -> plan
        | Run n -> { plan with cycles = plan.cycles + n }
        | Until n -> { plan with cycles = Int.max plan.cycles n }
        | Drive { pin; levels } ->
          { plan with
            driven =
              List.rev_mapi levels ~f:(fun i level -> plan.cycles + i, (pin, level))
              @ plan.driven
          ; cycles = plan.cycles + List.length levels
          })
    in
    { plan with tx = List.rev plan.tx; driven = List.rev plan.driven }
  ;;
end

let lockstep (scenario : Scenario.t) =
  let config, program =
    match loaded scenario with
    | values, Some program -> of_registers values, program
    | _, None -> raise_s [%message "the scenario loads no program" scenario.name]
  in
  let plan = Plan.of_script scenario.script in
  let peer = scenario.peer () in
  let driven = Int.Table.of_alist_exn plan.driven in
  let model = ref None
  and tx = ref plan.tx
  and received = ref [] in
  let inputs n =
    let levels = peer.inputs () in
    match Hashtbl.find driven n with
    | None -> levels
    | Some (pin, level) -> levels land lnot (1 lsl pin) lor (level lsl pin)
  in
  let host n =
    let fifo f = Option.value_map !model ~default:0 ~f:(fun m -> List.length (f m)) in
    let push =
      match !tx with
      | (from, word) :: rest
        when from <= n && fifo (fun (m : Machine.t) -> m.tx_fifo) < Machine.fifo_depth ->
        tx := rest;
        Some word
      | _ -> None
    in
    let pop_rx = fifo (fun (m : Machine.t) -> m.rx_fifo) > 0 in
    if pop_rx
    then
      Option.iter (Option.bind !model ~f:Machine.read_rx) ~f:(fun (word, _) ->
        received := word :: !received);
    { Lockstep.Host.idle with tx = push; pop_rx }
  in
  let react (m : Machine.t) =
    model := Some m;
    peer.step ~pin_out:m.pin_out ~pin_dir:m.pin_dir
  in
  let (_ : Machine.t) =
    Lockstep.lockstep ~cycles:plan.cycles ~host ~react ~config ~program ~inputs ()
  in
  List.rev !received
;;
