# The chip on an Icepi Zero (ECP5 LFE5U-25F): make [REV=v1.4] [USB=1] [SEED=1], then
# make prog to load it or make flash to keep it. USB=0 puts uio[1:0] on the header too.
# MHZ=40 clocks the chip at 40 MHz for 10BASE-T, with USB=0 unless told, since low speed
# USB needs 48, and names its bitstream apart. The SRAM macro is its IHP behavioural model,
# which yosys maps to block RAM.

REV ?= v1.4
MHZ ?= 48
ifeq ($(filter 40 48,$(MHZ)),)
$(error MHZ is 48, or 40 for 10BASE-T, not $(MHZ))
endif
USB ?= $(if $(filter 40,$(MHZ)),0,1)
SEED ?= 1
FREQ ?= $(MHZ)

BUILD = build
CLOCK = $(if $(filter-out 48,$(MHZ)),-$(MHZ)mhz)
NAME = $(REV)$(if $(filter 0,$(USB)),-header)$(CLOCK)
JSON = $(BUILD)/usb$(USB)$(CLOCK).json
SOURCES = icepi_top.v ../src/project.v ../src/protocol_emulator.v \
	../test/models/RM_IHPSG13_1P_512x16_c2_bm_bist.v \
	../test/models/RM_IHPSG13_1P_core_behavioral_bm_bist.v

bit: $(BUILD)/$(NAME).bit

$(JSON): $(SOURCES)
	mkdir -p $(BUILD)
	yosys -q -l $(JSON:.json=.log) -p "read_verilog -DFUNCTIONAL $(SOURCES); \
		chparam -set USB_UIO $(USB) -set MHZ $(MHZ) icepi_top; synth_ecp5 -top icepi_top -json $@"

$(BUILD)/$(NAME).config: $(JSON) header.lpf $(REV).lpf
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --lpf header.lpf \
		--lpf $(REV).lpf --freq $(FREQ) --seed $(SEED) --textcfg $@ \
		--report $(BUILD)/$(NAME).report.json --log $(BUILD)/$(NAME).log -q
	grep -h "Max frequency\|TRELLIS_COMB:\|TRELLIS_FF:\|DP16KD:" $(BUILD)/$(NAME).log | tail -5

$(BUILD)/$(NAME).bit: $(BUILD)/$(NAME).config
	ecppack --compress --input $< --bit $@

# openFPGALoader knows the board: its FT231X's bit-banged JTAG
prog: $(BUILD)/$(NAME).bit
	openFPGALoader -b icepi-zero $<

flash: $(BUILD)/$(NAME).bit
	openFPGALoader -b icepi-zero --write-flash $<

clean:
	rm -rf $(BUILD)

.PHONY: bit prog flash clean
