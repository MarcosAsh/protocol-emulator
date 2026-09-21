all: issue_timing host_timing

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

engine_sram.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine -sram > formal/engine_sram.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

host_timing: engine_sram.v
	sby -f host_timing.sby

.PHONY: all issue_timing host_timing
