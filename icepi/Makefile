# The chip on an Icepi Zero (ECP5 LFE5U-25F): make [REV=v1.4] [USB=1] [SEEDS='1 2'], then
# make prog to load it or make flash to keep it. USB=0 puts uio[1:0] on the header too.
# The .sha256 file lists the bitstream and the netlist it came from, and make equiv proves
# that netlist equal to the RTL (formal/icepi_equiv).
# FS=1 pulls D+ up for full speed USB instead of D-, and names the bitstream differently.
# PROBE=1 puts D+ and D- on header 8 and 12 instead of OUT0 and OUT2, for an analyser.
# MHZ=40 clocks the chip at 40 MHz for 10BASE-T. USB defaults to 0 then, since low speed
# USB needs 48. The bitstream is named differently. The SRAM macro is its IHP behavioural
# model, which yosys maps to block RAM.

REV ?= v1.4
MHZ ?= 48
ifeq ($(filter 40 48,$(MHZ)),)
$(error MHZ is 48, or 40 for 10BASE-T, not $(MHZ))
endif
USB ?= $(if $(filter 40,$(MHZ)),0,1)
SEED ?= 1
FS ?= 0
PROBE ?= 0
# 48 MHz is tight and placement depends on the seed, so we take the first seed whose clock
# reaches MARGIN MHz over MHZ (the same netlist always gets the same one). The PLL's
# constraint comes from the clk port in $(REV).lpf. Scaling it doesn't move any seed's
# placement, so the margin belongs to the seed, not the target.
SEEDS ?= 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16
MARGIN ?= 1.6

BUILD = build
CLOCK = $(if $(filter-out 48,$(MHZ)),-$(MHZ)mhz)
NAME = $(REV)$(if $(filter 0,$(USB)),-header)$(if $(filter 1,$(FS)),-fs)$(if $(filter 1,$(PROBE)),-probe)$(CLOCK)
JSON = $(BUILD)/usb$(USB)$(if $(filter 1,$(FS)),-fs)$(if $(filter 1,$(PROBE)),-probe)$(CLOCK).json
SOURCES = icepi_top.v ../src/project.v ../src/protocol_emulator.v \
	../test/models/RM_IHPSG13_1P_512x16_c2_bm_bist.v \
	../test/models/RM_IHPSG13_1P_core_behavioral_bm_bist.v

bit: $(BUILD)/$(NAME).bit

$(JSON): $(SOURCES)
	mkdir -p $(BUILD)
	yosys -q -l $(JSON:.json=.log) -p "read_verilog -DFUNCTIONAL $(SOURCES); \
		chparam -set USB_UIO $(USB) -set MHZ $(MHZ) -set FULL_SPEED $(FS) -set USB_PROBE $(PROBE) icepi_top; synth_ecp5 -top icepi_top -json $@"

$(BUILD)/$(NAME).config: $(JSON) header.lpf $(REV).lpf
	rm -f $@
	for seed in $(SEEDS); do \
	  nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --lpf header.lpf \
	    --lpf $(REV).lpf --seed $$seed --placer-heap-timingweight 80 --textcfg $@ \
	    --report $(BUILD)/$(NAME).report.json --log $(BUILD)/$(NAME).log -q \
	    && awk '/Max frequency/ { f = $$(NF - 5) } END { exit !(f >= $(MHZ) + $(MARGIN)) }' \
	      $(BUILD)/$(NAME).log \
	    && echo "seed $$seed" && break; \
	  rm -f $@; \
	done; test -f $@
	grep -h "Max frequency\|TRELLIS_COMB:\|TRELLIS_FF:\|DP16KD:" $(BUILD)/$(NAME).log | tail -5

$(BUILD)/$(NAME).bit: $(BUILD)/$(NAME).config
	ecppack --compress --input $< --bit $@
	cd $(BUILD) && sha256sum $(notdir $(JSON)) $(NAME).bit > $(NAME).sha256

equiv: $(JSON)
	$(MAKE) -C ../formal icepi_equiv ICEPI_JSON=$(abspath $(JSON)) USB=$(USB) MHZ=$(MHZ) \
	  FS=$(FS) PROBE=$(PROBE)

# openFPGALoader knows the board (bit-banged JTAG over its FT231X)
prog: $(BUILD)/$(NAME).bit
	openFPGALoader -b icepi-zero $<

flash: $(BUILD)/$(NAME).bit
	openFPGALoader -b icepi-zero --write-flash $<

# The bench carrier's self-test in place of the chip (carrier_check.v, demo/carrier_check.sh).
# make check-prog loads it into SRAM only, so openFPGALoader -r brings the chip back.
CHECK = $(BUILD)/$(REV)-carrier-check

check: $(CHECK).bit

$(BUILD)/carrier_check.json: carrier_check.v
	mkdir -p $(BUILD)
	yosys -q -l $(BUILD)/carrier_check.log -p "read_verilog carrier_check.v; synth_ecp5 -top carrier_check -json $@"

$(CHECK).config: $(BUILD)/carrier_check.json header.lpf carrier_check.lpf $(REV).lpf
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --lpf header.lpf \
		--lpf carrier_check.lpf --lpf $(REV).lpf --freq 50 --seed $(SEED) --textcfg $@ \
		--log $(CHECK).log -q

$(CHECK).bit: $(CHECK).config
	ecppack --compress --input $< --bit $@

check-prog: $(CHECK).bit
	openFPGALoader -b icepi-zero $<

# Usb_frame_rx alone on the first USB-C port at full speed (usb_fs_check.v,
# demo/usb_fs_check.py). make usb-fs-prog loads it into SRAM only, like check-prog.
USB_FS = $(BUILD)/$(REV)-usb-fs-check

usb-fs-check: $(USB_FS).bit

$(BUILD)/usb_frame_rx.v:
	mkdir -p $(BUILD)
	cd .. && dune exec --root . bin/generate.exe -- usb-rx > icepi/$@

$(BUILD)/usb_fs_check.json: usb_fs_check.v $(BUILD)/usb_frame_rx.v
	yosys -q -l $(BUILD)/usb_fs_check.log -p "read_verilog $^; synth_ecp5 -top usb_fs_check -json $@"

$(USB_FS).config: $(BUILD)/usb_fs_check.json header.lpf $(REV).lpf
	nextpnr-ecp5 --25k --package CABGA256 --speed 6 --json $< --lpf header.lpf \
		--lpf $(REV).lpf --freq 48 --seed $(SEED) --textcfg $@ --log $(USB_FS).log -q
	grep -h "Max frequency" $(USB_FS).log | tail -2

$(USB_FS).bit: $(USB_FS).config
	ecppack --compress --input $< --bit $@

usb-fs-prog: $(USB_FS).bit
	openFPGALoader -b icepi-zero $<

clean:
	rm -rf $(BUILD)

.PHONY: bit equiv prog flash check check-prog usb-fs-check usb-fs-prog clean
