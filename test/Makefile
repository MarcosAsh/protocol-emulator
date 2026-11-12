# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(CURDIR)/../src
PROJECT_SOURCES = project.v protocol_emulator.v

ifeq ($(ICEPI),yes)

# The Icepi Zero's top synthesised for its ECP5 (`make icepi_netlist.v`) on yosys' cell
# models. Yosys' block RAM model is empty, so models/ has our own, plus a PLL that passes
# the testbench clock through:
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
# Verilator is roughly 15x faster than icarus, which the rehearsals of the bench's real
# milliseconds need: make SIM=verilator COCOTB_TEST_MODULES=test_demo
ifeq ($(SIM),verilator)
SIM_BUILD				= sim_build/verilator
COMPILE_ARGS    += --no-timing -Wno-fatal -Wno-lint -Wno-style
endif

else

# Gate level simulation:
export GATES
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
# With SDF= set to a corner's SDF (via icarus_sdf.py), the cells and macros keep their
# specify blocks and take its delays. The netlist needs the same macro renaming:
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
COCOTB_TEST_MODULES := $(COCOTB_TEST_MODULES),test_two_engines,test_board_blame,test_ethernet_rx
GATE_TEST_MODULES := $(COCOTB_TEST_MODULES)
# on the Icepi's netlist they come near a runner's six hours, so CI runs them as
# HALF=slow and HALF=rest
comma := ,
SLOW_TEST_MODULES = test_two_engines,test_board_blame
ifeq ($(HALF),slow)
COCOTB_TEST_MODULES := $(SLOW_TEST_MODULES)
else ifeq ($(HALF),rest)
COCOTB_TEST_MODULES := $(subst $(comma)$(SLOW_TEST_MODULES),,$(COCOTB_TEST_MODULES))
endif
# the bench demo rehearsals simulate milliseconds, so they only run on the RTL
ifeq ($(GATES)$(ICEPI),)
COCOTB_TEST_MODULES := $(COCOTB_TEST_MODULES),test_demo,test_swd,test_demo_board,test_pyocd,test_usb_fs
endif

# With dune available, reassemble the firmware first so an encoding change reaches the
# words. The default goal stays cocotb's even though firmware.mk brings the first rule.
.DEFAULT_GOAL := all
include firmware.mk
ifneq ($(shell command -v dune),)
CUSTOM_SIM_DEPS += $(FIRMWARE) $(CERTIFICATES) $(ROWS)
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# The Icepi Zero's netlist, synthesised by its own flow in ../icepi.
icepi_netlist.v: $(SRC_DIR)/project.v $(SRC_DIR)/protocol_emulator.v ../icepi/icepi_top.v
	$(MAKE) -C ../icepi build/usb1.json
	yosys -q -p "read_json ../icepi/build/usb1.json; write_verilog -noattr icepi_netlist.v"

# The outside-chip demos (docs/hardware.md) on the RTL, against picosoc's SPI flash model,
# cocotbext-i2c's memory and cocotbext-spi's loopback slave, checked with sigrok decoders.
# Needs cocotbext-i2c 0.1.2, cocotbext-spi 0.5.0, cocotb-bus 0.3.0 and sigrok-cli.
outside:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_outside \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_outside.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_outside.xml

# demo_both_roles.py and demo_rates.py on the RTL, run as on the bench. Needs outside's.
both_roles:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_both_roles_bench \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_both_roles.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_both_roles.xml

# demo_tolerance.py on the RTL, shortened to simulate. Needs outside's.
tolerance_bench:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_tolerance_bench \
		PLUSARGS=+firmware=/dev/null \
		COCOTB_RESULTS_FILE=results_tolerance_bench.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_tolerance_bench.xml

# demo_margins.py on the RTL against models with their own thresholds, judged the way
# demo/margins.py judges the bench. MARGINS=margins.json comes from
# test/python/write_margins.exe.
# Needs outside's.
margins_bench:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_margins_bench \
		PLUSARGS=+firmware=/dev/null MARGINS=$(abspath $(MARGINS)) \
		COCOTB_RESULTS_FILE=results_margins_bench.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_margins_bench.xml

# Runs a remote lab job's firmware.json on the RTL like Pico A does, as the rtl backend of
# demo/lab.py: make lab LAB_FIRMWARE=DIR/firmware.json LAB_OUT=DIR. Needs outside's. The
# firmware is not reassembled, so dune doesn't run.
.PHONY: lab
lab:
	$(MAKE) sim OUTSIDE=yes SIM_BUILD=sim_build/outside COCOTB_TEST_MODULES=test_lab_rtl \
		PLUSARGS=+firmware=/dev/null CUSTOM_SIM_DEPS= \
		COCOTB_RESULTS_FILE=results_lab.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_lab.xml

# icepi/carrier_check.v (the bench carrier's self-test bitstream) with its own pulls and
# models/ecp5_pads.v: make carrier_check
carrier_check:
	$(MAKE) sim TOPLEVEL=tb_carrier_check SIM_BUILD=sim_build/carrier_check CUSTOM_SIM_DEPS= \
		VERILOG_SOURCES="$(CURDIR)/tb_carrier_check.v $(CURDIR)/../icepi/carrier_check.v \
		$(CURDIR)/models/ecp5_pads.v" \
		COCOTB_TEST_MODULES=test_carrier_bitstream COCOTB_RESULTS_FILE=results_carrier_check.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_carrier_check.xml

