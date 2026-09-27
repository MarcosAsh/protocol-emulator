all: issue_timing host_timing late_host fifo_order phase_step edge_step frame_step value_step \
  chip_frame teeth

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

# weakened statements, which pass only by failing
teeth: engine.v engine_sram.v engines.v kernel_step.v
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

.PHONY: all issue_timing host_timing late_host fifo_order phase_step edge_step frame_step \
  value_step chip_frame teeth certificates certificate inductive_certificate inductive_proof \
  inductive_certificates inductive_names stamped_certificate stamped_proof
