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
from cmd_tester import CmdDoneTester
from pyber import getnoise_bytes, KYBER_SYMBYTES, KYBER_N

@cocotb.coroutine
def func_test(dut, valid_gen=None, ready_gen=None):
    
    commands_dict = {'recv_msg': dut.i_recv_msg, 'send_hash': dut.i_send_hash}
    tb = CmdDoneTester(dut, dut.clk, input_name="din",
                       output_name="dout", num_out_words=KYBER_N, valid_gen=valid_gen, commands_dict=commands_dict)
    
    yield tb.reset()

    
    clkedge = RisingEdge(dut.clk)

    coins = [tb.rnd.randint(0,255) for _ in range(KYBER_SYMBYTES)]
    nonce = tb.rnd.randint(0, 255)
    exp = getnoise_bytes(coins, nonce)

    print(f"exp={exp}")

    tb.set_expected(exp)

    dut.i_nonce <= nonce
    yield tb.command('recv_msg', coins)
    yield tb.command('send_hash')

    for _ in range(3):
        yield clkedge

    raise tb.scoreboard.result



# Tests
factory = TestFactory(func_test)

factory.add_option(
    "valid_gen", [None, intermittent_single_cycles, random_50_percent])
# factory.add_option("valid_gen", [None])
# factory.add_option("subtract", [False])

factory.generate_tests()
