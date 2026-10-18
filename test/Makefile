# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(CURDIR)/../src
PROJECT_SOURCES = project.v protocol_emulator.v

ifeq ($(FPGA),yes)

# The netlist yosys synthesises for the FPGA kit's iCE40, from `make fpga_netlist.v`:
SIM_BUILD				= sim_build/fpga
VERILOG_SOURCES += $(shell yosys-config --datdir)/ice40/cells_sim.v
VERILOG_SOURCES += $(CURDIR)/fpga_netlist.v

else ifeq ($(ICEPI),yes)

# The Icepi Zero's top synthesised for its ECP5, from `make icepi_netlist.v`, on yosys'
# cell models. Its block RAM model is empty, so models/ has one, and a PLL that passes the
# testbench's clock through:
SIM_BUILD				= sim_build/icepi
ECP5_SIM = $(shell yosys-config --datdir)/ecp5
COMPILE_ARGS    += -I$(ECP5_SIM)
VERILOG_SOURCES += $(ECP5_SIM)/common_sim.vh $(ECP5_SIM)/ccu2c_sim.vh
VERILOG_SOURCES += $(CURDIR)/models/DP16KD.v $(CURDIR)/models/EHXPLLL.v $(CURDIR)/icepi_netlist.v

else ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
COMPILE_ARGS    += -DFUNCTIONAL
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES)) models/RM_IHPSG13_1P_core_behavioral_bm_bist.v models/RM_IHPSG13_1P_512x16_c2_bm_bist.v
# Verilator is some fifteen times icarus's speed, for the rehearsal of the bench's real
# milliseconds: make SIM=verilator COCOTB_TEST_MODULES=test_demo
ifeq ($(SIM),verilator)
SIM_BUILD				= sim_build/verilator
COMPILE_ARGS    += --no-timing -Wno-fatal -Wno-lint -Wno-style
endif

else

# Gate level simulation:
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_io/verilog/sg13cmos5l_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_udp.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_stdcell.v
VERILOG_SOURCES += models/RM_IHPSG13_1P_core_behavioral_bm_bist.v models/RM_IHPSG13_1P_512x16_c2_bm_bist.v

ifeq ($(SDF),)
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DFUNCTIONAL
# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(CURDIR)/gate_level_netlist.v
else
# With SDF= a corner's SDF from icarus_sdf.py the cells and macros keep their specify
# blocks and take its delays, on the netlist with the macros renamed as it renames them:
SIM_BUILD				= sim_build/sdf
COMPILE_ARGS    += -gspecify -ginterconnect -DSDF
COCOTB_PLUSARGS += +sdf=$(abspath $(SDF))
VERILOG_SOURCES += $(CURDIR)/sim_build/sdf/gate_level_netlist.v
endif

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
ifeq ($(ICEPI),yes)
VERILOG_SOURCES += $(CURDIR)/tb_icepi.v
TOPLEVEL = tb
else ifeq ($(OUTSIDE),yes)
VERILOG_SOURCES += $(CURDIR)/tb_outside.v $(CURDIR)/models/spiflash.v
TOPLEVEL = tb_outside
else
VERILOG_SOURCES += $(CURDIR)/tb.v
TOPLEVEL = tb
endif

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test,test_usb_board,test_ethernet,test_dshot_sent_cec
# the kit build has one engine, the chip two
ifneq ($(FPGA),yes)
COCOTB_TEST_MODULES := $(COCOTB_TEST_MODULES),test_two_engines,test_board_blame
endif
GATE_TEST_MODULES := $(COCOTB_TEST_MODULES)
# the bench demos' rehearsals simulate milliseconds, so on the RTL alone
ifeq ($(FPGA)$(GATES)$(ICEPI),)
COCOTB_TEST_MODULES := $(COCOTB_TEST_MODULES),test_demo,test_swd,test_demo_board,test_pyocd
endif

