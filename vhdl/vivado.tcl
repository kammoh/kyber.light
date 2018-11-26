# STEP#0: define output directory area.
#
set VHDL_SRCS "$env(VHDL_SRCS)"
set TOP_MODULE $env(TOP_MODULE)

set timestamp [clock format [clock seconds] -format {%y-%m-%d-%H:%M:%S}]
set outputDir ./vivado-synth-${TOP_MODULE}-${timestamp}/
set REPORTS_DIR ${outputDir}/reports
set CHECKPOINTS_DIR ${outputDir}/checkpoints

set parts [get_parts]

puts $parts

set PART  xc7z020clg484-1

if { $argc != 2 } {
        puts "The script requires two numbers to be input."
} else {
        puts "[lindex $argv 0] [lindex $argv 1]"
}

file mkdir $outputDir
file mkdir $REPORTS_DIR
file mkdir $CHECKPOINTS_DIR
#------------------------------------------------------------------------
# reportCriticalPaths
#------------------------------------------------------------------------
# This function generates a CSV file that provides a summary of the first
# 50 violations for both Setup and Hold analysis. So a maximum number of 
# 100 paths are reported.
#------------------------------------------------------------------------
proc reportCriticalPaths { fileName } {
    # Open the specified output file in write mode
    set FH [open $fileName w]
    # Write the current date and CSV format to a file header
    puts $FH "#\n# File created on [clock format [clock seconds]]\n#\n"
    puts $FH "Startpoint,Endpoint,DelayType,Slack,#Levels,#LUTs"
    # Iterate through both Min and Max delay types
    foreach delayType {max min} {
        # Collect details from the 50 worst timing paths for the current analysis 
        # (max = setup/recovery, min = hold/removal) 
        # The $path variable contains a Timing Path object.
        foreach path [get_timing_paths -delay_type $delayType -max_paths 50 -nworst 1] {
            # Get the LUT cells of the timing paths
            set luts [get_cells -filter {REF_NAME =~ LUT*} -of_object $path]
            # Get the startpoint of the Timing Path object
            set startpoint [get_property STARTPOINT_PIN $path]
            # Get the endpoint of the Timing Path object
            set endpoint [get_property ENDPOINT_PIN $path]
            # Get the slack on the Timing Path object
            set slack [get_property SLACK $path]
            # Get the number of logic levels between startpoint and endpoint
            set levels [get_property LOGIC_LEVELS $path]
            # Save the collected path details to the CSV file
            puts $FH "$startpoint,$endpoint,$delayType,$slack,$levels,[llength $luts]"
        }
    }
    # Close the output file
    close $FH
    puts "CSV file $fileName has been created.\n"
    return 0
}; # End PROC




#
# STEP#1: setup design sources and constraints
#
#read_vhdl -library $TOP_MODULELib [ glob ./Sources/hdl/$TOP_MODULELib/*.vhdl ]         

read_vhdl -vhdl2008 "$VHDL_SRCS"
#read_verilog  [ glob ./Sources/hdl/*.v ]
#read_xdc ./Sources/part.xdc
#
# STEP#2: run synthesis, report utilization and timing estimates, write checkpoint design
#
synth_design -top $TOP_MODULE -part $PART -directive AreaOptimized_high -max_dsp 0  -flatten_hierarchy full
# -retiming  -assert  -resource_sharing on -max_dsp 0
# write_checkpoint -force $outputDir/post_synth
report_timing_summary -file $REPORTS_DIR/post_synth_timing_summary.rpt
report_utilization -file $REPORTS_DIR/post_synth_util.rpt
reportCriticalPaths $REPORTS_DIR/post_synth_critpath_report.csv
report_power -file $REPORTS_DIR/post_synth_power.rpt

write_schematic -format pdf $TOP_MODULE.pdf -orientation landscape

#
# STEP#3: run placement and logic optimzation, report utilization and timing estimates, write checkpoint design
#
# directive: Default, RuntimeOptimized, ExploreArea, Explore, etc
opt_design -directive ExploreArea

place_design
phys_opt_design -retime -hold_fix  -rewire
#write_checkpoint -force $CHECKPOINTS_DIR/post_place
report_timing_summary -file $REPORTS_DIR/post_place_timing_summary.rpt
#
# STEP#4: run router, report actual utilization and timing, write checkpoint design, run drc, write verilog and xdc out
#
route_design
#write_checkpoint -force $CHECKPOINTS_DIR/post_route
report_timing_summary -file $REPORTS_DIR/post_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $REPORTS_DIR/post_route_timing.rpt
report_clock_utilization -file $REPORTS_DIR/clock_util.rpt
report_utilization -file $REPORTS_DIR/post_route_util.rpt
report_power -file $REPORTS_DIR/post_route_power.rpt
report_drc -file $REPORTS_DIR/post_imp_drc.rpt
write_verilog -force $outputDir/${TOP_MODULE}_impl_netlist.v
write_xdc -no_fixed_only -force $outputDir/${TOP_MODULE}_impl.xdc
#
# STEP#5: generate a bitstream
# 
write_bitstream -force $outputDir/$TOP_MODULE.bit
