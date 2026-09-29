# The firmware words are committed, because the workflows that simulate have no OCaml.
# Stands alone so the check that they are current needs no cocotb: make -f firmware.mk
FIRMWARE = $(patsubst %.asm,%.hex,$(wildcard *.asm))

# The assembler refuses firmware that can miss a deadline. What a program has to assume
# about the world to pass goes here, beside the configuration its test loads it with.
uart_rx_wire.hex: ASSUME = -single-capture-edge -capture-pin 20 -capture-falling
uart_tx_host_rate.hex: ASSUME = -period 434
ethernet.hex: ASSUME = -period 64000 -autopull-data 16
data_stream.hex: ASSUME = -autopull-data 16
# The checker loads its bit periods from the data memory, where the kernel takes one
# constant; test_self_check.ml has the analyser check it from its least period up.
self_check_wire.hex: ASSUME = -no-timing-check

# What self_check_wire checks uart_tx_host_rate's frames against, start bit to stop bit,
# above the data memory's low half.
ROWS = uart_tx_host_rate_rows.hex
uart_tx_host_rate_rows.hex: uart_tx_host_rate.asm FORCE
	cd .. && dune exec -- bin/generate.exe self-check -period 434 -first 8 -last 14 -base 256 test/$< > test/$@.new
	mv $@.new $@

firmware: $(FIRMWARE) $(ROWS)
%.hex: %.asm FORCE
	cd .. && dune exec -- bin/generate.exe assemble $(ASSUME) test/$< > test/$@.new
	mv $@.new $@
FORCE:
.PHONY: firmware
