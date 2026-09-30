open! Core
open Pio

(* One state machine at a divider of 1, from RP2040 datasheet chapter 3, after the
   verifier's pioemu.py. Side-set lands on an instruction's first cycle, its data writes
   on the cycle it completes, side-set winning a tie (3.2.4, 3.5.1, 3.5.6). The machine
   reads its own outputs 4 cycles late through the synchronisers (3.5.6.1). *)

module Edge = struct
  type t =
    { pin : string
    ; rising : bool
    ; time : int
    ; own : bool (** The machine changed its drive, not another driver letting go. *)
    }
end

module Setup = struct
  type t =
    { pull_threshold : int
    ; push_threshold : int
    ; shift_left : bool
    ; exec : (int * Pioasm.Instruction.t) list (** What [out exec] runs, by word. *)
    ; tx : int Sequence.t option (** The TX words, in order; random when [None]. *)
    }

  let default =
    { pull_threshold = 32; push_threshold = 32; shift_left = false; exec = []; tx = None }
  ;;
end

type kind =
  | Push_pull
  | Open_drain (** High when the direction bit is set, as [Dir]. *)
  | Open_drain_low (** Low when the direction bit is set, as [Dir_low]. *)

type control =
  | Next
  | Jump of int
  | Exec of Pioasm.Instruction.t
  | Halt

let mask32 = 0xFFFF_FFFF

let reverse32 value =
  List.init 32 ~f:Fn.id
  |> List.fold ~init:0 ~f:(fun acc bit ->
    if value land (1 lsl bit) <> 0 then acc lor (1 lsl (31 - bit)) else acc)
;;

