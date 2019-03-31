#=========================================================================
# Design Constraints File
#=========================================================================

# This constraint sets the target clock period for the chip in
# nanoseconds. Note that the first parameter is the name of the clock
# signal in your verlog design. If you called it something different than
# clk you will need to change this. You should set this constraint
# carefully. If the period is unrealistically small then the tools will
# spend forever trying to meet timing and ultimately fail. If the period
# is too large the tools will have no trouble but you will get a very
# conservative implementation.



create_clock -name ${CLOCK_NAME} \
             -period ${CLOCK_PERIOD} \
             [get_ports ${CLOCK_NET}]

# This constraint sets the load capacitance in picofarads of the
# output pins of your design.

set_load -pin_load $ADK_TYPICAL_ON_CHIP_LOAD [all_outputs]

# This constraint sets the input drive strength of the input pins of
# your design. We specifiy a specific standard cell which models what
# would be driving the inputs. This should usually be a small inverter
# which is reasonable if another block of on-chip logic is driving
# your inputs.


# set_input_delay constraints for input ports

set_input_delay -clock ${CLOCK_NAME} 0 [all_inputs]

# set_output_delay constraints for output ports

set_output_delay -clock ${CLOCK_NAME} 0 [all_outputs]

#Make all signals limit their fanout

set_max_fanout 20 ${DESIGN_NAME}

# Make all signals meet good slew

set_max_transition [expr 0.25*${CLOCK_PERIOD}] ${DESIGN_NAME}

#set_input_transition 1 [all_inputs]
#set_max_transition 10 [all_outputs]

