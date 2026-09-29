# The chip on an Icepi Zero (ECP5 LFE5U-25F): make [REV=v1.4] [USB=1] [SEED=1], then
# make prog to load it or make flash to keep it. USB=0 puts uio[1:0] on the header too.
# The SRAM macro is its IHP behavioural model, which yosys maps to block RAM.

REV ?= v1.4
USB ?= 1
SEED ?= 1
FREQ ?= 48

BUILD = build
NAME = $(REV)$(if $(filter 0,$(USB)),-header)
SOURCES = icepi_top.v ../src/project.v ../src/protocol_emulator.v \
	../test/models/RM_IHPSG13_1P_512x16_c2_bm_bist.v \
	../test/models/RM_IHPSG13_1P_core_behavioral_bm_bist.v

bit: $(BUILD)/$(NAME).bit

$(BUILD)/usb$(USB).json: $(SOURCES)
	mkdir -p $(BUILD)
	yosys -q -l $(BUILD)/usb$(USB).log -p "read_verilog -DFUNCTIONAL $(SOURCES); \
		chparam -set USB_UIO $(USB) icepi_top; synth_ecp5 -top icepi_top -json $@"

$(BUILD)/$(NAME).config: $(BUILD)/usb$(USB).json header.lpf $(REV).lpf
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
