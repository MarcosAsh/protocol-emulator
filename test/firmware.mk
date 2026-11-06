# The firmware words are committed because the simulation workflows have no OCaml.
# This file stands alone so the freshness check needs no cocotb: make -f firmware.mk
FIRMWARE = $(patsubst %.asm,%.hex,$(wildcard *.asm))
# what the chip checks each firmware against before starting it, under the same assumptions
CERTIFICATES = $(patsubst %.asm,%.cert.hex,$(wildcard *.asm))

# The assembler refuses firmware that can miss a deadline. Whatever a program must assume
# about the world to pass is listed here, next to the configuration its test loads.
uart_rx_wire.hex uart_rx_wire.cert.hex: ASSUME = -single-capture-edge -capture-pin 20 -capture-falling
uart_tx_host_rate.hex uart_tx_host_rate.cert.hex: ASSUME = -period-floor 4
ethernet.hex ethernet.cert.hex: ASSUME = -period 64000 -autopull-data 16
data_stream.hex data_stream.cert.hex: ASSUME = -autopull-data 16
ethernet_rx.hex ethernet_rx.cert.hex: ASSUME = -autopull-data 16
# The checker loads one bit period per edge from its rows, each >= min_gap.
self_check_wire.hex self_check_wire.cert.hex: ASSUME = -period-floor 17 -capture-pin 20 -capture-falling \
  -autopull-data 16

# The rows self_check_wire checks uart_tx_host_rate's frames against (start bit to stop
# bit), stored above the low half of data memory.
ROWS = uart_tx_host_rate_rows.hex
uart_tx_host_rate_rows.hex: uart_tx_host_rate.asm FORCE
	cd .. && dune exec -- bin/generate.exe self-check -period 434 -first 8 -last 14 -base 256 test/$< > test/$@.new
	mv $@.new $@

# A predicate's host budget is the period on every load of it, taken from the settings
# file the compiler wrote next to it.
host_budget = $(shell awk '$$1 == "budget_from_host" { print "-period", $$2 }' $(1).settings 2>/dev/null)

firmware: $(FIRMWARE) $(CERTIFICATES) $(ROWS)
%.cert.hex: %.asm FORCE
	cd .. && dune exec -- bin/generate.exe assemble -certificate $(ASSUME) $(call host_budget,$*) test/$< > test/$@.new
	mv $@.new $@
%.hex: %.asm FORCE
	cd .. && dune exec -- bin/generate.exe assemble $(ASSUME) $(call host_budget,$*) test/$< > test/$@.new
	mv $@.new $@
FORCE:
.PHONY: firmware
