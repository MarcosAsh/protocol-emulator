# The firmware words are committed, because the workflows that simulate have no OCaml.
# Stands alone so the check that they are current needs no cocotb: make -f firmware.mk
FIRMWARE = $(patsubst %.asm,%.hex,$(wildcard *.asm))
# what the chip checks each against before it starts it, under the same assumptions
CERTIFICATES = $(patsubst %.asm,%.cert.hex,$(wildcard *.asm))

# The assembler refuses firmware that can miss a deadline. What a program has to assume
# about the world to pass goes here, beside the configuration its test loads it with.
uart_rx_wire.hex uart_rx_wire.cert.hex: ASSUME = -single-capture-edge -capture-pin 20 -capture-falling
uart_tx_host_rate.hex uart_tx_host_rate.cert.hex: ASSUME = -period 434
ethernet.hex ethernet.cert.hex: ASSUME = -period 64000 -autopull-data 16
data_stream.hex data_stream.cert.hex: ASSUME = -autopull-data 16
# The checker loads a bit period per edge from its rows, each min_gap or more.
self_check_wire.hex self_check_wire.cert.hex: ASSUME = -period-floor 17 -capture-pin 20 -capture-falling \
  -autopull-data 16

# What self_check_wire checks uart_tx_host_rate's frames against, start bit to stop bit,
# above the data memory's low half.
ROWS = uart_tx_host_rate_rows.hex
uart_tx_host_rate_rows.hex: uart_tx_host_rate.asm FORCE
	cd .. && dune exec -- bin/generate.exe self-check -period 434 -first 8 -last 14 -base 256 test/$< > test/$@.new
	mv $@.new $@

# A predicate's budget from the host is the period every load of p carries, from the
# settings the compiler wrote beside it.
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
