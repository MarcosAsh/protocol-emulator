# The live die's data: the cells and wires of gds run RUN, and its netlist simulated
# sending "Jane St!". Needs gh, dune, and env.sh sourced for cocotb, icarus and the PDK.
RUN ?= 36922636022
GDS ?= _build/$(RUN)
PROVENANCE = _build/provenance.json

# the src line of each name in the RTL as it is here, which has to be what the run hardened
$(PROVENANCE): $(wildcard ../../src/*.ml) ../../bin/generate.ml
	mkdir -p _build
	cd ../.. && dune exec -- bin/generate.exe provenance -sram -engines 2 > pages/die/$@

die.bin: ../../demo/live_die.py ../../demo/live_die_stimulus.py ../../demo/live_die_tb.v ../../demo/die.py ../../test/uart_tx.hex $(PROVENANCE)
	[ -d $(GDS)/runs ] || gh run download $(RUN) -R MarcosAsh/protocol-emulator -n GDS_logs -D $(GDS)
	cmp $(GDS)/src/protocol_emulator.v ../../src/protocol_emulator.v
	python3 ../../demo/live_die.py $(GDS) --provenance $(PROVENANCE) -o $@ --build _build/sim

# the page as Pages serves it, at http://localhost:8000
serve:
	python3 -m http.server -d . 8000

clean:
	rm -rf _build

.PHONY: serve clean
