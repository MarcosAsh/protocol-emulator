# The live die's data: the cells and wires of gds run RUN, and its netlist simulated
# sending "Jane St!". Needs gh, and env.sh sourced for cocotb, icarus and the PDK.
RUN ?= 36922636022
GDS ?= _build/$(RUN)

die.bin: ../../demo/live_die.py ../../demo/live_die_stimulus.py ../../demo/live_die_tb.v ../../demo/die.py ../../test/uart_tx.hex
	[ -d $(GDS)/runs ] || gh run download $(RUN) -R MarcosAsh/protocol-emulator -n GDS_logs -D $(GDS)
	python3 ../../demo/live_die.py $(GDS) -o $@ --build _build/sim

# the page as Pages serves it, at http://localhost:8000
serve:
	python3 -m http.server -d . 8000

clean:
	rm -rf _build

.PHONY: serve clean
