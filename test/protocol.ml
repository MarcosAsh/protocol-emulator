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
  let config, program = loaded scenario in
  match
    List.find (t.certified @ t.time_triggered) ~f:(fun c ->
      [%equal: int list option] (Some (snd (configured c))) program)
  with
  | None ->
    raise_s
      [%message "the scenario loads none of the protocol's firmware" scenario.name t.name]
  | Some c ->
    if not ([%equal: int list] (fst (configured c)) config)
    then
      raise_s
        [%message
          "the scenario loads its firmware under another configuration"
            scenario.name
            c.name];
    c
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

let lockstep t (scenario : Scenario.t) =
  let firmware = firmware t scenario in
  let config, program =
    let program = Asm.assemble firmware.source |> ok_exn in
    Asm.Program.configure program firmware.config, Asm.Program.words program |> ok_exn
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
