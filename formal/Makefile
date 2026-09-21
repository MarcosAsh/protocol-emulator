all: issue_timing host_timing fifo_order teeth

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby prove

fifo_order: engine.v
	sby -f fifo_order.sby prove cover

# weakened statements, which pass only by failing
teeth: engine.v engine_sram.v
	sby -f fifo_order.sby stale_ahead
	sby -f host_timing.sby private_pull no_wait_excuse no_jump_excuse no_underflow_excuse no_overflow_excuse

.PHONY: all issue_timing host_timing fifo_order teeth
