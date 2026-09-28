all: issue_timing host_timing late_host fifo_order phase_step edge_step frame_step value_step \
  chip_frame data_step teeth fsm_miter sram_equiv \
  kernel_equiv

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

engines.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engines -engines 2 > formal/engines.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby prove

# a late host word can make a time-triggered program fault, never move a pin
late_host: engine_sram.v
	sby -f late_host.sby prove never_pushes

fifo_order: engine.v
	sby -f fifo_order.sby prove cover

kernel_step.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel > formal/kernel_step.v

# the step lemma under the universal certificate, for any program
phase_step: engine.v kernel_step.v
	sby -f phase_step.sby prove cover

kernel_accepts.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe kernel-accepts > formal/kernel_accepts.v

# The step lemma and the kernel's check in one run: no deadline is missed, for any program
# and any table of intervals the kernel accepts. About 20 min, so CI runs it in a job of
# its own on Verilog written already (phase_table_proof); each tooth must miss a deadline.
phase_table: engine.v kernel_step.v kernel_accepts.v
	$(MAKE) phase_table_proof

phase_table_proof:
	sby -f phase_table.sby prove cover
	sby -f phase_table.sby no_accepts no_open next_no_wrap target_is_next rows_while_running

# the edge lemma beside it: the pins change only the cycle after an entry that writes them
edge_step: engine.v
	sby -f edge_step.sby prove cover

# the frame lemma: a pin outside the engine's footprint keeps 0 from the clear on
frame_step: engine.v
	sby -f frame_step.sby prove cover

# the value lemma: what an out, a mov, an in, a push or a pull writes is the ISA's function
# of the shift registers, which hold what the ISA says from the clear on
value_step: engine.v
	sby -f value_step.sby prove cover

# and on the two-engine chip: two engines whose footprints share no pad each drive their
# pads as they would alone, and each reads as it would alone but where the other drives a
# bidirectional pad or can move a wire, and there reads what the other drives
chip_frame: engines.v
	sby -f chip_frame.sby prove pads_shared cover

osr_step.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe osr > formal/osr_step.v

# the data lemma: each out sends the bits of the word the osr last took that the osr
# kernel's count says, or the underflow fault is set
data_step: engine.v osr_step.v
	sby -f data_step.sby prove cover

# weakened statements, which pass only by failing
teeth: engine.v engine_sram.v engines.v kernel_step.v osr_step.v
	sby -f issue_timing.sby jump_in_one delay_ignores_side_set waits_are_plain
	sby -f fifo_order.sby stale_ahead
	sby -f phase_step.sby jump_in_one late_wait_waits no_carry one_late_cycle_is_safe taken_backwards \
	  second_edge level_at_arm later_edge_captured capture_a_cycle_older arm_one_short
	sby -f edge_step.sby pins_never_change side_set_only one_cycle_later flip_off_issue no_flip
	sby -f frame_step.sby narrow_side narrow_set narrow_out narrow_mov no_pair side_dirs_on_out \
	  no_wrap
	sby -f value_step.sby wrong_direction one_short no_invert reverse_wrong_width \
	  pull_past_threshold data_never_refused in_wrong_direction push_before_shift \
	  flip_at_outs_base flip_same_half
	sby -f chip_frame.sby overlap unbound read_everywhere
	sby -f data_step.sby wrong_way off_by_one stale_word
	sby -f host_timing.sby private_pull no_wait_excuse no_jump_excuse no_underflow_excuse no_overflow_excuse
	sby -f late_host.sby admit_fifo_wait admit_fifo_jump private_pull no_underflow_excuse \
	  no_overflow_excuse

# Each firmware's certificate from the analyser, as properties of the RTL for every input
# and every host, to the depth in certificate.sby. The cover run says how far into the
# firmware that depth reaches: a row it does not reach is not proven of that row, which is
# why the reached ones are printed. Only the properties failing is a failure here.
CERTIFIED = uart_tx spi_master ws2812
certificates: engine.v
	for name in $(CERTIFIED); do $(MAKE) certificate NAME=$$name || exit 1; done

# One firmware, at the depth in SBY. A firmware slow enough to need more than the depth
# certificate.sby carries is run on its own, which takes the better part of an hour:
#   make certificate NAME=uart_tx16 SBY=deep_certificate.sby
SBY = certificate.sby
certificate: engine.v
	(cd .. && dune exec -- test/certify/write_certificate.exe $(NAME)) > certificate.sv
	sby -f -d certificate_$(NAME)_bmc $(SBY) bmc
	-sby -f -d certificate_$(NAME)_cover $(SBY) cover
	@rows=$$(grep -c 'cover (entry' certificate.sv); \
	 missed=$$(grep -A99 'unreached cover statements' certificate_$(NAME)_cover/logfile.txt \
	   | grep -c 'certificate.sv:'); \
	 echo "$(NAME): $$((rows - missed)) of $$rows certified rows reached at this depth"

# The certificate of one firmware as an invariant proved by induction, which holds for
# all time and not only to a depth: make inductive_certificate NAME=uart_tx16. The teeth
# run adds one claim that is false in any run, because induction proves anything from an
# invariant no state satisfies, so it has to fail. inductive_proof runs the proof alone,
# on a certificate_$(NAME).sv written already, for CI, where make has no dune.
inductive_certificate: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive $(NAME)) > certificate_$(NAME).sv
	$(MAKE) inductive_proof NAME=$(NAME)

inductive_proof:
	cp certificate_$(NAME).sv certificate.sv
	sby -f -d certificate_$(NAME)_inductive certificate_inductive.sby prove
	sby -f -d certificate_$(NAME)_teeth certificate_inductive.sby teeth

