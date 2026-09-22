# The firmware words are committed, because the workflows that simulate have no OCaml.
# Stands alone so the check that they are current needs no cocotb: make -f firmware.mk
FIRMWARE = $(patsubst %.asm,%.hex,$(wildcard *.asm))

# The assembler refuses firmware that can miss a deadline. What a program has to assume
# about the world to pass goes here, beside the configuration its test loads it with.
uart_rx_wire.hex: ASSUME = -single-capture-edge -capture-pin 20 -capture-falling
uart_tx_host_rate.hex: ASSUME = -period 434
ethernet.hex: ASSUME = -period 64000

firmware: $(FIRMWARE)
%.hex: %.asm FORCE
	cd .. && dune exec -- bin/generate.exe assemble $(ASSUME) test/$< > test/$@.new
	mv $@.new $@
FORCE:
.PHONY: firmware
