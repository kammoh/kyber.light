TOPLEVEL_LANG = vhdl
SIM=ghdl
PWD=$(shell pwd)


VHDL_SOURCES = $(PWD)/../flopoco.vhdl
TOPLEVEL = intconstmultoptternary_3329_12

MODULE=test_const_mult

include $(shell cocotb-config --makefiles)/Makefile.inc
include $(shell cocotb-config --makefiles)/Makefile.sim



yosys:
	yosys -m ghdl -p 'ghdl $(VHDL_SOURCES) -e $(TOPLEVEL); synth_xilinx; stat'