# Replays the pin traces in traces/ (recorded from the OCaml simulation of the top) on the
# netlist the mode selects: make replay, make replay GATES=yes, FPGA=yes or ICEPI=yes.
replay:
	$(MAKE) sim COCOTB_TEST_MODULES=test_replay COCOTB_RESULTS_FILE=results_replay.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_replay.xml

# Gate-level tests and replays with the router's delays at one corner (sdf_slow, sdf_typ,
# sdf_fast) or all three (sdf), using the flow's SDF in SDF_DIR at the chip's 50 MHz. Each
# is one run because annotating takes minutes. Icarus has no timing checks, so a violation
# only shows up as a wrong value. GROUP picks a subset of the tests by module and name:
# CI runs each corner in sixteen jobs, runners vary 2x in speed and a job gets five hours,
# so no group should take much more than two on a fast runner.
SDF_DIR ?= ../runs/wokwi/final/sdf
GROUP ?= all
space := $(subst ,, )
SDF_MODULES_all = $(GATE_TEST_MODULES),test_replay
# the replays sorted by their slow-corner time (dmx512 alone takes over two hours).
# replay_rest takes every trace the others don't name, so a new one always runs somewhere.
# cocotb puts the filter unquoted in its shell line, so it's quoted here and ends on \Z
# rather than $
SDF_REPLAYS_dmx512 = dmx512
SDF_REPLAYS_wiegand = wiegand|ir_nec
SDF_REPLAYS_bridge = bridge|usb_power_delivery|snorble
SDF_REPLAYS_c = caliper|dali|fifo_poll|frumbleglide|i2c_logger|lfast|lin
SDF_REPLAYS_m = microwire|plinkoo|spdif|spi_master|swd_blind
SDF_REPLAYS_named = $(foreach g,dmx512 wiegand bridge c m,$(SDF_REPLAYS_$(g)))
SDF_MODULES_replay_dmx512 = test_replay
SDF_FILTER_replay_dmx512 = [.]replay_($(SDF_REPLAYS_dmx512))\Z
SDF_MODULES_replay_wiegand = test_replay
SDF_FILTER_replay_wiegand = [.]replay_($(SDF_REPLAYS_wiegand))\Z
SDF_MODULES_replay_bridge = test_replay
SDF_FILTER_replay_bridge = [.]replay_($(SDF_REPLAYS_bridge))\Z
SDF_MODULES_replay_c = test_replay
SDF_FILTER_replay_c = [.]replay_($(SDF_REPLAYS_c))\Z
SDF_MODULES_replay_m = test_replay
SDF_FILTER_replay_m = [.]replay_($(SDF_REPLAYS_m))\Z
SDF_MODULES_replay_rest = test_replay
SDF_FILTER_replay_rest = [.]replay_(?!($(subst $(space),|,$(SDF_REPLAYS_named)))\Z)
SDF_MODULES_two_engines_fault = test_two_engines
SDF_FILTER_two_engines_fault = [.]test_a_faulted_
SDF_MODULES_two_engines_one = test_two_engines
SDF_FILTER_two_engines_one = [.]test_one_
SDF_MODULES_two_engines_uart = test_two_engines
SDF_FILTER_two_engines_uart = [.]test_uart_
SDF_MODULES_two_engines_chip = test_two_engines
SDF_FILTER_two_engines_chip = [.]test_the_chip_
SDF_MODULES_blame_a = test_board_blame
SDF_FILTER_blame_a = [.]test_[a-s]
SDF_MODULES_blame_b = test_board_blame
SDF_FILTER_blame_b = [.]test_[t-z]
SDF_MODULES_core_a = test
SDF_FILTER_core_a = [.]test_[a-i]
SDF_MODULES_core_b = test
SDF_FILTER_core_b = [.]test_[j-z]
SDF_MODULES_boards = $(subst $(space),$(comma),$(filter-out test test_two_engines test_board_blame test_usb_board,$(subst $(comma),$(space),$(GATE_TEST_MODULES))))
SDF_MODULES_boards_usb = test_usb_board
SDF_RESULTS = results_sdf_$(1)$(if $(filter-out all,$(GROUP)),_$(GROUP)).xml
CORNERS = slow typ fast
sdf_file = $(or $(wildcard $(SDF_DIR)/nom_$(1)_*/*.sdf),$(error no $(1) SDF in $(SDF_DIR)))
$(CURDIR)/sim_build/sdf/gate_level_netlist.v: gate_level_netlist.v icarus_sdf.py
	mkdir -p $(@D)
	$(PYTHON_BIN) icarus_sdf.py netlist < $< > $@
sdf: $(addprefix sdf_,$(CORNERS))
sdf_%:
	mkdir -p sim_build/sdf
	$(PYTHON_BIN) icarus_sdf.py sdf < $(call sdf_file,$*) > sim_build/sdf/$*.sdf
	COCOTB_TEST_FILTER="'$(SDF_FILTER_$(GROUP))'" $(MAKE) sim GATES=yes SDF=sim_build/sdf/$*.sdf \
		COCOTB_RESULTS_FILE=$(call SDF_RESULTS,$*) COCOTB_TEST_MODULES=$(SDF_MODULES_$(GROUP))
	$(PYTHON_BIN) -m cocotb_tools.check_results $(call SDF_RESULTS,$*)
