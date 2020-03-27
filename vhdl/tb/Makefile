TOPLEVEL_LANG = vhdl
SIM=ghdl
# PWD=$(shell pwd)

# QHAT_BITS=13

# VHDL_SOURCES:=$(PWD)/../barrett_3329.vhdl $(PWD)/../IntConstMultOptTernary_10079_14.vhdl $(PWD)/../IntConstMultOptTernary_3329_$(QHAT_BITS).vhdl
# TOPLEVEL:=barrett_3329
# MODULE:=barrett_tb

WORKDIR=work

COMPILE_ARGS:=-fexplicit
SIM_ARGS:=--fst=$(TOPLEVEL).fst

export COCOTB_REDUCED_LOG_FMT:=1


include $(shell cocotb-config --makefiles)/Makefile.inc
include $(shell cocotb-config --makefiles)/Makefile.sim

default: gen_source sim

gen_source: ../generate_barrett.py
	cd ../ && ./generate_barrett.py


yosys:
	yosys -m ghdl -p 'ghdl -fexplicit $(VHDL_SOURCES) -e $(TOPLEVEL); synth_xilinx -top $(TOPLEVEL) -family xc7 -noiopad -flatten'
	# ; write_verilog $(TOPLEVEL).synth.v'



# show -format pdf -colors 1 -prefix $(TOPLEVEL).synth ; stat


# ghdl expects lower-case!
# ifeq ($(SIM), ghdl)
# TOPLEVEL = $(shell echo $(TOPLEVEL) | awk '{print tolower($0)}')
# endif




