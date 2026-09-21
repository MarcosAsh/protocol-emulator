all: issue_timing host_timing fifo_order

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby

fifo_order: engine.v
	sby -f fifo_order.sby prove cover

.PHONY: all issue_timing host_timing fifo_order
