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
COCOTB_TEST_MODULES = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

# The kit has no SRAM macro, so the program memory is the flop variant, which yosys
# maps to block RAM.
fpga_netlist.v: $(SRC_DIR)/project.v $(SRC_DIR)/../bin/generate.ml
	cd .. && dune exec -- bin/generate.exe top > test/fpga_top.v
	yosys -q -p "read_verilog $(SRC_DIR)/project.v fpga_top.v; synth_ice40 -top tt_um_marcosash_protocol_emulator; write_verilog -noattr fpga_netlist.v"
