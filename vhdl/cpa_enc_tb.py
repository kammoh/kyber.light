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
from pyber import KYBER_SYMBYTES, KYBER_INDCPA_MSGBYTES, atpk_bytes, compressed_pk_bytes
import pyber
import itertools


def compare_lists(l1, l2):
    return [f"@{x[0]}: {hex(x[1])} != {hex(y)}" for x, y in itertools.zip_longest(enumerate(l1), l2) if x[1] != y]


@cocotb.coroutine
def func_test(dut, valid_generator=None, ready_generator=None):

    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)
    clkedge = RisingEdge(dut.clk)

    dut.i_start_dec <= 0
    dut.i_start_enc <= 0
    dut.i_recv_pk <= 0

    coins = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_SYMBYTES)]  # [i & 0xff for i in range(KYBER_SYMBYTES)]
    pk = [tb.rnd.randint(0, 0xff) for i in range(compressed_pk_bytes())]
    atpk = list(atpk_bytes(pk))
    msg = [tb.rnd.randint(0, 0xff) for i in range(KYBER_INDCPA_MSGBYTES)]
    exp = list(pyber.indcpa_enc_nontt(msg, atpk, coins))
    # exp_str = [hex(e)[2:].zfill(2) for e in exp]

    # This should come first!
    tb.expect_output('ct', exp)

    tb.log.info("sending PK + AT")
    dut.i_recv_pk <= 1
    yield tb.drive_input('pk', atpk)

    yield tb.wait_for_done()
    yield clkedge  # optional
    dut.i_recv_pk <= 0
    yield clkedge  # optional

    tb.log.info("sending coins")
    dut.i_start_enc <= 1
    yield tb.drive_input('coins', coins)

    tb.log.info("sending message")
    yield tb.drive_input('pt', msg)

    tb.log.info("waiting for done")
    yield tb.wait_for_done()

    dut.i_start_enc <= 0

    yield clkedge  # optional
    yield clkedge  # optional

    raise tb.scoreboard.result


# Tests
factory = TestFactory(func_test)

# Test configs
factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])

factory.generate_tests()