# Every frame uart_tx_stamped sends carries the low 16 bits of the cycle its start bit
# shows on the pin, and the pin shows those bits: its certificate as above with that
# claim added. Teeth: the stamp a cycle late has to fail from reset, and the pin showing
# the next bit has to fail the step.
stamped_certificate: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive -stamped uart_tx_stamped) > certificate_stamped.sv
	$(MAKE) stamped_proof

stamped_proof:
	cp certificate_stamped.sv certificate.sv
	sby -f -d certificate_stamped_inductive certificate_inductive.sby prove
	sby -f --prefix certificate_stamped certificate_inductive.sby teeth off_by_one next_bit

# Which bits of which host word the pins carry, for the transmitters that pull each word by
# hand and send it through the osr alone: their certificate as above with the data claims
# of write_certificate.ml added. Teeth: the pins showing the bit after the one sent has to
# fail.
DATA = uart_tx uart_tx16 uart_tx_host_rate spi_master jtag
data_certificate: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -inductive -data $(NAME)) > certificate_data_$(NAME).sv
	$(MAKE) data_proof NAME=$(NAME)

data_proof:
	cp certificate_data_$(NAME).sv certificate.sv
	sby -f -d certificate_data_$(NAME)_inductive certificate_inductive.sby prove
	sby -f --prefix certificate_data_$(NAME) certificate_inductive.sby teeth next_bit

data_certificates: engine_sram.v
	for name in $(DATA); do $(MAKE) data_certificate NAME=$$name || exit 1; done

data_names:
	@echo $(DATA)

# Every firmware in test/certified.ml, each under what its entry there says it assumes,
# which the certificate prints: nothing for most; for the firmware that waits on the host
# or anchors on a captured edge, that the core is within 84 ms of its deadline and of that
# edge, since 24 bits of the difference wrap beyond it.
INDUCTIVE = uart_tx uart_tx16 uart_tx_host_rate uart_rx spi_master spi_slave i2c_master \
  i2c_slave i2c_logger usb_tx usb_rx usb_device edge_meter ws2812 ethernet one_wire ps2 jtag \
  uart_tx_stream spi_master_stream
inductive_certificates: engine_sram.v
	for name in $(INDUCTIVE); do $(MAKE) inductive_certificate NAME=$$name || exit 1; done

# CI writes each of these and proves it in a job of its own
inductive_names:
	@echo $(INDUCTIVE)

# the fsm compiler's miter (write_certificate.ml -fsm): Uart.Tx of hardcaml_hobby_boards,
# unmodified, beside the engine running its compiled firmware; proof ~20 s, teeth ~1.5 min.
# fsm_miter_proof runs on files written already, for CI.
fsm_miter: engine_sram.v
	(cd .. && dune exec -- test/certify/write_certificate.exe -fsm) > fsm_miter.sv
	(cd .. && dune exec -- test/certify/write_certificate.exe -fsm -mutant) > fsm_miter_mutant.sv
	$(MAKE) fsm_miter_proof

fsm_miter_proof:
	sby -f fsm_miter.sby prove short_gap early mutant

memory_flops.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe memory > formal/memory_flops.v

memory_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe memory -sram > formal/memory_sram.v

# the flop program memory is IHP's model of the macro, step for step from any equal state
# (sram_equiv/step.tcl), which is what lets the lemmas and netlist_equiv cut the macro;
# then the model's own cases and the teeth. About 45 s; sram_equiv_proof runs on files
# written already.
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

# mutants of the model that must be refuted: dout reading the word before the write, not
# through it; bit 0 of the mask dropped from the write; and each word stored with bit 15
# flipped when bit 0 is set, which is the model again from all-zero contents and so passes
# there (sram_equiv/zero.tcl), but not from any
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

# the kernel's step and its check of a row, as the Verilog the RTL proofs read, are the
# gates its SAT proofs build (kernel_equiv/miter.ys); each with one gate flipped must
# fail. About 15 s; kernel_equiv_proof runs on files written already.
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

# the hardened netlist equals the RTL, macros cut (netlist_equiv/miter.ys); about 2 min:
#   make netlist_equiv NETLIST=../runs/wokwi/final/nl/tt_um_marcosash_protocol_emulator.nl.v
STDCELL = $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell
EQUIV = netlist_equiv_run
EXPECT = 1
WRITTEN = ../src/protocol_emulator.v
FSM_STEP = timeout 600 yosys-abc -c 'read_aiger fsm_step.aig; print_stats; pdr; print_status'
netlist_equiv:
	rm -rf $(EQUIV) && mkdir $(EQUIV)
	cp $(NETLIST) $(EQUIV)/netlist.v
	cp $(WRITTEN) $(EQUIV)/written.v
	sed -e '/^\s*specify/,/^\s*endspecify/d' -e 's/delayed_//g' \
	  -e 's/^\(\s*\)\(ihp_[a-z0-9_]*\) *(\([A-Za-z0-9_]*\),/\1\2 u_\3 (\3,/' \
	  $(STDCELL)/verilog/sg13cmos5l_stdcell.v > $(EQUIV)/cells.v
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
# synchroniser untied (its counterexample must pass the first cycle), and the written
# host port's state held, against fsm_step
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

.PHONY: all issue_timing host_timing late_host fifo_order phase_step phase_table \
  phase_table_proof edge_step frame_step value_step chip_frame data_step teeth certificates \
  certificate inductive_certificate inductive_proof inductive_certificates inductive_names \
  stamped_certificate stamped_proof data_certificate data_proof data_certificates data_names \
  netlist_equiv netlist_equiv_teeth fsm_miter fsm_miter_proof sram_equiv sram_equiv_proof \
  sram_equiv_step sram_equiv_teeth kernel_equiv kernel_equiv_proof kernel_miter
