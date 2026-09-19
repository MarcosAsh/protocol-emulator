all: issue_timing

engine.v: ../src/*.ml
	cd .. && dune exec -- bin/generate.exe engine > formal/engine.v

issue_timing: engine.v
	sby -f issue_timing.sby prove cover

.PHONY: all issue_timing
