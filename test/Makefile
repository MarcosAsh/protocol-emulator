# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults
SIM ?= icarus
FST ?= -fst # Use more efficient FST format
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.v protocol_emulator.v

ifeq ($(FPGA),yes)

# The netlist yosys synthesises for the FPGA kit's iCE40, from `make fpga_netlist.v`:
SIM_BUILD				= sim_build/fpga
VERILOG_SOURCES += $(shell yosys-config --datdir)/ice40/cells_sim.v
VERILOG_SOURCES += $(PWD)/fpga_netlist.v

else ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
COMPILE_ARGS    += -DFUNCTIONAL
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES)) models/RM_IHPSG13_1P_core_behavioral_bm_bist.v models/RM_IHPSG13_1P_512x16_c2_bm_bist.v

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_io/verilog/sg13cmos5l_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_udp.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_stdcell.v
VERILOG_SOURCES += models/RM_IHPSG13_1P_core_behavioral_bm_bist.v models/RM_IHPSG13_1P_512x16_c2_bm_bist.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Allow sharing configuration between design and testbench via `include`:
COMPILE_ARGS 		+= -I$(SRC_DIR)

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

# List test modules to run, separated by commas and without the .py suffix:
COCOTB_TEST_MODULES = test,test_usb_board

# The firmware words are committed, because the workflows that simulate have no OCaml.
# Where there is a dune they are reassembled first, so an encoding change reaches them.
FIRMWARE = $(patsubst %.asm,%.hex,$(wildcard *.asm))
ifneq ($(shell command -v dune),)
CUSTOM_SIM_DEPS += $(FIRMWARE)
endif

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

firmware: $(FIRMWARE)
%.hex: %.asm FORCE
	cd .. && dune exec -- bin/generate.exe assemble test/$< > test/$@
FORCE:
.PHONY: firmware

# The kit has no SRAM macro, so the program memory is the flop variant, which yosys
# maps to block RAM.
fpga_netlist.v: $(SRC_DIR)/project.v $(SRC_DIR)/../bin/generate.ml
	cd .. && dune exec -- bin/generate.exe top > test/fpga_top.v
	yosys -q -p "read_verilog $(SRC_DIR)/project.v fpga_top.v; synth_ice40 -top tt_um_marcosash_protocol_emulator; write_verilog -noattr fpga_netlist.v"

# The kit's own top and pin file through place and route: the design has to fit the
# iCE40 UP5K and hold the clock the kit demos run at.
FPGA_MHZ ?= 16
fpga_fit: fpga_netlist.v
	sed "s/__tt_um_placeholder/tt_um_marcosash_protocol_emulator/" ../tt/fpga/tt_fpga_top.v > fpga_kit_top.v
	yosys -q -p "read_verilog -sv fpga_kit_top.v $(SRC_DIR)/project.v fpga_top.v; synth_ice40 -top tt_fpga_top -json fpga_kit.json"
	nextpnr-ice40 --up5k --package sg48 --json fpga_kit.json --pcf ../tt/fpga/tt_fpga_top.pcf --pcf-allow-unconstrained --freq $(FPGA_MHZ) --seed 1 -q --log fpga_kit.log
	grep -h "ICESTORM_LC:\|Max frequency" fpga_kit.log | tail -3

# Replays the pin traces in traces/, recorded from the OCaml simulation of the top, on
# whichever netlist the mode selects: make replay, make replay GATES=yes or FPGA=yes.
replay:
	$(MAKE) sim COCOTB_TEST_MODULES=test_replay COCOTB_RESULTS_FILE=results_replay.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_replay.xml