# Where there is a dune the firmware words are reassembled first, so an encoding change
# reaches them. The default stays cocotb's, though firmware.mk brings the first rule.
.DEFAULT_GOAL := all
include firmware.mk
ifneq ($(shell command -v dune),)
CUSTOM_SIM_DEPS += $(FIRMWARE) $(ROWS)
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# The kit has no SRAM macro, so the program memory is the flop variant, which yosys
# maps to block RAM.
fpga_netlist.v: $(SRC_DIR)/project.v $(wildcard $(SRC_DIR)/*.ml) $(SRC_DIR)/../bin/generate.ml
	cd .. && dune exec -- bin/generate.exe top > test/fpga_top.v
	yosys -q -p "read_verilog $(SRC_DIR)/project.v fpga_top.v; synth_ice40 -top tt_um_marcosash_protocol_emulator; write_verilog -noattr fpga_netlist.v"

# The kit's own top and pin file through place and route: the design has to fit the
# iCE40 UP5K and hold the clock the kit demos run at.
FPGA_MHZ ?= 16
fpga_fit: fpga_netlist.v
	sed "s/__tt_um_placeholder/tt_um_marcosash_protocol_emulator/" ../tt/fpga/tt_fpga_top.v > fpga_kit_top.v
	yosys -q -p "read_verilog -sv fpga_kit_top.v $(SRC_DIR)/project.v fpga_top.v; synth_ice40 -top tt_fpga_top -json fpga_kit.json"
	nextpnr-ice40 --up5k --package sg48 --json fpga_kit.json --pcf ../tt/fpga/tt_fpga_top.pcf --pcf-allow-unconstrained --freq $(FPGA_MHZ) --seed 1 -q --log fpga_kit.log --asc fpga_kit.asc
	grep -h "ICESTORM_LC:\|Max frequency" fpga_kit.log | tail -3

# The bitstream for Tiny Tapeout's classic FPGA breakout, which the release carries.
fpga_kit.bin: fpga_fit
	icepack fpga_kit.asc $@

# The Icepi Zero's netlist, as its own flow in ../icepi synthesises it.
icepi_netlist.v: $(SRC_DIR)/project.v $(SRC_DIR)/protocol_emulator.v ../icepi/icepi_top.v
	$(MAKE) -C ../icepi build/usb1.json
	yosys -q -p "read_json ../icepi/build/usb1.json; write_verilog -noattr icepi_netlist.v"

# The outside chip acts of BRINGUP.md on the RTL, against picosoc's SPI flash model,
# cocotbext-i2c's memory and cocotbext-spi's loopback slave, each capture judged by sigrok's
# decoders. Needs cocotbext-i2c 0.1.2, cocotbext-spi 0.5.0 with cocotb-bus 0.3.0, and
# sigrok-cli beside cocotb.
outside:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_outside \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_outside.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_outside.xml

# demo_both_roles.py and demo_rates.py on the RTL beside the outside chip demos' models,
# as the bench runs them: make both_roles. Needs what outside needs.
both_roles:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_both_roles_bench \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_both_roles.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_both_roles.xml

# demo_tolerance.py on the RTL, shortened to simulate: make tolerance_bench. Needs what
# outside needs.
tolerance_bench:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_tolerance_bench \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_tolerance_bench.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_tolerance_bench.xml

# A remote lab job's firmware.json on the RTL as Pico A runs it, for demo/lab.py's rtl
# backend: make lab LAB_FIRMWARE=DIR/firmware.json LAB_OUT=DIR. Needs what outside needs;
# the firmware is not reassembled, so no dune runs. test/lab is the examples' folder.
.PHONY: lab
lab:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_lab_rtl \
		PLUSARGS=+firmware=/dev/null CUSTOM_SIM_DEPS= \
		COCOTB_RESULTS_FILE=results_lab.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_lab.xml

# icepi/carrier_check.v, the bench carrier's self-test bitstream, on its own pulls and
# models/ecp5_pads.v: make carrier_check
carrier_check:
	$(MAKE) sim TOPLEVEL=tb_carrier_check SIM_BUILD=sim_build/carrier_check CUSTOM_SIM_DEPS= \
		VERILOG_SOURCES="$(CURDIR)/tb_carrier_check.v $(CURDIR)/../icepi/carrier_check.v \
		$(CURDIR)/models/ecp5_pads.v" \
		COCOTB_TEST_MODULES=test_carrier_bitstream COCOTB_RESULTS_FILE=results_carrier_check.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_carrier_check.xml

# Replays the pin traces in traces/, recorded from the OCaml simulation of the top, on
# whichever netlist the mode selects: make replay, make replay GATES=yes, FPGA=yes or
# ICEPI=yes.
replay:
	$(MAKE) sim COCOTB_TEST_MODULES=test_replay COCOTB_RESULTS_FILE=results_replay.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_replay.xml

# The gate level's tests and replays with the router's delays at one corner (sdf_slow,
# sdf_typ, sdf_fast) or all three (sdf), from the flow's SDF in SDF_DIR, at the chip's
# 50 MHz, in one run each since annotating takes minutes. Icarus has no timing checks, so a
# violation shows only as a wrong value.
SDF_DIR ?= ../runs/wokwi/final/sdf
CORNERS = slow typ fast
sdf_file = $(or $(wildcard $(SDF_DIR)/nom_$(1)_*/*.sdf),$(error no $(1) SDF in $(SDF_DIR)))
$(CURDIR)/sim_build/sdf/gate_level_netlist.v: gate_level_netlist.v icarus_sdf.py
	mkdir -p $(@D)
	$(PYTHON_BIN) icarus_sdf.py netlist < $< > $@
sdf: $(addprefix sdf_,$(CORNERS))
sdf_%:
	mkdir -p sim_build/sdf
	$(PYTHON_BIN) icarus_sdf.py sdf < $(call sdf_file,$*) > sim_build/sdf/$*.sdf
	$(MAKE) sim GATES=yes SDF=sim_build/sdf/$*.sdf COCOTB_RESULTS_FILE=results_sdf_$*.xml \
		COCOTB_TEST_MODULES=$(GATE_TEST_MODULES),test_replay
	$(PYTHON_BIN) -m cocotb_tools.check_results results_sdf_$*.xml
