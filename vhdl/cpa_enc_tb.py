############################################################################################################
##
# @description:  CocoTB testbench for sha3_noisegen
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.7+, CocoTB 1.1.xnor
# @copyright:    (c) 2019
##
############################################################################################################


# import random
# import logging
# import math
# from collections.abc import Iterable
# from collections import deque
import cocotb
from cocotb.utils import hexdump
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue, TestError, TestSuccess
from cocotb.drivers import BusDriver, ValidatedBusDriver
from cocotb.monitors import BusMonitor
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.log import SimLog
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cocotb.generators.byte import random_data, get_bytes
from cocotb.handle import ModifiableObject
from cmd_tester import CmdDoneTester
from pyber import KYBER_SYMBYTES, KYBER_N, getnoise_bytes
import itertools


def compare_lists(l1, l2):
    return [f"@{x[0]}: {hex(x[1])} != {hex(y)}" for x, y in itertools.zip_longest(enumerate(l1), l2) if x[1] != y]


@cocotb.coroutine
def func_test(dut, valid_gen=None, ready_gen=None):

    
    tb = CmdDoneTester(dut, dut.clk)

    yield tb.reset()

    dut.i_start <= 1

    yield tb.drive_input('coins', range(KYBER_SYMBYTES))
    yield tb.drive_input('pkmsg', range(2000))
    yield tb.drive_input('pkmsg', range(2000))

    exp = [1, 2, 3, 4, 5] 
    yield tb.expect_output('ct', exp )

    yield tb.wait_for_done()


    raise tb.scoreboard.result


# Tests
factory = TestFactory(func_test)

# factory.add_option( "valid_gen", [None, intermittent_single_cycles, random_50_percent])
factory.add_option("valid_gen", [None])
# factory.add_option("subtract", [False])

factory.generate_tests()
