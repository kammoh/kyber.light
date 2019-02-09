set REPORTS_DIR {{output_dir}}/reports
set CHECKPOINTS_DIR {{output_dir}}/checkpoints

set parts [get_parts]

puts "available devices: $parts"

if {[lsearch -exact $parts {{part}}] < 0} {
    puts "ERROR: device {{part}} is not supported"
    quit
}

puts "using {{part}}"


# if { $argc != 2 } {
#         puts "The script requires two numbers to be input."
# } else {
#         puts "[lindex $argv 0] [lindex $argv 1]"
# }

file mkdir {{output_dir}}
file mkdir $REPORTS_DIR
file mkdir $CHECKPOINTS_DIR


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


{% for source in hdl_sources %}
    {% if source.language == 'vhdl.2008' %}
read_vhdl -vhdl2008 {{source.path}} -library {{source.lib}}
    {% elif source.language == 'vhdl' %}
read_vhdl {{source.path}} -library {{source.lib}}
    {% elif source.language == 'verilog' %}
read_verilog {{source.path}} -library {{source.lib}}
    {% endif%}
{% endfor %}

{% for xdc in xdcs %}
read_xdc {{xdc.path}}
{% endfor %}

synth_design {{synth_options}}

# directive: Default, RuntimeOptimized, ExploreArea, Explore, etc
# OR # -merge_equivalent_drivers -control_set_merge -resynth_area -remap  -propconst 
opt_design {{opt_options}}

write_checkpoint -force {{output_dir}}/post_synth

report_timing_summary -file $REPORTS_DIR/post_synth_timing_summary.rpt 
report_utilization -file $REPORTS_DIR/post_synth_util.rpt
reportCriticalPaths $REPORTS_DIR/post_synth_critpath_report.csv
report_methodology  -file $REPORTS_DIR/post_synth_methodology.rpt
# report_power -file $REPORTS_DIR/post_synth_power.rpt


place_design
phys_opt_design -retime -hold_fix  -rewire
#write_checkpoint -force $CHECKPOINTS_DIR/post_place
report_timing_summary -file $REPORTS_DIR/post_place_timing_summary.rpt

route_design
#write_checkpoint -force $CHECKPOINTS_DIR/post_route
report_timing_summary -file $REPORTS_DIR/post_route_timing_summary.rpt
report_timing  -sort_by group -max_paths 100 -path_type summary -file $REPORTS_DIR/post_route_timing.rpt
report_clock_utilization -file $REPORTS_DIR/clock_util.rpt
report_utilization -file $REPORTS_DIR/post_route_util.rpt
report_utilization -hierarchical  -file   $REPORTS_DIR/post_route_util_hierarchical.rpt
# report_power -file $REPORTS_DIR/post_route_power.rpt
# report_drc -file $REPORTS_DIR/post_route_drc.rpt
# report_methodology  -file $REPORTS_DIR/post_route_methodology.rpt

# write_verilog -force {{output_dir}}/{{top_module_name}}_impl_netlist.v
# write_vhdl -force {{output_dir}}/{{top_module_name}}_impl_netlist.vhdl
# write_xdc -no_fixed_only -force {{output_dir}}/{{top_module_name}}_impl.xdc

# write_bitstream -force {{output_dir}}/{{top_module_name}}.bit

puts "\n\n** Vivado run completed **\n"
puts "** Number of Critical Warnings: [get_msg_config -severity {CRITICAL WARNING} -count]"
puts "** Number of Warnings: [get_msg_config -severity {WARNING} -count]\n\n"

quit
