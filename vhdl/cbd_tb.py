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

import pyber

from pyber import Polynomial, KYBER_N, KYBER_ETA

@cocotb.coroutine
def func_test(dut, valid_gen=None, ready_gen=None):
    tb = ValidReadyTester(dut, dut.clk, input_name="din",
                          output_name="coeffout")
    log = dut._log 
    yield tb.reset()
    
    input = [tb.rnd.randint(0, 255) for _ in range(KYBER_ETA * KYBER_N // 4)]
    nibble_in = []
    for i in input:
        nibble_in.append(i % 16)
        nibble_in.append(i // 16)

    exp = Polynomial.cbd(input)
    exp.dump()
    
    # log.info(f'input = {input}   \n\t len = {len(input)}')


    tb.set_expected(list(exp))

    log.info('sending data...')
    yield tb.send_input(nibble_in)
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