let run
  ?(setup = Setup.default)
  (config : Timing.Config.t)
  (program : Pioasm.Program.t)
  ~seed
  ~cycles
  =
  let rng = Random.State.make [| seed |] in
  let chance p = Float.( < ) (Random.State.float rng 1.) p in
  let is_output (pin : Timing.Pin.t) =
    List.exists pin.bindings ~f:(fun (_, drive) ->
      match drive with
      | Level | Dir | Dir_low -> true
      | Input -> false)
  in
  let outputs = List.filter config.pins ~f:is_output |> Array.of_list in
  let count = Array.length outputs in
  let kind =
    Array.map outputs ~f:(fun pin ->
      List.fold pin.bindings ~init:Push_pull ~f:(fun kind (_, drive) ->
        match drive with
        | Dir -> Open_drain
        | Dir_low -> Open_drain_low
        | Level | Input -> kind))
  in
  let level = Array.create ~len:count false in
  let dir = Array.create ~len:count false in
  let held = Array.create ~len:count false in
  Array.iteri outputs ~f:(fun i pin ->
    let high = Option.value pin.initial ~default:(Random.State.bool rng) in
    match kind.(i) with
    | Push_pull -> level.(i) <- high
    | Open_drain -> dir.(i) <- high
    | Open_drain_low -> dir.(i) <- not high);
  let pad i =
    match kind.(i) with
    | Push_pull -> level.(i)
    | Open_drain -> dir.(i) && not held.(i)
    | Open_drain_low -> (not dir.(i)) && not held.(i)
  in
  let pads () = Array.init count ~f:pad in
  let history = Queue.of_list (List.init 4 ~f:(fun _ -> pads ())) in
  let may_stretch =
    Array.map outputs ~f:(fun pin ->
      not (List.mem config.no_stretch pin.name ~equal:String.equal))
  in
  let stretch = List.random_element_exn ~random_state:rng [ 3; 40 ] in
  let external_inputs = Hashtbl.create (module String) in
  let read (pin_ref : Timing.Pin_ref.t) =
    let own =
      Array.findi outputs ~f:(fun _ pin ->
        List.exists pin.bindings ~f:(fun (bound, drive) ->
          Timing.Pin_ref.equal bound pin_ref
          &&
          match drive with
          | Input -> true
          | Level | Dir | Dir_low -> false))
    in
    match own with
    | Some (i, _) -> (Queue.peek_exn history).(i)
    | None ->
      Hashtbl.find_or_add
        external_inputs
        (Sexp.to_string (Timing.Pin_ref.sexp_of_t pin_ref))
        ~default:(fun () -> Random.State.bool rng)
  in
  let pc =
    ref
      (Option.bind config.entry ~f:(fun label ->
         List.Assoc.find program.labels label ~equal:String.equal)
       |> Option.value ~default:0)
  in
  let x = ref (Random.State.bits rng) in
  let y = ref (Random.State.bits rng) in
  let osr = ref 0 in
  let osr_count = ref 32 in
  let isr = ref 0 in
  let isr_count = ref 0 in
  let tx = Queue.create () in
  let tx_words = ref setup.tx in
  let rx = ref 0 in
  let irq = Array.create ~len:8 false in
  let delay = ref 0 in
  let stalling = ref false in
  let latch = ref None in
  let halted = ref false in
  let touched = Array.create ~len:count false in
  let edges = Queue.create () in
  let next_word () =
    match !tx_words with
    | None -> Some (Random.State.bits rng lor (Random.State.bits rng lsl 30) land mask32)
    | Some words ->
      (match Sequence.next words with
       | None -> None
       | Some (word, rest) ->
         tx_words := Some rest;
         Some word)
  in
  let environment () =
    if Queue.length tx < 4 && (config.fifo_ready || chance 0.3)
    then Option.iter (next_word ()) ~f:(Queue.enqueue tx);
    if config.fifo_ready || (!rx > 0 && chance 0.3) then rx := 0;
    Array.iteri irq ~f:(fun i flag -> if chance 0.02 then irq.(i) <- not flag);
    Hashtbl.map_inplace external_inputs ~f:(fun value ->
      if chance 0.05 then not value else value);
    (* Another driver holds a released open-drain pin low only once it is low, as a
       stretching slave does. *)
    Array.iteri outputs ~f:(fun i _ ->
      match kind.(i) with
      | Push_pull -> ()
      | (Open_drain | Open_drain_low) when not may_stretch.(i) -> ()
      | Open_drain | Open_drain_low ->
        if held.(i)
        then (if chance (1. /. Float.of_int stretch) then held.(i) <- false)
        else if (not (pad i)) && chance 0.3
        then held.(i) <- true)
  in
  let apply writes =
    List.iter writes ~f:(fun (pin_ref, to_dir, value) ->
      Array.iteri outputs ~f:(fun i pin ->
        List.iter pin.bindings ~f:(fun (bound, drive) ->
          if Timing.Pin_ref.equal bound pin_ref
          then (
            match drive, to_dir with
            | Level, false ->
              if not (Bool.equal level.(i) value) then touched.(i) <- true;
              level.(i) <- value
            | (Dir | Dir_low), true ->
              if not (Bool.equal dir.(i) value) then touched.(i) <- true;
              dir.(i) <- value
            | (Level | Dir | Dir_low | Input), _ -> ()))))
  in
  let group ~count ~make ~to_dir value =
    List.init count ~f:(fun bit -> make bit, to_dir, value land (1 lsl bit) <> 0)
  in
  let out_pins ~to_dir value =
    group ~count:config.out_count ~make:(fun i -> Timing.Pin_ref.Out i) ~to_dir value
  in
  let refill () =
    if config.autopull && !osr_count >= setup.pull_threshold && not (Queue.is_empty tx)
    then (
      osr := Queue.dequeue_exn tx;
      osr_count := 0)
  in
  let pins_value () =
    List.init 32 ~f:Fn.id
    |> List.fold ~init:0 ~f:(fun acc bit ->
      if read (In bit) then acc lor (1 lsl bit) else acc)
  in
  let source (source : Pioasm.Source.t) =
    match source with
    | Pins -> pins_value ()
    | X -> !x
    | Y -> !y
    | Null -> 0
    | Status -> if Random.State.bool rng then mask32 else 0
    | Isr -> !isr
    | Osr -> !osr
  in
  let exec_of value =
    match List.Assoc.find setup.exec (value land 0xFFFF) ~equal:Int.equal with
    | Some instruction -> Exec instruction
    | None -> raise_s [%message "no exec table entry" (value : int)]
  in
  let destination (destination : Pioasm.Destination.t) value ~bits =
    match destination with
    | Pins -> out_pins ~to_dir:false value, Next
    | Pindirs -> out_pins ~to_dir:true value, Next
    | X ->
      x := value;
      [], Next
    | Y ->
      y := value;
      [], Next
    | Null -> [], Next
    | Isr ->
      isr := value;
      isr_count := bits;
      [], Next
    | Osr ->
      osr := value;
      osr_count := 0;
      [], Next
    | Pc -> [], Jump (value land 31)
    | Exec -> [], exec_of value
  in
  let stall = `Stall in
  let execute (instruction : Pioasm.Instruction.t) =
    (match instruction.op with
     | Out _ -> ()
     | _ -> refill ());
    match instruction.op with
    | Jmp { condition; target } ->
      let taken =
        match condition with
        | Always -> true
        | X_zero -> !x = 0
        | Y_zero -> !y = 0
        | X_post_decrement ->
          let taken = !x <> 0 in
          x := (!x - 1) land mask32;
          taken
        | Y_post_decrement ->
          let taken = !y <> 0 in
          y := (!y - 1) land mask32;
          taken
        | X_not_y -> !x <> !y
        | Pin -> read Jmp_pin
        | Osr_not_empty -> !osr_count < setup.pull_threshold
      in
      `Done ([], if taken then Jump target else Next)
    | Wait { polarity; source } ->
      (match source with
       | Irq index ->
         if Bool.equal irq.(index land 7) polarity
         then (
           if polarity then irq.(index land 7) <- false;
           `Done ([], Next))
         else stall
       | Pin index ->
         if Bool.equal (read (In index)) polarity then `Done ([], Next) else stall
       | Gpio index ->
         if Bool.equal (read (Gpio index)) polarity then `Done ([], Next) else stall
       | Jmp_pin -> if Bool.equal (read Jmp_pin) polarity then `Done ([], Next) else stall)
    | In { source = from; bits } ->
      if config.autopush
         && Int.min 32 (!isr_count + bits) >= setup.push_threshold
         && !rx >= 4
         && not config.fifo_ready
      then stall
      else (
        let value = source from land if bits = 32 then mask32 else (1 lsl bits) - 1 in
        isr
        := if bits = 32
           then value
           else if setup.shift_left
           then (!isr lsl bits) lor value land mask32
           else (!isr lsr bits) lor (value lsl (32 - bits));
        isr_count := Int.min 32 (!isr_count + bits);
        if config.autopush && !isr_count >= setup.push_threshold
        then (
          incr rx;
          isr := 0;
          isr_count := 0);
        `Done ([], Next))
    | Out { destination = into; bits } ->
      if config.autopull && !osr_count >= setup.pull_threshold
      then (
        refill ();
        stall)
      else (
        let value, rest =
          if bits = 32
          then !osr, 0
          else if setup.shift_left
          then !osr lsr (32 - bits), (!osr lsl bits) land mask32
          else !osr land ((1 lsl bits) - 1), !osr lsr bits
        in
        osr := rest;
        osr_count := Int.min 32 (!osr_count + bits);
        refill ();
        `Done (destination into value ~bits))
    | Push { if_full; block } ->
      if if_full && !isr_count < setup.push_threshold
      then `Done ([], Next)
      else if !rx >= 4 && not config.fifo_ready
      then
        if block
        then stall
        else (
          isr := 0;
          isr_count := 0;
          `Done ([], Next))
      else (
        incr rx;
        isr := 0;
        isr_count := 0;
        `Done ([], Next))
    | Pull { if_empty; block } ->
      if (if_empty && !osr_count < setup.pull_threshold)
         || (config.autopull && !osr_count = 0)
      then `Done ([], Next)
      else if Queue.is_empty tx
      then
        if block
        then stall
        else (
          osr := !x;
          osr_count := 0;
          `Done ([], Next))
      else (
        osr := Queue.dequeue_exn tx;
        osr_count := 0;
        `Done ([], Next))
    | Mov { destination = into; op; source = from } ->
      let value = source from in
      let value =
        match op with
        | Copy -> value
        | Invert -> lnot value land mask32
        | Reverse -> reverse32 value
      in
      (match into with
       | Isr ->
         isr := value;
         isr_count := 0;
         `Done ([], Next)
       | into -> `Done (destination into value ~bits:32))
    | Irq { mode; index } ->
      let index = index land 7 in
      (match mode with
       | Clear ->
         irq.(index) <- false;
         `Done ([], Next)
       | Raise ->
         irq.(index) <- true;
         `Done ([], Next)
       | Raise_and_wait when config.irq_wait_halts -> `Done ([], Halt)
       | Raise_and_wait ->
         if not !stalling
         then (
           irq.(index) <- true;
           stall)
         else if irq.(index)
         then stall
         else `Done ([], Next))
    | Set { destination = into; value } ->
      let set ~to_dir =
        group ~count:config.set_count ~make:(fun i -> Timing.Pin_ref.Set i) ~to_dir value
      in
      (match into with
       | Pins -> `Done (set ~to_dir:false, Next)
       | Pindirs -> `Done (set ~to_dir:true, Next)
       | X ->
         x := value;
         `Done ([], Next)
       | Y ->
         y := value;
         `Done ([], Next)
       | Null | Pc | Isr | Osr | Exec -> raise_s [%message "bad set"])
  in
  let machine_cycle () =
    if !delay > 0
    then (
      decr delay;
      refill ())
    else (
      let instruction, from_exec =
        match !latch with
        | Some instruction -> instruction, true
        | None -> program.instructions.(!pc), false
      in
      let side =
        match instruction.side with
        | Some value when not !stalling ->
          group
            ~count:program.side_set.count
            ~make:(fun i -> Timing.Pin_ref.Side i)
            ~to_dir:program.side_set.pindirs
            value
        | Some _ | None -> []
      in
      match execute instruction with
      | `Stall ->
        stalling := true;
        apply side
      | `Done (data, control) ->
        stalling := false;
        apply data;
        apply side;
        if from_exec then latch := None;
        (match control with
         | Exec executee -> latch := Some executee
         | Jump target ->
           pc := target;
           delay := instruction.delay
         | Next ->
           pc := if !pc = program.wrap then program.wrap_target else !pc + 1;
           delay := instruction.delay
         | Halt -> halted := true))
  in
  let time = ref 0 in
  let before = ref (pads ()) in
  while (not !halted) && !time < cycles do
    environment ();
    Array.fill touched ~pos:0 ~len:count false;
    machine_cycle ();
    let after = pads () in
    Array.iteri outputs ~f:(fun i pin ->
      if not (Bool.equal !before.(i) after.(i))
      then
        Queue.enqueue
          edges
          { Edge.pin = pin.name; rising = after.(i); time = !time + 1; own = touched.(i) });
    ignore (Queue.dequeue_exn history : bool array);
    Queue.enqueue history after;
    before := after;
    incr time
  done;
  Queue.to_list edges
;;
