open! Core
open! Hardcaml

let shift_limit = 2 * Isa.data_bits
let shift_bits = Bits.num_bits_to_represent shift_limit

(* x and a count past 16 together *)
let sum_bits = Isa.data_bits + 1

module Row = struct
  type 'a t =
    { shifted_lo : 'a [@bits shift_bits]
    ; shifted_hi : 'a [@bits shift_bits]
    ; sum_lo : 'a [@bits sum_bits]
    ; sum_hi : 'a [@bits sum_bits]
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

module Holds = struct
  type 'a t =
    { shifted : 'a
    ; sum : 'a
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

module Ways = struct
  type 'a t =
    { next : 'a
    ; target : 'a
    }
  [@@deriving hardcaml]
end

module Conjuncts = struct
  type 'a t =
    { next : 'a Holds.t
    ; target : 'a Holds.t
    }
  [@@deriving hardcaml]
end

module Step = struct
  type 'a t =
    { next_shifted : 'a [@bits shift_bits]
    ; next_pulled : 'a
    ; takes : 'a
    }
  [@@deriving hardcaml]
end

module Make (Comb : Comb.S) = struct
  open Comb
  module Decoder = Decoder.Make (Comb)
  module Opcode = Isa.Opcode.Make_comb (Comb)
  module Jmp_cond = Isa.Jmp_cond.Make_comb (Comb)
  module Out_dest = Isa.Out_dest.Make_comb (Comb)
  module Mov_dest = Isa.Mov_dest.Make_comb (Comb)
  module Set_dest = Isa.Set_dest.Make_comb (Comb)
  module Alu_dest = Isa.Alu_dest.Make_comb (Comb)
  module Sys_op = Isa.Sys_op.Make_comb (Comb)

  (* wide enough for a sum and a count on top *)
  let wide_bits = sum_bits + 1
  let wide x = uresize x ~width:wide_bits
  let max a b = mux2 (a >: b) a b
  let min a b = mux2 (a <: b) a b

  module Class = struct
    type t =
      { out : Comb.t
      ; pull : Comb.t
      ; mov_osr : Comb.t
      ; count : Comb.t
      ; set_x : Comb.t
      ; set_value : Comb.t
      ; x_dec : Comb.t
      ; writes_x : Comb.t
      ; jump : Comb.t
      ; always : Comb.t
      ; halts : Comb.t
      }

    let of_word ~side_set_count word =
      let d = Decoder.decode ~side_set_count word in
      let is op = Opcode.is d.opcode op in
      let cond c = is Jmp &: Jmp_cond.is d.jmp_cond c in
      { out = is Out
      ; pull = is Sys &: Sys_op.is d.sys_op Pull
      ; mov_osr = is Mov &: Mov_dest.is d.mov_dest Osr
      ; count = uresize d.shift_count ~width:shift_bits
      ; set_x = is Set &: Set_dest.is d.set_dest X
      ; set_value = uresize d.set_value ~width:Isa.data_bits
      ; x_dec = cond X_dec
      ; writes_x =
          is Mov
          &: Mov_dest.is d.mov_dest X
          |: (is Out &: Out_dest.is d.out_dest X)
          |: (is Alu &: Alu_dest.is d.alu_dest X)
      ; jump = is Jmp
      ; always = cond Always
      ; halts = ~:(d.valid) |: (is Sys &: Sys_op.is d.sys_op Halt)
      }
    ;;
  end

  (* the core's [osr_count], which stops at 16 *)
  let count_of shifted =
    mux2
      (shifted >:. Isa.data_bits)
      (of_unsigned_int ~width:Isa.count_bits Isa.data_bits)
      (sel_bottom shifted ~width:Isa.count_bits)
  ;;

  let saturate v =
    mux2 (v >:. shift_limit) (of_unsigned_int ~width:(width v) shift_limit) v
  ;;

  let step ~side_set_count ~autopull ~pull_threshold ~word ~shifted ~pulled =
    let c = Class.of_word ~side_set_count word in
    let pull_now = c.out &: autopull &: (count_of shifted >=: pull_threshold) in
    let base = mux2 pull_now (zero shift_bits) shifted in
    { Step.next_shifted =
        mux2 c.out (sel_bottom (saturate (wide base +: wide c.count)) ~width:shift_bits)
        @@ mux2 (c.pull |: c.mov_osr) (zero shift_bits) shifted
    ; next_pulled = c.pull |: pull_now |: (pulled &: ~:(c.mov_osr))
    ; takes = c.pull |: pull_now
    }
  ;;

  let sum_max = ones sum_bits
  let is_empty (r : _ Row.t) = r.shifted_lo >: r.shifted_hi |: (r.sum_lo >: r.sum_hi)
  let sum_is_full (r : _ Row.t) = r.sum_lo ==:. 0 &: (r.sum_hi ==: sum_max)

  let is_full (r : _ Row.t) =
    r.shifted_lo
    ==:. 0
    &: (r.shifted_hi ==:. shift_limit)
    &: sum_is_full r
    &: ~:(r.pulled)
  ;;

  let image
    ~side_set_count
    ~autopull
    ~pull_threshold
    ~word
    ~x_lo
    ~x_hi
    ~(row : _ Row.t)
    ~taken
    =
    let c = Class.of_word ~side_set_count word in
    (* a counted jump is taken only with x at 1 or more *)
    let x_lo =
      if taken then mux2 (c.x_dec &: (x_lo ==:. 0)) (one Isa.data_bits) x_lo else x_lo
    in
    let x_lo = wide x_lo in
    let x_hi = wide x_hi in
    let sum_lo = wide row.sum_lo in
    let sum_hi = wide row.sum_hi in
    (* shifted is the sum less x *)
    let shifted_lo =
      max (wide row.shifted_lo) (mux2 (sum_lo >=: x_hi) (sum_lo -: x_hi) (zero wide_bits))
    in
    let shifted_hi =
      min
        (wide row.shifted_hi)
        (mux2 (sum_hi >=: x_lo) (sum_hi -: x_lo) (wide row.shifted_hi))
    in
    (* and falling through [jmp x--] leaves x at zero, where shifted is the sum *)
    let shifted_lo, shifted_hi =
      if taken
      then shifted_lo, shifted_hi
      else
        ( mux2 c.x_dec (max shifted_lo sum_lo) shifted_lo
        , mux2 c.x_dec (min shifted_hi sum_hi) shifted_hi )
    in
    let surely = autopull &: (count_of shifted_lo >=: pull_threshold) in
    let never = ~:autopull |: (count_of shifted_hi <: pull_threshold) in
    let n = wide c.count in
    let resets = c.pull |: c.mov_osr in
    let next_lo =
      mux2 c.out (saturate (mux2 never shifted_lo (zero wide_bits) +: n))
      @@ mux2 resets (zero wide_bits) shifted_lo
    in
    let next_hi =
      mux2 c.out (saturate (mux2 surely (zero wide_bits) shifted_hi +: n))
      @@ mux2 resets (zero wide_bits) shifted_hi
    in
    (* An out that keeps its word adds n to the sum, but where the count stops at the
       limit the sum is the limit and x. One that autopulls starts it again at x and n. *)
    let kept_lo =
      min (of_unsigned_int ~width:wide_bits shift_limit +: x_lo) (sum_lo +: n)
    in
    let kept_hi = sum_hi +: n in
    let fresh_lo = x_lo +: n in
    let fresh_hi = x_hi +: n in
    let out_lo = mux2 surely fresh_lo @@ mux2 never kept_lo (min kept_lo fresh_lo) in
    let out_hi = mux2 surely fresh_hi @@ mux2 never kept_hi (max kept_hi fresh_hi) in
    (* [jmp x--] takes one from x either way, from zero to 0xffff falling through *)
    let dec_lo, dec_hi =
      if taken
      then max sum_lo (one wide_bits) -:. 1, sum_hi -:. 1
      else (
        let wrapped = wide (ones Isa.data_bits) in
        shifted_lo +: wrapped, shifted_hi +: wrapped)
    in
    let set_value = wide c.set_value in
    let image_sum_lo =
      mux2 c.set_x (next_lo +: set_value)
      @@ mux2 c.x_dec dec_lo
      @@ mux2 resets x_lo
      @@ mux2 c.out out_lo sum_lo
    in
    let image_sum_hi =
      mux2 c.set_x (next_hi +: set_value)
      @@ mux2 c.x_dec dec_hi
      @@ mux2 resets x_hi
      @@ mux2 c.out out_hi sum_hi
    in
    let known = ~:(c.writes_x) &: (image_sum_hi <=: wide sum_max) in
    { Row.shifted_lo = sel_bottom next_lo ~width:shift_bits
    ; shifted_hi = sel_bottom next_hi ~width:shift_bits
    ; sum_lo = mux2 known (sel_bottom image_sum_lo ~width:sum_bits) (zero sum_bits)
    ; sum_hi = mux2 known (sel_bottom image_sum_hi ~width:sum_bits) sum_max
    ; pulled =
        mux2 c.out (surely |: row.pulled)
        @@ mux2 c.pull vdd
        @@ mux2 c.mov_osr gnd row.pulled
    }
  ;;

  let ways ~side_set_count ~word ~x_lo ~x_hi ~row =
    let c = Class.of_word ~side_set_count word in
    let asks = ~:(is_empty row) &: (x_lo <=: x_hi) &: ~:(c.halts) in
    let may_take = mux2 c.always vdd @@ mux2 c.x_dec (x_hi <>:. 0) vdd in
    let may_fall = mux2 c.always gnd @@ mux2 c.x_dec (x_lo ==:. 0) vdd in
    { Ways.next = asks &: (~:(c.jump) |: may_fall); target = asks &: c.jump &: may_take }
  ;;

  (* a full sum in the image asks the row for a full sum *)
  let holds (s : _ Row.t) (image : _ Row.t) =
    { Holds.shifted =
        s.shifted_lo <=: image.shifted_lo &: (image.shifted_hi <=: s.shifted_hi)
    ; sum = s.sum_lo <=: image.sum_lo &: (image.sum_hi <=: s.sum_hi)
    ; pulled = ~:(s.pulled) |: image.pulled
    }
  ;;

  let conjuncts
    ~side_set_count
    ~autopull
    ~pull_threshold
    ~word
    ~x_lo
    ~x_hi
    ~row
    ~next
    ~target
    =
    let ways = ways ~side_set_count ~word ~x_lo ~x_hi ~row in
    let image = image ~side_set_count ~autopull ~pull_threshold ~word ~x_lo ~x_hi ~row in
    let only_if needed holds = Holds.map holds ~f:(fun h -> ~:needed |: h) in
    { Conjuncts.next = only_if ways.next (holds next (image ~taken:false))
    ; target = only_if ways.target (holds target (image ~taken:true))
    }
  ;;

  let accepts
    ~side_set_count
    ~autopull
    ~pull_threshold
    ~word
    ~x_lo
    ~x_hi
    ~row
    ~next
    ~target
    =
    conjuncts
      ~side_set_count
      ~autopull
      ~pull_threshold
      ~word
      ~x_lo
      ~x_hi
      ~row
      ~next
      ~target
    |> Conjuncts.to_list
    |> reduce ~f:( &: )
  ;;
end

module M = Make (Bits)

(* The configuration and the program as the checker and the proposer read them. *)
module Program = struct
  type t =
    { side_set_count : Bits.t
    ; autopull : Bits.t
    ; pull_threshold : Bits.t
    ; words : int array
    ; wrap_top : int
    ; wrap_bottom : int
    }

  let create ~(config : Program_config.t) ~words =
    { side_set_count = Bits.of_unsigned_int ~width:2 config.side_set_count
    ; autopull = Bits.of_bool config.autopull
    ; pull_threshold = Bits.of_unsigned_int ~width:Isa.count_bits config.pull_threshold
    ; words = Array.of_list words
    ; wrap_top = config.wrap_top
    ; wrap_bottom = config.wrap_bottom
    }
  ;;

  let size = 1 lsl Isa.pc_bits

  let word t pc =
    Bits.of_unsigned_int
      ~width:Isa.data_bits
      (if pc < Array.length t.words then t.words.(pc) else 0)
  ;;

  let following t pc = if pc = t.wrap_top then t.wrap_bottom else (pc + 1) % size

  let target t pc =
    Bits.to_unsigned_int (Isa.Field.select (module Bits) Isa.Field.jmp_target (word t pc))
  ;;
end

module Table = struct
  type t = Bits.t Row.t array

  let unreached =
    { Row.shifted_lo = Bits.one shift_bits
    ; shifted_hi = Bits.zero shift_bits
    ; sum_lo = Bits.one sum_bits
    ; sum_hi = Bits.zero sum_bits
    ; pulled = Bits.gnd
    }
  ;;

  let full =
    { Row.shifted_lo = Bits.zero shift_bits
    ; shifted_hi = Bits.of_unsigned_int ~width:shift_bits shift_limit
    ; sum_lo = Bits.zero sum_bits
    ; sum_hi = Bits.ones sum_bits
    ; pulled = Bits.gnd
    }
  ;;

  let equal a b = List.equal Bits.equal (Row.to_list a) (Row.to_list b)

  let join (a : Bits.t Row.t) (b : Bits.t Row.t) =
    if Bits.to_bool (M.is_empty a)
    then b
    else if Bits.to_bool (M.is_empty b)
    then a
    else (
      let pick f x y =
        if f (Bits.to_unsigned_int x) (Bits.to_unsigned_int y) then x else y
      in
      { Row.shifted_lo = pick ( <= ) a.shifted_lo b.shifted_lo
      ; shifted_hi = pick ( >= ) a.shifted_hi b.shifted_hi
      ; sum_lo = pick ( <= ) a.sum_lo b.sum_lo
      ; sum_hi = pick ( >= ) a.sum_hi b.sum_hi
      ; pulled = Bits.(a.pulled &: b.pulled)
      })
  ;;

  (* a sum still moving after this many joins at one pc is given up as full *)
  let widen_after = 64

  let propose ~config ~words (kernel : Kernel.Table.t) =
    let program = Program.create ~config ~words in
    let table = Array.create ~len:Program.size unreached in
    let joins = Array.create ~len:Program.size 0 in
    table.(0) <- full;
    let rec settle = function
      | [] -> ()
      | pc :: rest ->
        let word = Program.word program pc in
        let { Kernel.Row.x_lo; x_hi; _ } = kernel.(pc) in
        let ways =
          M.ways ~side_set_count:program.side_set_count ~word ~x_lo ~x_hi ~row:table.(pc)
        in
        let image =
          M.image
            ~side_set_count:program.side_set_count
            ~autopull:program.autopull
            ~pull_threshold:program.pull_threshold
            ~word
            ~x_lo
            ~x_hi
            ~row:table.(pc)
        in
        let changed =
          [ ways.next, Program.following program pc, false
          ; ways.target, Program.target program pc, true
          ]
          |> List.filter_map ~f:(fun (asked, to_, taken) ->
            let joined = join table.(to_) (image ~taken) in
            let joined =
              if joins.(to_) < widen_after
              then joined
              else { joined with sum_lo = full.sum_lo; sum_hi = full.sum_hi }
            in
            if (not (Bits.to_bool asked)) || equal joined table.(to_)
            then None
            else (
              table.(to_) <- joined;
              joins.(to_) <- joins.(to_) + 1;
              Some to_))
        in
        settle (rest @ changed)
    in
    settle [ 0 ];
    table
  ;;
end

module Rejection = struct
  type t =
    { pc : int
    ; fails : string list
    }
  [@@deriving sexp_of]
end

let check ~config ~words ~(kernel : Kernel.Table.t) (table : Table.t) =
  let program = Program.create ~config ~words in
  let names =
    let way name = Holds.map Holds.port_names ~f:(fun field -> name ^ " " ^ field) in
    { Conjuncts.next = way "next"; target = way "target" }
  in
  let rejected =
    List.filter_map (List.range 0 Program.size) ~f:(fun pc ->
      let conjuncts =
        M.conjuncts
          ~side_set_count:program.side_set_count
          ~autopull:program.autopull
          ~pull_threshold:program.pull_threshold
          ~word:(Program.word program pc)
          ~x_lo:kernel.(pc).x_lo
          ~x_hi:kernel.(pc).x_hi
          ~row:table.(pc)
          ~next:table.(Program.following program pc)
          ~target:table.(Program.target program pc)
      in
      let fails =
        List.filter_map
          (Conjuncts.to_list (Conjuncts.zip names conjuncts))
          ~f:(fun (name, holds) -> Option.some_if (not (Bits.to_bool holds)) name)
      in
      Option.some_if (not (List.is_empty fails)) { Rejection.pc; fails })
  in
  match Bits.to_bool (M.is_full table.(0)), rejected with
  | true, [] -> Ok ()
  | false, _ -> Or_error.error_s [%message "the row at pc 0 must be the full range"]
  | true, rejected ->
    Or_error.error_s [%message "rows the check rejects" (rejected : Rejection.t list)]
;;

module I = struct
  type 'a t =
    { side_set_count : 'a [@bits 2]
    ; autopull : 'a
    ; pull_threshold : 'a [@bits Isa.count_bits]
    ; word : 'a [@bits Isa.data_bits]
    ; shifted : 'a [@bits shift_bits]
    ; pulled : 'a
    }
  [@@deriving hardcaml]
end

module O = Step

let create (_scope : Scope.t) (i : Signal.t I.t) =
  let module M = Make (Signal) in
  M.step
    ~side_set_count:i.side_set_count
    ~autopull:i.autopull
    ~pull_threshold:i.pull_threshold
    ~word:i.word
    ~shifted:i.shifted
    ~pulled:i.pulled
;;

let hierarchical ?instance scope i =
  let module H = Hierarchy.In_scope (I) (O) in
  H.hierarchical ?instance ~scope ~name:"osr_step" create i
;;
