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
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DSIM
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_io/verilog/sg13cmos5l_io.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_udp.v
VERILOG_SOURCES += $(PDK_ROOT)/ihp-sg13cmos5l/libs.ref/sg13cmos5l_stdcell/verilog/sg13cmos5l_stdcell.v
VERILOG_SOURCES += models/RM_IHPSG13_1P_core_behavioral_bm_bist.v models/RM_IHPSG13_1P_512x16_c2_bm_bist.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(CURDIR)/gate_level_netlist.v

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
# the bench demos' rehearsals simulate milliseconds, so on the RTL alone
ifeq ($(FPGA)$(GATES)$(ICEPI),)
COCOTB_TEST_MODULES := $(COCOTB_TEST_MODULES),test_demo,test_swd
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

# Replays the pin traces in traces/, recorded from the OCaml simulation of the top, on
# whichever netlist the mode selects: make replay, make replay GATES=yes, FPGA=yes or
# ICEPI=yes.
replay:
	$(MAKE) sim COCOTB_TEST_MODULES=test_replay COCOTB_RESULTS_FILE=results_replay.xml
	$(PYTHON_BIN) -m cocotb_tools.check_results results_replay.xml
