all: issue_timing host_timing host_spacing late_host fifo_order unreachable phase_step fetch_step edge_step event_step frame_step \
  value_step narrow saturating chip_frame fail_safe isolation data_step teeth fsm_miter verilog_in \
  sram_equiv kernel_equiv translation frontend_equiv link self_check self_check_clean powerup offset_axioms

# dune runs from this checkout's root, not an enclosing worktree's
export DUNE_ROOT = .

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

# 7-bit timer core (wraps 128 cycles after a start) and its kernel, for the narrow tasks
engine_narrow.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -timer-bits 7 > formal/engine_narrow.v

kernel_step_narrow.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel -timer-bits 7 > formal/kernel_step_narrow.v

engines.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engines -engines 2 > formal/engines.v

engines_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engines -engines 2 -sram > formal/engines_sram.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby prove

# Host port, two engines: config moves only after a halted cycle, and no config, program
# or data word is written the cycle after a start. Seconds. Tooth: config written while running.
top.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe top -engines 2 > formal/top.v

HOST_UNGATED = /^module host_port (/,/^endmodule/s/^\(\s*assign signal_wire_[0-9]* = \)status\$$halted_0;/\11;/
host_spacing: top.v
	mkdir -p host_spacing_teeth
	sed '$(HOST_UNGATED)' top.v > host_spacing_teeth/ungated.v
	! cmp -s top.v host_spacing_teeth/ungated.v
	sby -f host_spacing.sby prove cover ungated

# a late host word can make a time-triggered program fault, never move a pin
late_host: engine_sram.v
	sby -f late_host.sby prove never_pushes

fifo_order: engine.v
	sby -f fifo_order.sby prove cover

# the pin bits coverage waives in src/engine.ml stay zero after a clear
unreachable: engine.v
	sby -f unreachable.sby prove cover

kernel_step.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel > formal/kernel_step.v

# the step lemma under the universal certificate, for any program
phase_step: engine.v kernel_step.v
	sby -f phase_step.sby prove cover

kernel_accepts.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel-accepts > formal/kernel_accepts.v

# Step lemma plus the kernel's check: no deadline is missed, for any program and any table
# the kernel accepts. About 20 min, a CI job of its own (phase_table_proof). Each tooth must miss one.
phase_table: engine.v kernel_step.v kernel_accepts.v
	$(MAKE) phase_table_proof

phase_table_proof:
	sby -f phase_table.sby prove cover
	sby -f phase_table.sby no_accepts no_open next_no_wrap target_is_next rows_while_running \
	  config_while_running

# Pair spacing: pair_step's lemma and the kernel's check of one step carrying the pair, per
# opcode; then the run, assuming both and the run above: each counted edge of a watched pair
# is spaced, for any program and any table accepted with a spacing. About 3 h, two pair
# tasks near 2 h each. Tooth: a check without the spacing must fail.
phase_spacing: engine.v kernel_step.v kernel_accepts.v
	$(MAKE) phase_spacing_proof

PAIR_STEP_TASKS = jmp wait_0 wait_1 wait_2_0 wait_2_1 wait_2_2 wait_2_3 wait_3 in out mov \
  set alu_x alu_y alu_p alu_t_0_0 alu_t_0_1 alu_t_0_2 alu_t_0_3 alu_t_1 alu_t_2 alu_t_3 sys

phase_spacing_proof:
	sby -f pair_step.sby $(PAIR_STEP_TASKS)
	sby -f pair_step.sby unspaced
	sby -f phase_spacing.sby prove cover no_spacing

# The same in CI parts: the seven slowest tasks alone, the rest with the tooth, the run
PAIR_STEP_ALONE = alu_t_0_1 alu_t_0_0 alu_t_0_2 wait_2_1 wait_2_2 wait_2_0 alu_t_1
PAIR_STEP_REST = $(filter-out $(PAIR_STEP_ALONE),$(PAIR_STEP_TASKS))

phase_spacing_parts:
	@echo $(PAIR_STEP_ALONE) rest run

phase_spacing_part:
ifeq ($(PART),run)
	sby -f phase_spacing.sby prove cover no_spacing
else ifeq ($(PART),rest)
	sby -f pair_step.sby $(PAIR_STEP_REST)
	sby -f pair_step.sby unspaced
else ifneq ($(filter $(PART),$(PAIR_STEP_ALONE)),)
	sby -f pair_step.sby $(PART)
else
	$(error PART is one of: $(PAIR_STEP_ALONE) rest run)
endif

# The same for rows that bound phase - slope * x too: row_step's lemma and the kernel's
# check per opcode, then the run assuming it. Each tooth must fail. About 8 min.
phase_table_affine: engine.v kernel_step.v kernel_accepts.v
	$(MAKE) phase_table_affine_proof

phase_table_affine_proof:
	sby -f row_step.sby jmp wait in out mov set alu_x alu_y alu_p alu_t sys
	sby -f row_step.sby no_axioms no_offset_check x_unfollowed
	sby -f phase_table_affine.sby prove cover
	sby -f phase_table_affine.sby offset_unchecked no_accepts no_open next_no_wrap \
	  target_is_next rows_while_running config_while_running

# The axioms on the free offsets (also taken by phase_step.sv's AFFINE run and test_kernel.ml)
# hold of the true phase - slope * x mod 2^24: each check unsat, each tooth sat. Seconds.
offset_axioms:
	[ "$$(z3 offset_axioms.smt2 | xargs)" = "unsat unsat unsat unsat unsat" ]
	[ "$$(z3 offset_axioms_teeth.smt2 | xargs)" = "sat sat sat sat" ]

# Fetch lemma: the core runs the word its memory holds at pc, followed at one free address
# by a probe added to engine.v. Seconds. Teeth: config or program written in a start's second
# cycle, which host_spacing rules out.
PROBE = /^module program_memory (/,/^endmodule/s/^\(\s*\)reg \[15:0\] signal_multiport_mem\[0:511\];/&\n\1wire [8:0] probe_addr = $$anyconst;\n\1wire [15:0] probe_word = signal_multiport_mem[probe_addr];/
fetch_step: engine.v
	sed '$(PROBE)' engine.v > engine_probed.v
	! cmp -s engine.v engine_probed.v
	sby -f fetch_step.sby prove cover config_at_start program_at_start

# the edge lemma beside it: the pins change only the cycle after an entry that writes them
edge_step: engine.v
	sby -f edge_step.sby prove cover

# a pin wait releases, and a jmp on the pin goes, by that cycle's sample
event_step: engine.v
	sby -f event_step.sby prove cover

# the frame lemma: a pin outside the engine's footprint keeps 0 from the clear on
frame_step: engine.v
	sby -f frame_step.sby prove cover

# the value lemma: what an out, a mov, an in, a push or a pull writes is the ISA's function
# of the shift registers, which hold what the ISA says from the clear on
value_step: engine.v
	sby -f value_step.sby prove cover

# the four lemmas on the narrow core, the first three each with a tooth, the step lemma's below
narrow: engine_narrow.v kernel_step_narrow.v
	$(MAKE) narrow_proof

narrow_proof:
	sby -f edge_step.sby narrow_timer_prove narrow_timer_cover narrow_timer_pins_never_change
	sby -f frame_step.sby narrow_timer_prove narrow_timer_cover narrow_timer_no_pair
	sby -f value_step.sby narrow_timer_prove narrow_timer_cover \
	  narrow_timer_reverse_wrong_width
	sby -f phase_step.sby narrow_timer_prove narrow_timer_cover

# Wrap tooth: a timer that stops at its top, on one run of jmp 0 (ONE_RUN in phase_step.sv).
# The narrow core's bounded run reaches the top and fails; the chip's, as deep, passes
# (saturating_chip).
SATURATE = s/^\(\s*assign signal_add_[0-9]* = \)now_0 + \(signal_const_[0-9]*\);/\1\&now_0 ? now_0 : now_0 + \2;/
saturating: engine_narrow.v kernel_step_narrow.v
	$(MAKE) saturating_proof

saturating_proof:
	sed '$(SATURATE)' engine_narrow.v > engine_narrow_saturating.v
	! cmp -s engine_narrow.v engine_narrow_saturating.v
	sby -f phase_step.sby saturating_narrow

saturating_chip: engine.v kernel_step.v
	sed '$(SATURATE)' engine.v > engine_saturating.v
	! cmp -s engine.v engine_saturating.v
	sby -f phase_step.sby saturating_chip

# Two-engine chip: engines with no shared pad each drive as alone, and each reads as alone
# except where the other drives a bidirectional pad or moves a wire
chip_frame: engines.v
	sby -f chip_frame.sby prove pads_shared cover

# Fault fail-safe on the two-engine chip (fail_safe.sv): a latched fault drives no pin from
# the edge it shows, halts within two edges and stays halted, pc held, until the clear. No
# fault, pins as before. Seconds. Teeth: drive kept, engine runs on or restarts, engine 0's
# mask, stop or start gate removed.
FAULT_MASK = /^module engines (/,/^endmodule/s/^\(\s*assign signal_mux[_0-9]* = \)faulted\$$0 ? signal_const[_0-9]* : \(signal_wire_[0-9]*;\)/\1\2/
FAULT_STOP = /^module engines (/,/^endmodule/s/^\(\s*assign signal_or[_0-9]* = signal_wire_[0-9]*\) | faulted\$$0;/\1;/
FAULT_START = /^module engines (/,/^endmodule/s/^\(\s*assign signal_not[_0-9]* = \)~ faulted\$$0;/\1 1;/
fail_safe: engines.v
	sby -f fail_safe.sby prove cover

fail_safe_teeth: engines.v
	mkdir -p fail_safe_teeth
	sed '$(FAULT_MASK)' engines.v > fail_safe_teeth/unmasked.v
	sed '$(FAULT_STOP)' engines.v > fail_safe_teeth/unstopped.v
	sed '$(FAULT_START)' engines.v > fail_safe_teeth/restartable.v
	! cmp -s engines.v fail_safe_teeth/unmasked.v
	! cmp -s engines.v fail_safe_teeth/unstopped.v
	! cmp -s engines.v fail_safe_teeth/restartable.v
	sby -f fail_safe.sby kept_drive runs_on restarts unmasked unstopped restartable

# Fail-safe as a corollary of the one-run theorem, per engine inside the two-engine chip, the
# rest free (phase_step.sv's CHIP): each edge driven comes the cycle after an entry inside
# its row, but the release on the edge a fault shows, then nothing until reset. Teeth: no
# kernel check, edge at the entry, mask gone or a cycle late, fault flop not sticky, a
# Manchester half early.
FAULT_LATE = /^module engines (/,/^endmodule/{s/^\(\s*assign signal_mux[_0-9]* = \)faulted\$$0 \(? signal_const[_0-9]* : signal_wire_[0-9]*;\)/\1late$$0 \2/;s/^\(\s*\)wire faulted\$$0;/&\n\1reg late$$0 = 0;\n\1always @(posedge clock) late$$0 <= faulted$$0;/}
FLIP_EARLY = /^module engine (/,/^endmodule/s/^\(\s*assign signal_and[_0-9]* = \)issue & flip_pending_0;/\1flip_pending_0;/
fail_safe_table: engines.v kernel_step.v kernel_accepts.v
	$(MAKE) fail_safe_table_proof

fail_safe_table_proof:
	mkdir -p fail_safe_teeth
	sed '$(FAULT_MASK)' engines.v > fail_safe_teeth/unmasked.v
	sed '$(FAULT_LATE)' engines.v > fail_safe_teeth/late_mask.v
	awk -f fail_safe_unsticky.awk engines.v engines.v > fail_safe_teeth/unsticky.v
	sed '$(FLIP_EARLY)' engines.v > fail_safe_teeth/flip_early.v
	for tooth in unmasked late_mask unsticky flip_early; do \
	  ! cmp -s engines.v fail_safe_teeth/$$tooth.v || exit 1; \
	done
	sby -f fail_safe_table.sby prove_0 prove_1 cover
	sby -f fail_safe_table.sby no_accepts edge_at_entry unmasked late_mask unsticky flip_early

# A UART from engine 0 to engine 1 over a wire, by induction: each word engine 1 pushes is
# the byte engine 0 sent in that frame, once a frame, each sample half a bit from the wire's
# edges. Proof about 2 min, covers 12. Teeth, failing from reset: a claim no run keeps, the
# next bit pushed, a margin one wider, a receiver at 11 cycles a bit.
link: engines_sram.v
	(cd .. && dune exec -- test/certify/write_link.exe) > link.sv
	(cd .. && dune exec -- test/certify/write_link.exe -rx-period 11) > link_baud.sv
	$(MAKE) link_proof

link_proof:
	sby -f link.sby prove cover never_pushes next_bit wider baud

# Engine 0 cannot tell what engine 1 or its host does: two chip copies agree on engine 0's
# pins and host reads, for all time (isolation.sv). Teeth drop one assumption each: engine 1
# heard by wire or pad, a pointer or host off its side of the region, reads ignoring the
# turn, a load while engine 1 runs, a write as engine 0 starts.
ANY_TURN = /^module data_memory/,/^endmodule/s/^\(\s*assign signal_and[_0-9]* = \)signal_eq[_0-9]* & \(signal_not[_0-9]*\);/\1\2;/
isolation: engines_sram.v
	$(MAKE) isolation_proof

isolation_proof:
	sed '$(ANY_TURN)' engines_sram.v > engines_any_turn.v
	! cmp -s engines_sram.v engines_any_turn.v
	sby -f isolation.sby prove cover heard pad_heard any_turn region_written outside \
	  load_anytime start_write

# Self_check.checker beside its contract (test/self_check_contract.ml), any line, 116 cycles
# from the clear: irq only after a break and when the contract says, no deadline missed.
# That covers the first frame's deadlines for a first fall by about cycle 22. Covers meet
# each deadline to the cycle. Teeth: a stamp a cycle off at either check, irq missing or
# late. About 30 min.
self_check: engine_sram.v
	(cd .. && dune exec -- test/certify/write_self_check.exe) > self_check.sv
	(cd .. && dune exec -- test/certify/write_self_check.exe -mutant stamp) > self_check_stamp.sv
	(cd .. && dune exec -- test/certify/write_self_check.exe -mutant least) > self_check_least.sv
	(cd .. && dune exec -- test/certify/write_self_check.exe -mutant silent) > self_check_silent.sv
	(cd .. && dune exec -- test/certify/write_self_check.exe -mutant slow) > self_check_slow.sv
	$(MAKE) self_check_proof

self_check_proof:
	sby -f self_check.sby bmc cover stamp least silent slow

# The same checker, any line, for all time: until the line leaves its rows, no irq, no halt,
# no missed deadline. By 12-induction over invariants mined from simulated runs less the
# refuted ones (write_self_check.ml). Teeth: a frame is reached; without the claims a
# contract a cycle off sees a false alarm. ~1 min.
self_check_clean: engine_sram.v
	(cd .. && dune exec -- test/certify/write_self_check.exe -invariants) > self_check_clean.sv
	$(MAKE) self_check_clean_proof

self_check_clean_proof:
	sby -f self_check_clean.sby prove teeth shifted

osr_step.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe osr > formal/osr_step.v

# the data lemma: each out sends the bits of the word the osr last took that the osr
# kernel's count says, or the underflow fault is set
data_step: engine.v osr_step.v
	sby -f data_step.sby prove cover

# weakened statements, which pass only by failing, phase_step's core with its capture
# stamped a cycle early, and a core whose program memory takes a write, or that takes a
# start, while it runs
UNGATED = s/^\(\s*assign program_write = signal_wire_[0-9]*\) & halted_0;/\1;/
START_UNGATED = s/^\(\s*assign starting = signal_wire_[0-9]*\) & halted_0;/\1;/
teeth: engine.v engine_sram.v engines.v kernel_step.v osr_step.v
	mkdir -p issue_timing_teeth
	sed '$(UNGATED)' engine.v > issue_timing_teeth/write_while_running.v
	sed '$(START_UNGATED)' engine.v > issue_timing_teeth/start_while_running.v
	! cmp -s engine.v issue_timing_teeth/write_while_running.v
	! cmp -s engine.v issue_timing_teeth/start_while_running.v
	sby -f issue_timing.sby jump_in_one delay_ignores_side_set waits_are_plain write_while_running \
	  start_while_running
	sby -f fifo_order.sby stale_ahead
	sby -f unreachable.sby one_more
	mkdir -p phase_step_teeth
	awk -f capture_early.awk engine.v engine.v > phase_step_teeth/capture_early.v
	sby -f phase_step.sby jump_in_one late_wait_waits no_carry one_late_cycle_is_safe taken_backwards \
	  second_edge level_at_arm later_edge_captured capture_a_cycle_older capture_a_cycle_younger \
	  capture_stamped_early arm_one_short edge_one_short start_while_running
	sby -f edge_step.sby pins_never_change side_set_only one_cycle_later flip_off_issue no_flip
	sby -f event_step.sby late level_only wires_plain jump_late held_moves
	sby -f frame_step.sby narrow_side narrow_set narrow_out narrow_mov no_pair side_dirs_on_out \
	  no_wrap
	sby -f value_step.sby wrong_direction one_short no_invert reverse_wrong_width \
	  pull_past_threshold data_never_refused in_wrong_direction push_before_shift \
	  flip_at_outs_base flip_same_half
	sby -f chip_frame.sby overlap unbound read_everywhere
	$(MAKE) fail_safe_teeth
	sby -f data_step.sby wrong_way off_by_one stale_word
	sby -f host_timing.sby private_pull no_wait_excuse no_jump_excuse no_underflow_excuse no_overflow_excuse
	sby -f late_host.sby admit_fifo_wait admit_fifo_jump private_pull no_underflow_excuse \
	  no_overflow_excuse

# One firmware's certificate as an inductive invariant, for all time: make
# inductive_certificate NAME=uart_tx16. Teeth, failing from reset: a claim that the pc never
# reaches a row a few instructions in, a row moved a cycle, a receiver's capture a cycle
# older or younger. inductive_write needs dune, inductive_proof does not.
MACRO = RM_IHPSG13_1P_512x16_c2_bm_bist.v
$(MACRO):
	cp ../src/$(MACRO) $@

inductive_write: engine_sram.v $(MACRO)
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive $(NAME)) > certificate_$(NAME).sv
	-python3 ../demo/speed.py mark $(NAME) file --if-started

inductive_certificate: inductive_write
	$(MAKE) inductive_proof NAME=$(NAME)

inductive_proof: $(MACRO)
	cp certificate_$(NAME).sv certificate.sv
	sby -f -d certificate_$(NAME)_inductive certificate_inductive.sby prove
	sby -f -d certificate_$(NAME)_teeth certificate_inductive.sby teeth
	! grep -q NO_PERIOD certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby no_period
	! grep -q LEVEL_AT_ARM certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby level_at_arm
	! grep -q ROW_EARLY certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby row_early
	! grep -q ROW_LATE certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby row_late
	! grep -q CAPTURE_OLDER certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby capture_older
	! grep -q CAPTURE_YOUNGER certificate.sv || \
	  sby -f --prefix certificate_$(NAME) certificate_inductive.sby capture_younger
	-python3 ../demo/speed.py mark $(NAME) certificate --if-started

# Every uart_tx_stamped frame carries the low 16 bits of the cycle its start bit shows on
# the pin, and the pin shows them: the certificate above plus that claim. Teeth: the stamp
# a cycle late, the pin showing the next bit.
stamped_certificate: engine_sram.v $(MACRO)
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive -stamped uart_tx_stamped) > certificate_stamped.sv
	$(MAKE) stamped_proof

stamped_proof: $(MACRO)
	cp certificate_stamped.sv certificate.sv
	sby -f -d certificate_stamped_inductive certificate_inductive.sby prove
	sby -f --prefix certificate_stamped certificate_inductive.sby teeth off_by_one next_bit

# Which bits of which host word the pins carry, for transmitters that pull each word by hand
# and send it through the osr alone: the certificate above plus write_certificate.ml's data
# claims. Tooth: pins showing the next bit fail from reset, except at uart_tx_host_rate's
# 434 cycles a bit, too deep for bmc; uart_tx runs the same claims at 8.
DATA = uart_tx uart_tx16 uart_tx_host_rate spi_master jtag
NEXT_BIT_DATA = $(filter-out uart_tx_host_rate,$(DATA))
data_certificate: engine_sram.v $(MACRO)
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive -data $(NAME)) > certificate_data_$(NAME).sv
	$(MAKE) data_proof NAME=$(NAME)

data_proof: $(MACRO)
	cp certificate_data_$(NAME).sv certificate.sv
	sby -f -d certificate_data_$(NAME)_inductive certificate_inductive.sby prove
	sby -f --prefix certificate_data_$(NAME) certificate_inductive.sby teeth \
	  $(if $(filter $(NAME),$(NEXT_BIT_DATA)),next_bit)

data_certificates: engine_sram.v
	for name in $(DATA); do $(MAKE) data_certificate NAME=$$name || exit 1; done

data_names:
	@echo $(DATA)

# Every firmware in test/library.ml under the assumptions its entry states and the
# certificate prints: none for most, the period the host loads, one edge from the arm to its
# wait, or for firmware that waits on the host or anchors on a captured edge, the core within
# 84 ms of its deadline and edge (24 bits of the difference wrap beyond). With the period or
# the line's level at the arm left free it has to fail.
INDUCTIVE = $(shell cd .. && dune exec -- test/certify/write_certificate.exe -names)
inductive_certificates: engine_sram.v
	for name in $(INDUCTIVE); do $(MAKE) inductive_certificate NAME=$$name || exit 1; done

# CI writes each of these and proves it in a job of its own
inductive_names:
	@echo $(INDUCTIVE)

# Each receiver's clock tolerance (write_tolerance.ml). UARTs at their certificates' bounds
# (test/tolerance.ml), from a sender free-running at any m 2^-16 cycles a bit within them and
# any phase: the byte read, no irq or fault, and the next frame's start edge, right behind
# the stop bit, captured as far after the first's as it shows, so every frame meets the
# receiver as the first did. Teeth: a step faster or slower than the bounds, and a receiver
# sampling a cycle late at the on-time one's bounds or a step past its own; at its own bounds
# it passes. uart_rx_16 is the library's, the host rate receivers at half periods short
# enough to unroll. The SPI target follows SCK, so no rate error builds up: two bytes in
# mode 0 with every SCK phase free from its least to 2 more, and a cycle less high fails.
TOLERANCE = uart_rx_16 uart_rx_host_rate_4 uart_rx_host_rate_8 spi_target_mode0
TOLERANCE_PROOFS = prove moved_own
TOLERANCE_TEETH = reach_least reach_most faster slower moved moved_faster moved_slower
TOLERANCE_PROOFS_spi_target_mode0 = prove
TOLERANCE_TEETH_spi_target_mode0 = reach_least faster

tolerance: engine_sram.v
	for name in $(TOLERANCE); do $(MAKE) tolerance_one NAME=$$name || exit 1; done

tolerance_one:
	(cd .. && dune exec -- test/certify/write_tolerance.exe -name $(NAME)) > tolerance_$(NAME).sv
	(cd .. && dune exec -- test/certify/write_tolerance.exe -name $(NAME) -moved) > tolerance_$(NAME)_moved.sv
	(cd .. && dune exec -- test/certify/write_tolerance.exe -name $(NAME) -depth) > tolerance_$(NAME).depth
	$(MAKE) tolerance_proof NAME=$(NAME)

tolerance_proof:
	sed -e "s/^depth .*/depth $$(cat tolerance_$(NAME).depth)/" \
	  -e "s/tolerance_moved.sv/tolerance_$(NAME)_moved.sv/g" \
	  -e "s/tolerance.sv/tolerance_$(NAME).sv/g" tolerance.sby > tolerance_$(NAME).sby
	sby -f tolerance_$(NAME).sby $(or $(TOLERANCE_PROOFS_$(NAME)),$(TOLERANCE_PROOFS))
	sby -f tolerance_$(NAME).sby $(or $(TOLERANCE_TEETH_$(NAME)),$(TOLERANCE_TEETH))

tolerance_names:
	@echo $(TOLERANCE)

# fsm compiler's miter (write_certificate.ml -fsm): hardcaml_hobby_boards' Uart.Tx,
# unmodified, beside the engine running its compiled firmware. Proof ~20 s, teeth ~1.5 min.
fsm_miter: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -fsm) > fsm_miter.sv
	(cd .. && dune exec -- test/certify/write_certificate.exe -fsm -mutant) > fsm_miter_mutant.sv
	$(MAKE) fsm_miter_proof

fsm_miter_proof:
	sby -f fsm_miter.sby prove short_gap early mutant

# Verilog in (write_certificate.ml -verilog-corpus): the transmitters in
# test/certify/third_party, each refused by name or compiled, certified and written as a
# miter beside the engine. Accepted ones ~30 s, teeth ~5 min (the second's mutant, ~10 min,
# runs locally).
verilog_in: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -verilog-corpus -out formal) \
	  > verilog_corpus.txt
	$(MAKE) verilog_in_proof

verilog_in_proof:
	diff ../test/certify/third_party/corpus.expected verilog_corpus.txt
	sby -f verilog_nandland_uart.sby prove early mutant short_gap
	sby -f verilog_alexforencich_uart_tied.sby prove early

memory_flops.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe memory > formal/memory_flops.v

memory_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe memory -sram > formal/memory_sram.v

# The flop program memory is IHP's macro model, step for step from any equal state
# (sram_equiv/step.tcl), which lets the lemmas and netlist_equiv cut the macro; then the
# model's own cases and the teeth. About 45 s.
MODELS = ../test/models
CORE = $(MODELS)/RM_IHPSG13_1P_core_behavioral_bm_bist.v
STEP = sram_equiv_run
SIDES = FLOPS=../memory_flops.v MACRO=../memory_sram.v \
  MODEL=../$(MODELS)/RM_IHPSG13_1P_512x16_c2_bm_bist.v CORE=../$(CORE)
sram_equiv: memory_flops.v memory_sram.v
	$(MAKE) sram_equiv_proof

sram_equiv_proof:
	$(MAKE) sram_equiv_step
	cd $(STEP) && yosys -q -l cases.log ../sram_equiv/cases.ys
	$(MAKE) sram_equiv_teeth

sram_equiv_step:
	rm -rf $(STEP) && mkdir $(STEP)
	cd $(STEP) && $(SIDES) yosys -q -l step.log -c ../sram_equiv/step.tcl
	cd $(STEP) && timeout 600 yosys-abc \
	  -c 'read_aiger step.aig; print_stats; dprove; print_status' > proof.log
	grep 'Status = $(EXPECT) ' $(STEP)/proof.log

# model mutants that must be refuted: dout reading the word before the write; bit 0 of the
# mask dropped; each word stored with bit 15 flipped when bit 0 is set, which equals the model
# from all-zero contents (passes in sram_equiv/zero.tcl) but not from any state
TEETH = sram_equiv_teeth
SCRAMBLE = function [P_DATA_WIDTH-1:0] scramble(input [P_DATA_WIDTH-1:0] v); \
  scramble = v ^ {v[0], {(P_DATA_WIDTH-1){1'b0}}}; endfunction
sram_equiv_teeth:
	rm -rf $(TEETH) && mkdir $(TEETH)
	sed 's/dr_r<= (memory\[ADDR_MUX\] & ~BM_MUX) | (DIN_MUX & BM_MUX);/dr_r<= memory[ADDR_MUX];/' \
	  $(CORE) > $(TEETH)/read_first.v
	sed '/^\s*memory\[ADDR_MUX\] <=/s/BM_MUX/(BM_MUX \& ~1)/g' $(CORE) > $(TEETH)/mask_bit.v
	sed -e 's/(memory\[ADDR_MUX\] & ~BM_MUX)/(scramble(memory[ADDR_MUX]) \& ~BM_MUX)/g' \
	  -e 's/^\(\s*memory\[ADDR_MUX\] <= \)\(.*\);/\1scramble(\2);/' \
	  -e 's/dr_r<=memory\[ADDR_MUX\];/dr_r<=scramble(memory[ADDR_MUX]);/' \
	  -e "/^reg \[P_DATA_WIDTH-1:0\] *dr_r;/a $(SCRAMBLE)" $(CORE) > $(TEETH)/scrambled.v
	for tooth in read_first mask_bit scrambled; do \
	  ! cmp -s $(CORE) $(TEETH)/$$tooth.v || exit 1; \
	  $(MAKE) sram_equiv_step CORE=$(TEETH)/$$tooth.v STEP=sram_equiv_$$tooth EXPECT=0 || exit 1; \
	done
	rm -rf sram_equiv_zero && mkdir sram_equiv_zero
	cd sram_equiv_zero && $(SIDES) CORE=../$(TEETH)/scrambled.v \
	  yosys -q -l build.log -c ../sram_equiv/zero.tcl
	cd sram_equiv_zero && timeout 600 yosys-abc \
	  -c 'read_aiger zero.aig; print_stats; dprove; print_status' > proof.log
	grep 'Status = 1 ' sram_equiv_zero/proof.log

kernel_gates.aag: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel-gates > formal/kernel_gates.aag

kernel_accepts_gates.aag: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel-gates -accepts > formal/kernel_accepts_gates.aag

# The kernel's step and row check, as the Verilog the RTL proofs read, equal the gates its
# SAT proofs build (kernel_equiv/miter.ys); each with one gate flipped must fail. About 15 s.
kernel_equiv: kernel_step.v kernel_gates.aag kernel_accepts.v kernel_accepts_gates.aag
	$(MAKE) kernel_equiv_proof

kernel_equiv_proof:
	$(MAKE) kernel_miter RTL=kernel_step.v GATES=kernel_gates.aag KERNEL=kernel_equiv_step
	$(MAKE) kernel_miter RTL=kernel_accepts.v GATES=kernel_accepts_gates.aag \
	  KERNEL=kernel_equiv_accepts
	$(MAKE) kernel_miter RTL=kernel_step.v GATES=kernel_gates.aag KERNEL=kernel_equiv_step_flip \
	  FLIP='awk -f kernel_equiv/flip.awk' EXPECT=0
	$(MAKE) kernel_miter RTL=kernel_accepts.v GATES=kernel_accepts_gates.aag \
	  KERNEL=kernel_equiv_accepts_flip FLIP='awk -f kernel_equiv/flip.awk' EXPECT=0

FLIP = cat
kernel_miter:
	rm -rf $(KERNEL) && mkdir $(KERNEL)
	cp $(RTL) $(KERNEL)/rtl.v
	$(FLIP) $(GATES) > $(KERNEL)/gates.aag
	[ "$(FLIP)" = cat ] || ! cmp -s $(GATES) $(KERNEL)/gates.aag
	cd $(KERNEL) && yosys -q -l miter.log ../kernel_equiv/miter.ys
	cd $(KERNEL) && timeout 600 yosys-abc \
	  -c 'read_aiger miter.aig; print_stats; dprove; print_status' > proof.log
	grep 'Status = $(EXPECT) ' $(KERNEL)/proof.log

# The simulated circuit is the Verilog the proofs and flow read: each chip module, built as
# bin/generate.exe top -sram -engines 2, equals the committed file as Yosys reads it, by
# Hardcaml's Sec with every UNSAT checked by cake_lpr (test/translation). Seconds. Each tooth
# must fail in its module alone: host_port's config gate open, pc stepping back, a fifo word
# written at the read address, a fifo flop's initial value, the reset synchroniser's edge.
TRANSLATION = ../_build/default/test/translation/check_translation.exe check \
  -lib ../src/RM_IHPSG13_1P_512x16_c2_bm_bist.v
translation:
	cd .. && dune build test/translation/check_translation.exe
	$(MAKE) translation_proof

translation_proof:
	rm -rf translation_run && mkdir translation_run
	$(TRANSLATION) $(WRITTEN) > translation_run/check.log
	$(MAKE) translation_tooth TOOTH=ungated FAILS='failed host_port'
	$(MAKE) translation_tooth TOOTH=pc_back FAILS='counterexample engine'
	$(MAKE) translation_tooth TOOTH=fifo_word FAILS='counterexample host_fifo'
	$(MAKE) translation_tooth TOOTH=fifo_init FAILS='failed host_fifo'
	$(MAKE) translation_tooth TOOTH=reset_edge FAILS='failed top'

EDIT_ungated = $(HOST_UNGATED)
EDIT_pc_back = /^module engine (/,/^endmodule/s/= pc_0 + /= pc_0 - /
EDIT_fifo_word = /^module host_fifo (/,/^endmodule/s/mem\[signal_wire_2\] <=/mem[RA] <=/
EDIT_fifo_init = /^module host_fifo (/,/^endmodule/s/USED_MINUS_1 = 4'b1111;/USED_MINUS_1 = 4'b0111;/
EDIT_reset_edge = /^module top (/,/^endmodule/s/ or posedge / or negedge /
translation_tooth:
	sed "$(EDIT_$(TOOTH))" $(WRITTEN) > translation_run/$(TOOTH).v
	! cmp -s $(WRITTEN) translation_run/$(TOOTH).v
	! $(TRANSLATION) translation_run/$(TOOTH).v > translation_run/$(TOOTH).log
	grep -Eq '^\($(FAILS)([ )]|$$)' translation_run/$(TOOTH).log
	[ $$(grep -c '^(QED' translation_run/$(TOOTH).log) -eq \
	  $$(($$(grep -c '^(QED' translation_run/check.log) - 1)) ]

# Two frontends read that Verilog to one chip: Yosys's read_verilog and yosys-slang's
# read_slang (frontend_equiv/equiv.ys). About 2 min. Teeth, 2 each: pc stepping back on
# slang's side alone, a fifo word written at the read address on Yosys's alone
frontend_equiv:
	$(MAKE) frontend_equiv_step STEP=frontend_equiv_run
	$(MAKE) frontend_equiv_step STEP=frontend_equiv_pc_back SLANG=pc_back FAILS=1
	$(MAKE) frontend_equiv_step STEP=frontend_equiv_fifo_word YOSYS=fifo_word FAILS=1

frontend_equiv_step:
	rm -rf $(STEP) && mkdir $(STEP)
	sed "$(EDIT_$(YOSYS))" $(WRITTEN) > $(STEP)/yosys.v
	sed "$(EDIT_$(SLANG))" $(WRITTEN) > $(STEP)/slang.v
	[ -z "$(FAILS)" ] || ! cmp -s $(STEP)/yosys.v $(STEP)/slang.v
	cd $(STEP) && timeout 900 yosys -q -l equiv.log ../frontend_equiv/equiv.ys > /dev/null 2>&1; \
	  echo $$? > status
	if [ -z "$(FAILS)" ]; then grep -qx 0 $(STEP)/status; \
	else grep -q "unproven \$$equiv cells in 'equiv_status -assert'" $(STEP)/equiv.log; fi

# Power-up is deterministic: two chip copies from any two states, reset at the first edge
# and same pins after it, drive the same pins (powerup.sv), by induction on an invariant over
# the flops powerup.tcl brings out. havoc leaves the host fifos' words and read buffers free
# while cleared (powerup_havoc.awk), as netlist_anystate needs; cold gives each copy its own
# program SRAM words until its engine first starts. About 30 s each. Teeth: no reset at the
# first edge, the engines' pin register without its clear (also under havoc and cold), and
# the stale-head fix for an empty rx fifo reverted, which a host read must catch.
powerup:
	mkdir -p powerup_teeth
	awk -f powerup_unreset.awk ../src/protocol_emulator.v ../src/protocol_emulator.v \
	  > powerup_teeth/unreset.v
	awk -f powerup_stale.awk ../src/protocol_emulator.v ../src/protocol_emulator.v \
	  > powerup_teeth/stale.v
	awk -f powerup_havoc.awk ../src/protocol_emulator.v > powerup_teeth/havoc.v
	awk -f powerup_havoc.awk powerup_teeth/unreset.v > powerup_teeth/havoc_unreset.v
	sby -f powerup.sby prove no_reset unreset stale havoc havoc_unreset cold cold_unreset

# the hardened netlist equals the RTL, macros cut (netlist_equiv/miter.ys); about 2 min:
#   make netlist_equiv NETLIST=../runs/wokwi/final/nl/tt_um_marcosash_protocol_emulator.nl.v
STDCELL = $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell
EQUIV = netlist_equiv_run
EXPECT = 1
WRITTEN = ../src/protocol_emulator.v
# the cell models at zero delay (netlist_equiv/primitives.v)
CELL_MODELS = sed -e '/^\s*specify/,/^\s*endspecify/d' -e 's/delayed_//g' \
  -e 's/^\(\s*\)\(ihp_[a-z0-9_]*\) *(\([A-Za-z0-9_]*\),/\1\2 u_\3 (\3,/' \
  $(STDCELL)/verilog/sg13cmos5l_stdcell.v
FSM_STEP = timeout 600 yosys-abc -c 'read_aiger fsm_step.aig; print_stats; pdr; print_status'
netlist_equiv:
	rm -rf $(EQUIV) && mkdir $(EQUIV)
	cp $(NETLIST) $(EQUIV)/netlist.v
	cp $(WRITTEN) $(EQUIV)/written.v
	$(CELL_MODELS) > $(EQUIV)/cells.v
	cp $(STDCELL)/lib/sg13cmos5l_stdcell_typ_1p20V_25C.lib $(EQUIV)/cells.lib
	cp netlist_equiv/cells.ys $(EQUIV)
	for cell in $$(grep -oE '^ *sg13cmos5l_[a-z0-9_]+ ' $(EQUIV)/netlist.v | sort -u | grep -vE 'fill|decap|antenna'); do \
	  printf '%s\n' "design -reset" "design -copy-from liberty -as liberty $$cell" \
	    "design -copy-from model -as model $$cell" \
	    "select -assert-none t:\$$_DFF_N* t:\$$_DFFE_N* %u t:\$$_DFFSR_N* %u t:\$$_DLATCH* %u" \
	    "equiv_make liberty model equiv" "hierarchy -top equiv" "async2sync" \
	    "equiv_simple -seq 2" "equiv_status -assert"; \
	done >> $(EQUIV)/cells.ys
	cd $(EQUIV) && yosys -q -l cells.log cells.ys
	cd $(EQUIV) && yosys -q -l gold.log ../netlist_equiv/gold.ys
	cd $(EQUIV) && yosys -q -l gate.log ../netlist_equiv/gate.ys
	cd $(EQUIV) && yosys -q -l miter.log ../netlist_equiv/miter.ys
	cd $(EQUIV) && $(FSM_STEP) > fsm_step.log
	grep 'Status = 1 ' $(EQUIV)/fsm_step.log
	cd $(EQUIV) && timeout 1200 yosys-abc \
	  -c 'read_aiger miter.aig; print_stats; scorr; print_stats; dprove; print_status' > proof.log
	@cd $(EQUIV) && echo "netlist: $$(cut -d' ' -f1 logic.count) logic cells, $$(cut -d' ' -f1 covered.count)" \
	  "in the fan-in of a compared bit and the rest driving no net;" \
	  "$$(cut -d' ' -f1 physical.count) fill, decap and antenna cells"
	grep 'Status = $(EXPECT) ' $(EQUIV)/proof.log

# mutants that must be refuted: macro enables swapped, uio_oe[0] inverted, a reset
# synchroniser untied (its counterexample must pass the first cycle), the written host
# port's state held against fsm_step
netlist_equiv_teeth:
	mkdir -p netlist_equiv_teeth
	sed -E '/^module host_port /,/^endmodule/s/^( *sm <= )signal_wire_[0-9]+;/\1sm;/' \
	  ../src/protocol_emulator.v > netlist_equiv_teeth/written.v
	! cmp -s ../src/protocol_emulator.v netlist_equiv_teeth/written.v
	rm -rf netlist_equiv_written && mkdir netlist_equiv_written
	cp netlist_equiv_teeth/written.v netlist_equiv_written
	cd netlist_equiv_written && yosys -q -l gold.log ../netlist_equiv/gold.ys
	cd netlist_equiv_written && $(FSM_STEP) > fsm_step.log
	grep 'Status = 0 ' netlist_equiv_written/fsm_step.log
	sed '/ RM_IHPSG13_1P_512x16_c2_bm_bist \\core\.top\.engines\.data_memory\.sram_macro\.sram /,/;$$/'\
	'{s/\.A_REN(/.A_SWAP(/;s/\.A_WEN(/.A_REN(/;s/\.A_SWAP(/.A_WEN(/}' $(NETLIST) > netlist_equiv_teeth/swap.v
	! cmp -s $(NETLIST) netlist_equiv_teeth/swap.v
	awk -v 'net=uio_oe[0]' -f netlist_equiv/flip.awk $(NETLIST) > netlist_equiv_teeth/flip.v
	awk -f netlist_equiv/unreset.awk $(NETLIST) $(NETLIST) > netlist_equiv_teeth/unreset.v
	$(MAKE) netlist_equiv NETLIST=netlist_equiv_teeth/swap.v EQUIV=netlist_equiv_swap EXPECT=0
	$(MAKE) netlist_equiv NETLIST=netlist_equiv_teeth/flip.v EQUIV=netlist_equiv_flip EXPECT=0
	$(MAKE) netlist_equiv NETLIST=netlist_equiv_teeth/unreset.v EQUIV=netlist_equiv_unreset EXPECT=0
	grep -E 'CEX: .* Frame = +[1-9]' netlist_equiv_unreset/proof.log

# the hardened netlist from any state, rst_n low at the first edge, equals the RTL from
# any state after it (netlist_equiv/anystate.awk), and the host port's recoded state
# machine its written one; run after netlist_equiv, in its directory. About 5 min.
ANY_EXPECT = 1
ANY_AIG = setundef -init -zero; aigmap; opt_clean -purge
ANY_PROOF = read_aiger anystate.aig; print_stats; scorr -C 10000; print_stats; dprove; print_status
netlist_anystate:
	cd $(EQUIV) && yosys -q -l anystate.log ../netlist_equiv/anystate.ys
	cd $(EQUIV) && awk -v reset=in_rst_n -v fifos=1 -f ../netlist_equiv/anystate.awk \
	  anystate_pre.il anystate_pre.il > anystate.il
	cd $(EQUIV) && awk -v reset=in_clear -v high=1 -f ../netlist_equiv/anystate.awk \
	  fsm_step_pre.il fsm_step_pre.il > fsm_anystate.il
	cd $(EQUIV) && yosys -q -p 'read_rtlil fsm_anystate.il; $(ANY_AIG); write_aiger fsm_anystate.aig'
	cd $(EQUIV) && yosys -q -p 'read_rtlil anystate.il; $(ANY_AIG); write_aiger anystate.aig'
	cd $(EQUIV) && timeout 600 yosys-abc \
	  -c 'read_aiger fsm_anystate.aig; print_stats; pdr; print_status' > fsm_anystate.log
	grep 'Status = 1 ' $(EQUIV)/fsm_anystate.log
	cd $(EQUIV) && timeout 1800 yosys-abc -c '$(ANY_PROOF)' > anystate.proof.log
	grep 'Status = $(ANY_EXPECT) ' $(EQUIV)/anystate.proof.log

# mutants that must be refuted from any state: a reset synchroniser untied, and a flop
# with no reset ORed into uio_oe[0], which netlist_equiv, from all flops 0, has to pass
netlist_anystate_teeth:
	mkdir -p netlist_anystate_teeth
	awk -f netlist_equiv/unreset.awk $(NETLIST) $(NETLIST) > netlist_anystate_teeth/unreset.v
	awk -v 'net=uio_oe[0]' -f netlist_equiv/stuck.awk $(NETLIST) > netlist_anystate_teeth/stuck.v
	$(MAKE) netlist_equiv NETLIST=netlist_anystate_teeth/unreset.v EQUIV=netlist_anystate_unreset \
	  EXPECT=0
	$(MAKE) netlist_anystate EQUIV=netlist_anystate_unreset ANY_EXPECT=0
	$(MAKE) netlist_equiv NETLIST=netlist_anystate_teeth/stuck.v EQUIV=netlist_anystate_stuck
	$(MAKE) netlist_anystate EQUIV=netlist_anystate_stuck ANY_EXPECT=0

# The Icepi Zero's build equals the RTL: synth_ecp5's netlist before place and route, against
# icepi_top.v around the chip's Verilog, macro cores cut on both sides (icepi_equiv/miter.ys),
# from all 0 and from the bitstream's configured state (configured.awk). About 5 min:
#   make -C icepi build/usb1.json && make icepi_equiv
# ICEPI_JSON, USB and MHZ select another build, as in icepi/Makefile's equiv target.
ICEPI = icepi_equiv_run
ICEPI_JSON = ../icepi/build/usb1.json
USB = 1
MHZ = 48
ICEPI_PROOF = print_stats; scorr; print_stats; dprove; print_status
icepi_equiv:
	rm -rf $(ICEPI) && mkdir $(ICEPI)
	cp $(ICEPI_JSON) $(ICEPI)/netlist.json
	cp $(WRITTEN) $(ICEPI)/written.v
	echo 'chparam -set USB_UIO $(USB) -set MHZ $(MHZ) icepi_top' > $(ICEPI)/params.ys
	cd $(ICEPI) && yosys -q -l gold.log ../icepi_equiv/gold.ys
	cd $(ICEPI) && yosys -q -l gate.log ../icepi_equiv/gate.ys
	cd $(ICEPI) && $(FSM_STEP) > fsm_step.log
	grep 'Status = 1 ' $(ICEPI)/fsm_step.log
	cd $(ICEPI) && yosys -q -l miter.log ../icepi_equiv/miter.ys
	cd $(ICEPI) && awk -f ../icepi_equiv/configured.awk miter_pre.il > configured.il
	cd $(ICEPI) && yosys -q -l configured.log ../icepi_equiv/configured.ys
	cd $(ICEPI) && timeout 3600 yosys-abc -c 'read_aiger miter.aig; $(ICEPI_PROOF)' > proof.log
	grep 'Status = $(EXPECT) ' $(ICEPI)/proof.log
	cd $(ICEPI) && timeout 3600 yosys-abc -c 'read_aiger configured.aig; $(ICEPI_PROOF)' \
	  > configured_proof.log
	grep 'Status = $(EXPECT) ' $(ICEPI)/configured_proof.log
	@echo "netlist sha256 $$(sha256sum < $(ICEPI)/netlist.json | cut -d' ' -f1)"

# Mutants that must be refuted: the LUT driving uio[2] inverted, the data memory's block
# RAM with two data bits swapped, the written host port's state held against fsm_step, and
# a block RAM in a mode DP16KD.v does not model, which has to stop the run
ICEPI_TEETH = icepi_equiv_teeth
icepi_equiv_teeth:
	rm -rf $(ICEPI_TEETH) && mkdir $(ICEPI_TEETH)
	jq --arg pad 'uio_pad[2]' -f icepi_equiv/flip.jq $(ICEPI_JSON) > $(ICEPI_TEETH)/flip.json
	jq --arg a DIA0 --arg b DIA1 -f icepi_equiv/swap.jq $(ICEPI_JSON) > $(ICEPI_TEETH)/swap.json
	jq '(.modules.icepi_top.cells[] | select(.type == "DP16KD") | .parameters.WRITEMODE_A) = "NORMAL"' \
	  $(ICEPI_JSON) > $(ICEPI_TEETH)/mode.json
	sed -E '/^module host_port /,/^endmodule/s/^( *sm <= )signal_wire_[0-9]+;/\1sm;/' \
	  $(WRITTEN) > $(ICEPI_TEETH)/written.v
	! cmp -s $(WRITTEN) $(ICEPI_TEETH)/written.v
	$(MAKE) icepi_equiv ICEPI_JSON=$(ICEPI_TEETH)/flip.json ICEPI=icepi_equiv_flip EXPECT=0
	$(MAKE) icepi_equiv ICEPI_JSON=$(ICEPI_TEETH)/swap.json ICEPI=icepi_equiv_swap EXPECT=0
	! $(MAKE) icepi_equiv ICEPI_JSON=$(ICEPI_TEETH)/mode.json ICEPI=icepi_equiv_mode
	grep -q 'DP16KD: a configuration icepi_equiv does not model' icepi_equiv_mode/gate.log
	! $(MAKE) icepi_equiv WRITTEN=$(ICEPI_TEETH)/written.v ICEPI=icepi_equiv_written
	grep 'Status = 0 ' icepi_equiv_written/fsm_step.log

# one clock, and every other pin through one two-flop synchroniser (sync/check.tcl), on
# the RTL and on the hardened netlist; about 3 min:
#   make sync_rtl sync_gate NETLIST=../runs/wokwi/final/nl/tt_um_marcosash_protocol_emulator.nl.v
# With FAILS set, the run must fail at the check it names instead.
SYNC = sync_run
PROJECT = ../src/project.v
FAILS =
SYNC_RUN = if [ -z '$(FAILS)' ]; then yosys -q -l $(1).log ../sync/$(1).ys; else \
  ! yosys -q -l $(1).log ../sync/$(1).ys > /dev/null 2>&1 \
  && [ "$$(grep '^sync: ' $(1).log | tail -n 1)" = 'sync: $(FAILS)' ]; fi
sync_rtl:
	rm -rf $(SYNC)_rtl && mkdir $(SYNC)_rtl
	cp $(PROJECT) $(SYNC)_rtl/project.v
	cd $(SYNC)_rtl && $(call SYNC_RUN,rtl)

sync_gate:
	rm -rf $(SYNC)_gate && mkdir $(SYNC)_gate
	cp $(NETLIST) $(SYNC)_gate/netlist.v
	$(CELL_MODELS) > $(SYNC)_gate/cells.v
	cd $(SYNC)_gate && $(call SYNC_RUN,gate)

# a second flop on ui_in[3] and a latch in the wrapper, which must be refuted
sync_rtl_teeth:
	mkdir -p sync_teeth
	sed '/^endmodule/i reg tooth; always @(posedge clk) tooth <= ui_in[3];' $(PROJECT) > sync_teeth/sample_rtl.v
	sed '/^endmodule/i reg tooth; always @* if (ena) tooth = uo_out[0];' $(PROJECT) > sync_teeth/latch_rtl.v
	$(MAKE) sync_rtl PROJECT=sync_teeth/sample_rtl.v SYNC=sync_sample FAILS='ui_in_3_ reaches one flop'
	$(MAKE) sync_rtl PROJECT=sync_teeth/latch_rtl.v SYNC=sync_latch FAILS='no latch'

# mutants that must be refuted, each at its own check: a second flop on ui_in[3], a
# second reader of uio_in[0]'s first stage, a latch, a loop, and a flop clocked by a flop
TOOTH = sed '/^endmodule/i wire tooth_hi, tooth_q, tooth_y;
sync_gate_teeth:
	mkdir -p sync_teeth
	$(TOOTH) sg13cmos5l_tiehi hi (.L_HI(tooth_hi)); sg13cmos5l_dfrbpq_1 tooth \
	  (.RESET_B(tooth_hi), .D(ui_in[3]), .Q(tooth_q), .CLK(clk));' $(NETLIST) > sync_teeth/sample.v
	$(TOOTH) sg13cmos5l_tiehi hi (.L_HI(tooth_hi)); sg13cmos5l_dfrbpq_1 tooth \
	  (.RESET_B(tooth_hi), .D(\\core.top.uio_meta[0] ), .Q(tooth_q), .CLK(clk));' \
	  $(NETLIST) > sync_teeth/stage.v
	$(TOOTH) sg13cmos5l_dlhq_1 tooth (.D(\\core.top.host_port.addr[0] ), \
	  .GATE(\\core.top.host_port.select ), .Q(tooth_q));' $(NETLIST) > sync_teeth/latch.v
	$(TOOTH) sg13cmos5l_inv_1 tooth (.A(tooth_y), .Y(tooth_y));' $(NETLIST) > sync_teeth/loop.v
	$(TOOTH) sg13cmos5l_tiehi hi (.L_HI(tooth_hi)); sg13cmos5l_dfrbpq_1 tooth \
	  (.RESET_B(tooth_hi), .D(tooth_hi), .Q(tooth_q), .CLK(\\core.top.host_port.select ));' \
	  $(NETLIST) > sync_teeth/clock.v
	$(MAKE) sync_gate NETLIST=sync_teeth/sample.v SYNC=sync_sample FAILS='ui_in_3_ reaches one flop'
	$(MAKE) sync_gate NETLIST=sync_teeth/stage.v SYNC=sync_stage FAILS='uio_in_0_ first stage reaches one flop'
	$(MAKE) sync_gate NETLIST=sync_teeth/latch.v SYNC=sync_latch FAILS='no latch'
	$(MAKE) sync_gate NETLIST=sync_teeth/loop.v SYNC=sync_loop FAILS='no combinational loop or undriven net'
	$(MAKE) sync_gate NETLIST=sync_teeth/clock.v SYNC=sync_clock FAILS='no flop or macro drives a clock'

# cadical (rel-3.0.1), cake_lpr and Certifaiger on the aiger library at pinned commits, in
# sat_tools/bin, for the kernel's checked QEDs (test/checked_unsat.ml) and the witnesses below
CADICAL = c60730422e758ef1cebe7aeddf2dda31c996bf04
CAKE_LPR = a36874a8b750b43fe4b385b8ddbf5b033e46a3fa
CERTIFAIGER = 079dc0e8477059cea8f4b168676f2dde4568829c
AIGER = 1876b273dc603d000d11da8ebbc099353ac42c6f
CAKE_LPR_ARCH = $(if $(filter arm64 aarch64,$(shell uname -m)),cake_lpr_arm8,cake_lpr)
sat_tools:
	rm -rf sat_tools && mkdir -p sat_tools/bin
	curl -fsSL https://github.com/arminbiere/cadical/archive/$(CADICAL).tar.gz | tar xz -C sat_tools
	cd sat_tools/cadical-$(CADICAL) && ./configure && $(MAKE) -j4
	cp sat_tools/cadical-$(CADICAL)/build/cadical sat_tools/bin/
	curl -fsSL https://github.com/tanyongkiam/cake_lpr/archive/$(CAKE_LPR).tar.gz | tar xz -C sat_tools
	cd sat_tools/cake_lpr-$(CAKE_LPR) && rm -f cake_lpr && $(MAKE) $(CAKE_LPR_ARCH)
	cp sat_tools/cake_lpr-$(CAKE_LPR)/cake_lpr sat_tools/bin/
	curl -fsSL https://github.com/arminbiere/aiger/archive/$(AIGER).tar.gz | tar xz -C sat_tools
	curl -fsSL https://github.com/Froleyks/certifaiger/archive/$(CERTIFAIGER).tar.gz \
	  | tar xz -C sat_tools
	cd sat_tools && $(CC) -O3 -c aiger-$(AIGER)/aiger.c -o aiger.o
	cd sat_tools && $(CXX) -std=c++23 -O3 -DNDEBUG -DVERSION='"10.3.1"' -DGITID='"$(CERTIFAIGER)"' \
	  -iquote aiger-$(AIGER) certifaiger-$(CERTIFAIGER)/src/certifaiger.cpp aiger.o -o bin/certifaiger

# Certifaiger witnesses for the step lemmas, the self-check's and the fail-safe's. The model
# is the lemma's prove task through SBY's aiger flow (witness/model.ys); rIC3 proves it by
# k-induction and writes a witness circuit; each SAT check Certifaiger makes must be UNSAT by
# an LRAT proof cake_lpr accepts. Trusted: the .sby and Verilog it reads, SBY's --dumpfiles
# and --dumpcfg, Yosys from parsing to write_aiger, model.ys, Certifaiger's checks and the
# aiger library, aigsplit, aigtocnf, cake_lpr's verified build, the C compilers, make and the
# shell; not rIC3 or cadical. Needs make sat_tools. phase_table's peaks at 30 GB and takes
# 6.5 h (rIC3 1.5 h, Inductive's check 4 h), past a hosted runner. CI proves the others
# (2.5 to 13 min, 4.3 GB); self_check_clean's Verilog comes from make self_check_clean, so it
# is not in WITNESSED.
WITNESSED = phase_step edge_step event_step frame_step value_step phase_table fail_safe
witness: engine.v engines.v kernel_step.v kernel_accepts.v
	for lemma in $(WITNESSED); do $(MAKE) witness_proof LEMMA=$$lemma || exit 1; done

CHECKS = Reset Safety Base Transition Liveness Decrease Closure Consistent Inductive
witness_proof:
	$(MAKE) witness_model TASK=prove W=$(LEMMA)_witness
	cd $(LEMMA)_witness && rIC3 -e kind model.aig witness.aig > ric3.log 2>&1; [ $$? = 20 ]
	cd $(LEMMA)_witness && certifaiger model.aig witness.aig check.aig > certifaiger.log
	cd $(LEMMA)_witness && aigsplit -n check.aig
	cd $(LEMMA)_witness && [ "$$(ls *.aig | grep -vx 'model.aig\|witness.aig\|check.aig' | sort | xargs)" \
	  = "$$(printf '%s.aig\n' $(CHECKS) | sort | xargs)" ]
	for check in $(CHECKS); do $(MAKE) witness_unsat W=$(LEMMA)_witness CHECK=$$check || exit 1; done
	$(MAKE) witness_teeth

# the task's [script] and [files] from the .sby, through witness/model.ys, in $(W)
witness_model:
	rm -rf $(W) && mkdir $(W)
	cp $$(sby --dumpfiles $(LEMMA).sby $(TASK)) $(W)
	sby --dumpcfg $(LEMMA).sby $(TASK) > $(W)/task.sby
	awk '/^\[/ { on = $$0 == "[script]"; next } on' $(W)/task.sby > $(W)/read.ys
	cd $(W) && yosys -q -l model.log ../witness/model.ys

# One check, UNSAT only if cake_lpr verifies the LRAT proof cadical pipes to it (on disk
# Inductive's would take GBs). Either side dying ends the other. HEAP is cake_lpr's in MB:
# 4096 passes all but phase_table's, which needs 24576.
WITNESS_HEAP_phase_table = 24576
HEAP = $(or $(WITNESS_HEAP_$(LEMMA)),4096)
witness_unsat:
	cd $(W) && aigtocnf $(CHECK).aig $(CHECK).cnf
	cd $(W) && { cadical -q --unsat --lrat=true -w $(CHECK).cadical $(CHECK).cnf -; \
	  echo $$? >> $(CHECK).cadical; } \
	  | cake_lpr --CML_HEAP_SIZE=$(HEAP) $(CHECK).cnf /dev/stdin > $(CHECK).cake 2>&1
	[ "$$(tail -n 1 $(W)/$(CHECK).cadical)" = 20 ]
	[ "$$(cat $(W)/$(CHECK).cake)" = "s VERIFIED UNSAT" ]
	rm $(W)/$(CHECK).cnf
	@echo "$(W): $(CHECK) verified"

# Each weakened copy the .sby expects to fail, through the same script: rIC3 must find a
# counterexample within the task's depth that aigsim replays to a bad state (so model.ys did
# not make the model vacuous), and Certifaiger must reject the lemma's witness. At least
# WITNESS_TEETH_<lemma> of them. A copy of other files than the prove task's, as the narrow
# core's, is another model and not a tooth.
WITNESS_TEETH_phase_step = 12
WITNESS_TEETH_edge_step = 5
WITNESS_TEETH_event_step = 5
WITNESS_TEETH_frame_step = 7
WITNESS_TEETH_value_step = 10
WITNESS_TEETH_phase_table = 5
WITNESS_TEETH_self_check_clean = 2
WITNESS_TEETH_fail_safe = 3
witness_teeth:
	teeth=0; for task in $$(sby --dumptasks $(LEMMA).sby); do \
	  sby --dumpcfg $(LEMMA).sby $$task | grep -qx 'expect fail' || continue; \
	  [ "$$(sby --dumpfiles $(LEMMA).sby $$task | sort)" \
	    = "$$(sby --dumpfiles $(LEMMA).sby prove | sort)" ] || continue; \
	  $(MAKE) witness_tooth TASK=$$task W=$(LEMMA)_witness_$$task || exit 1; \
	  teeth=$$((teeth + 1)); \
	done; \
	[ $$teeth -ge "$(WITNESS_TEETH_$(LEMMA))" ] \
	  || { echo "$(LEMMA): $$teeth teeth, want $(WITNESS_TEETH_$(LEMMA))"; exit 1; }

witness_tooth:
	$(MAKE) witness_model
	cd $(W) && rIC3 -e bmc --end $$(awk '$$1 == "depth" { print $$2 }' task.sby) --witness model.aig \
	  > ric3.log; [ $$? = 10 ]
	cd $(W) && sed -n '/^1$$/,/^\.$$/p' ric3.log > cex.aiw && aigsim -c model.aig cex.aiw
	$(MAKE) witness_reject

# One of the witness's checks is satisfiable, cheapest first. Anything else, a missing
# witness or a tool error, is an error and not a rejection.
witness_reject:
	cd $(W) && certifaiger model.aig ../$(LEMMA)_witness/witness.aig check.aig > certifaiger.log
	cd $(W) && aigsplit -n check.aig && for check in $(CHECKS); do \
	    aigtocnf $$check.aig $$check.cnf && cadical -q $$check.cnf > $$check.cadical; \
	    case $$? in 10) echo "$(W): $$check fails"; exit 0 ;; 20) ;; *) exit 1 ;; esac; \
	  done; exit 1

# The witnesses as a bundle rechecked with witness/check.sh and no OCaml: per witness the
# prove task's Verilog, read.ys, model.aig, witness.aig, and per tooth its read.ys, model.aig
# and aigsim's counterexample, plus cake_lpr's heap if not the default. Run after
# witness_proof. A witness of another task (W=fail_safe_table_witness_prove_0 TASK=prove_0)
# has no teeth.
BUNDLE = proof_bundle
SHA256 = $(if $(shell command -v sha256sum),sha256sum,shasum -a 256)
witness_bundle: W = $(LEMMA)_witness
witness_bundle: TASK = prove
witness_bundle:
	rm -rf $(BUNDLE)/$(subst _witness,,$(W)) && mkdir -p $(BUNDLE)/$(subst _witness,,$(W))/teeth
	for file in $$(sby --dumpfiles $(LEMMA).sby $(TASK)) read.ys model.aig witness.aig; do \
	  cp $(W)/$$(basename $$file) $(BUNDLE)/$(subst _witness,,$(W)) || exit 1; \
	done
	for tooth in $(W)_*/cex.aiw; do \
	  [ -f $$tooth ] || continue; \
	  dir=$(BUNDLE)/$(subst _witness,,$(W))/teeth/$$(dirname $$tooth | sed 's/^$(W)_//'); \
	  mkdir $$dir && cp $$(dirname $$tooth)/read.ys $$(dirname $$tooth)/model.aig $$tooth $$dir || exit 1; \
	done
	[ $$(ls $(BUNDLE)/$(subst _witness,,$(W))/teeth | wc -l) -ge "$(or $(WITNESS_TEETH_$(LEMMA)),0)" ]
	[ -z "$(WITNESS_HEAP_$(LEMMA))" ] || echo $(WITNESS_HEAP_$(LEMMA)) > $(BUNDLE)/$(subst _witness,,$(W))/heap

# check.sh, model.ys, tools.sh with the SAT tools' commits, and a sha256 of each file
proof_bundle:
	cp witness/check.sh witness/model.ys $(BUNDLE)
	sed -e 's/@CADICAL@/$(CADICAL)/' -e 's/@CAKE_LPR@/$(CAKE_LPR)/' \
	  -e 's/@CERTIFAIGER@/$(CERTIFAIGER)/' -e 's/@AIGER@/$(AIGER)/' witness/tools.sh > $(BUNDLE)/tools.sh
	chmod +x $(BUNDLE)/check.sh $(BUNDLE)/tools.sh
	cd $(BUNDLE) && find . -type f ! -name SHA256SUMS | sort | xargs $(SHA256) > SHA256SUMS
	tar czf $(BUNDLE).tar.gz $(BUNDLE)

# A copy of the bundle whose $(LEMMA) witness has one latch's next state inverted, its sum
# made to match, has to fail check.sh at one of the nine checks.
proof_bundle_tooth:
	rm -rf bundle_tooth && cp -R $(BUNDLE) bundle_tooth
	cd bundle_tooth/$(LEMMA) && aigtoaig witness.aig witness.aag \
	  && awk 'NR == 1 { inputs = $$3 } NR == inputs + 2 { $$2 += $$2 % 2 ? -1 : 1 } 1' witness.aag \
	  > flipped.aag && aigtoaig flipped.aag witness.aig && rm witness.aag flipped.aag
	! cmp -s $(BUNDLE)/$(LEMMA)/witness.aig bundle_tooth/$(LEMMA)/witness.aig
	cd bundle_tooth && find . -type f ! -name SHA256SUMS | sort | xargs $(SHA256) > SHA256SUMS
	! bundle_tooth/check.sh $(LEMMA) > bundle_tooth/check.log
	grep -E '^$(LEMMA): FAIL, [A-Za-z]+ not verified' bundle_tooth/check.log

.PHONY: witness witness_proof witness_model witness_unsat witness_teeth witness_tooth \
  witness_reject witness_bundle proof_bundle proof_bundle_tooth

.PHONY: all link link_proof issue_timing host_timing late_host fifo_order unreachable phase_step phase_table \
  phase_table_proof phase_table_affine phase_table_affine_proof phase_spacing \
  phase_spacing_proof edge_step event_step frame_step value_step chip_frame fail_safe \
  fail_safe_teeth fail_safe_table fail_safe_table_proof data_step teeth \
  inductive_write inductive_certificate inductive_proof inductive_certificates inductive_names \
  stamped_certificate stamped_proof data_certificate data_proof data_certificates data_names \
  netlist_equiv netlist_equiv_teeth netlist_anystate netlist_anystate_teeth \
  icepi_equiv icepi_equiv_teeth \
  sync_rtl sync_gate sync_rtl_teeth sync_gate_teeth \
  fsm_miter fsm_miter_proof verilog_in verilog_in_proof sram_equiv sram_equiv_proof \
  sram_equiv_step sram_equiv_teeth kernel_equiv kernel_equiv_proof kernel_miter sat_tools \
  narrow narrow_proof saturating saturating_proof saturating_chip self_check self_check_proof \
  self_check_clean self_check_clean_proof \
  powerup isolation isolation_proof offset_axioms translation translation_proof translation_tooth \
  frontend_equiv frontend_equiv_step
