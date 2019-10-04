puts "RM-Info: Running script [info script]\n"

##########################################################################################
# Variables common to all reference methodology scripts
# Script: common_setup.tcl
# Version: O-2018.06-SP4 
# Copyright (C) 2007-2019 Synopsys, Inc. All rights reserved.
##########################################################################################

set MAX_CORES                     4

set DESIGN_NAME                   "{{top_module_name}}"  ;#  The name of the top-level design

set CLOCK_NET                     clk
set CLOCK_NAME                    ideal_clock
set CLOCK_PERIOD                  6.000

##########################################################################################
# Hierarchical Flow Design Variables
##########################################################################################

set HIERARCHICAL_DESIGNS           "" ;# List of hierarchical block design names "DesignA DesignB" ...
set HIERARCHICAL_CELLS             "" ;# List of hierarchical block cell instance names "u_DesignA u_DesignB" ...

##########################################################################################
# Library Setup Variables
##########################################################################################

# For the following variables, use a blank space to separate multiple entries.
# Example: set TARGET_LIBRARY_FILES "lib1.db lib2.db lib3.db"

set RTK_PATH                      "/src/SAED32nm/rvt_tt_1p05v_25c" ;

set ADDITIONAL_SEARCH_PATH        "${RTK_PATH}"  ;#  Additional search path to be added to the default search path

set TARGET_LIBRARY_FILES          "${RTK_PATH}/saed32rvt_tt1p05v25c.db"  ;#  Target technology logical libraries
# set ADDITIONAL_LINK_LIB_FILES     "[glob ${RTK_PATH}/SRAM*.db]"  ;#  Extra link logical libraries not included in TARGET_LIBRARY_FILES
set ADDITIONAL_LINK_LIB_FILES     "${RTK_PATH}/saed32sram_tt1p05v25c.db"  ;#  Extra link logical libraries not included in TARGET_LIBRARY_FILES

set MIN_LIBRARY_FILES             ""  ;#  List of max min library pairs "max1 min1 max2 min2 max3 min3"...

set MW_REFERENCE_LIB_DIRS         "${RTK_PATH}/saed32nm_rvt_1p9m.mwlib ${RTK_PATH}/saed32sram.mwlib "  ;#  Milkyway reference libraries (include IC Compiler ILMs here)

set MW_REFERENCE_CONTROL_FILE     ""  ;#  Reference Control file to define the Milkyway reference libs

set TECH_FILE                     "${RTK_PATH}/saed32nm_1p9m_mw.tf"  ;#  Milkyway technology file
set MAP_FILE                      "${RTK_PATH}/saed32nm_tf_itf_tluplus.map"  ;#  Mapping file for TLUplus
set TLUPLUS_MAX_FILE              "${RTK_PATH}/saed32nm_1p9m_Cmax.tluplus"  ;#  Max TLUplus file
set TLUPLUS_MIN_FILE              "${RTK_PATH}/saed32nm_1p9m_Cmin.tluplus"  ;#  Min TLUplus file

set MIN_ROUTING_LAYER            ""   ;# Min routing layer
set MAX_ROUTING_LAYER            ""   ;# Max routing layer

set LIBRARY_DONT_USE_FILE        ""   ;# Tcl file with library modifications for dont_use
set LIBRARY_DONT_USE_PRE_COMPILE_LIST ""; #Tcl file for customized don't use list before first compile
set LIBRARY_DONT_USE_PRE_INCR_COMPILE_LIST "";# Tcl file with library modifications for dont_use before incr compile



# This constraint sets the input drive strength of the input pins of
# your design. We specifiy a specific standard cell which models what
# would be driving the inputs. This should usually be a small inverter
# which is reasonable if another block of on-chip logic is driving
# your inputs.
set ADK_DRIVING_CELL                "INVX1"

# This constraint sets the load capacitance in picofarads of the
# output pins of your design.
set ADK_TYPICAL_ON_CHIP_LOAD        0.005 


set dc_post_synthesis_plugin "./scripts/dc/post_synthesis.tcl"

##########################################################################################
# Multivoltage Common Variables
#
# Define the following multivoltage common variables for the reference methodology scripts 
# for multivoltage flows. 
# Use as few or as many of the following definitions as needed by your design.
##########################################################################################

set PD1                          ""           ;# Name of power domain/voltage area  1
set VA1_COORDINATES              {}           ;# Coordinates for voltage area 1
set MW_POWER_NET1                "VDD1"       ;# Power net for voltage area 1

set PD2                          ""           ;# Name of power domain/voltage area  2
set VA2_COORDINATES              {}           ;# Coordinates for voltage area 2
set MW_POWER_NET2                "VDD2"       ;# Power net for voltage area 2

set PD3                          ""           ;# Name of power domain/voltage area  3
set VA3_COORDINATES              {}           ;# Coordinates for voltage area 3
set MW_POWER_NET3                "VDD3"       ;# Power net for voltage area 3

set PD4                          ""           ;# Name of power domain/voltage area  4
set VA4_COORDINATES              {}           ;# Coordinates for voltage area 4
set MW_POWER_NET4                "VDD4"       ;# Power net for voltage area 4

puts "RM-Info: Completed script [info script]\n"

