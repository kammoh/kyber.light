############################################################################################################
##
# @description:  CocoTB testbench for asymmetric_fifo
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.7+, CocoTB 1.1.xnor
# @copyright:    (c) 2019
##
############################################################################################################
import random
import logging
import math
from collections.abc import Iterable
from collections import deque
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
from cmd_tester import ValidReadyTester

import gmpy2

def gcd(a,b):
    return int(gmpy2.gcd(a,b))

@cocotb.coroutine
def func_test(dut, valid_gen=None, ready_gen=None):
    tb = ValidReadyTester(dut, dut.clk)
    log = dut._log 
    yield tb.reset()

    in_width = int(dut.G_IN_WIDTH)
    out_width = int(dut.G_OUT_WIDTH)

    num_expected_outputs = tb.rnd.randint(1, 400) * in_width // gcd(in_width, out_width)
    
    clkedge = RisingEdge(dut.clk)


    input = ''.join([str(tb.rnd.randint(0, 1))
                     for _ in range(out_width * num_expected_outputs)])

    pad_bits = math.ceil(out_width * num_expected_outputs / in_width) * in_width - len(input)

    exp = [int(input[max(0, len(input) - (x+1)*out_width): len(input) - x * out_width], base=2)
           for x in range(math.ceil(len(input)/out_width))]
    # pad afterwards:
    input = pad_bits * "0" + input

    # log.info(f'input = {input}   \n\t len = {len(input)}')
    # log.info(
    #     f'expected = {[hex(x) for x in exp ]}  \n\t len = {len(exp)} binary={[bin(x) for x in exp ]}')
    

    tb.set_expected(exp)

    yield clkedge

    log.info('sending data...')
    yield tb.send_input(input)
    log.info('send complete')

    log.info('waiting for transaction to complete')
    yield tb.wait_transaction()

    raise tb.scoreboard.result


# Tests
factory = TestFactory(func_test)

factory.add_option(
    "valid_gen", [None, intermittent_single_cycles, random_50_percent])
# factory.add_option("valid_gen", [None])
# factory.add_option("subtract", [False])

factory.generate_tests()
