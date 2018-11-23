
PWD := $(shell pwd)
WORK_DIR := $(PWD)/work

PKG_COMMON_SRCS := kyber_pkg.vhd

SYNTH_VHDL_SRCS := $(PKG_COMMON_SRCS) barret_reduce.vhd 
VHDL_SRCS := $(SYNTH_VHDL_SRCS) barret_reduce_tb.vhd

SIM_TOP := barret_reduce_tb
SYNTH_TOP := barret_reduce

GHDL_OPT := -O3
GHDL_WARNS := -Wbinding -Wreserved -Wlibrary -Wvital-generic -Wdelayed-checks -Wbody -Wspecs -Wunused

VHDL_STD := "08"


SIM_STOP_TUME := "6us"
SIM_STOP_OPT := #--stop-time=$(SIM_STOP_TUME) 

VCD_FILE := $(SIM_TOP).vcd
VCD_OPT := --vcd=$(VCD_FILE)

VHDL_OBJ := $(WORK_DIR)/$(SIM_TOP)/.$(SIM_TOP)_vhd

default: sim_run
	
$(WORK_DIR):
	@mkdir -p $@ 
	
elaborate_DONE := $(WORK_DIR)/.$(SIM_TOP).vhdl.elab
analyze_DONE := $(WORK_DIR)/.$(SIM_TOP).vhdl.anal


$(elaborate_DONE): elaborate
	@mkdir -p $(dir $@) && touch $@ 

$(analyze_DONE): analyze
	@mkdir -p $(dir $@) && touch $@ 

elaborate: $(WORK_DIR) $(analyze_DONE)
	ghdl -e $(GHDL_OPT) $(GHDL_WARNS) --std=$(VHDL_STD) --workdir=$(WORK_DIR) $(SIM_TOP)


analyze: $(WORK_DIR) $(VHDL_SRCS)
	ghdl -a $(GHDL_OPT) $(GHDL_WARNS) --std=$(VHDL_STD) --workdir=$(WORK_DIR) $(VHDL_SRCS)

		
sim_run: $(elaborate_DONE)
	ghdl -r $(SIM_TOP) $(VCD_OPT) $(SIM_STOP_OPT)

CLEAN_TARGETS := $(WORK_DIR)

SYNTH_TCL_SCRIPT := vivado.tcl

synth: $(SYNTH_VHDL_SRCS) $(XDC_FILES) $(SYNTH_TCL_SCRIPT) Makefile
	VHDL_SRCS="$(SYNTH_VHDL_SRCS)" TOP_MODULE=$(SYNTH_TOP) vivado -mode tcl -nojournal -source $(SYNTH_TCL_SCRIPT) -tclargs 3 4

clean:
	rm -rf $(CLEAN_TARGETS)

mrproper: clean
	rm -rf *.vcd

.PHONY: mrproper clean sim_pre_cmd sim_post_cmd simulation
