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
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.log import SimLog
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cocotb.generators.byte import random_data, get_bytes
from cocotb.handle import ModifiableObject
from cmd_tester import ValidReadyTester
from pyber import KYBER_N, KYBER_K, KYBER_POLYCOMPRESSEDBYTES, KYBER_POLYVECCOMPRESSEDBYTES, poly_decompress, polyvec_decompress


@cocotb.coroutine
def func_test(dut, debug=True, is_polyvec=True, valid_generator=None, ready_generator=None):

    tb = ValidReadyTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)
    yield tb.reset()
    
    clkedge = RisingEdge(dut.clk)

    dut.i_is_polyvec <= is_polyvec
    
    if debug:
        poly_bytes = [i & 0xff for i in range(KYBER_POLYCOMPRESSEDBYTES)]
        polyvec_bytes = [i & 0xff for i in range(KYBER_POLYVECCOMPRESSEDBYTES)]
    else:
        poly_bytes = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_POLYCOMPRESSEDBYTES)]
        polyvec_bytes = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_POLYVECCOMPRESSEDBYTES)]
        
    
    if is_polyvec:
        polyvec = polyvec_decompress(polyvec_bytes)
        exp = list(polyvec)
        if debug:
            polyvec.dump()
    else:
        poly = poly_decompress(poly_bytes)
        exp = list(poly)
        if debug:
            poly.dump()

    # This should come first!
    tb.expect_output('coefout', exp)

    yield clkedge  # optional
    
    if is_polyvec:
        tb.log.info("sending polyvec")
        yield tb.drive_input('bytein', polyvec_bytes)
    else:
        tb.log.info("sending poly")
        yield tb.drive_input('bytein', poly_bytes)

    for _ in range(KYBER_K * KYBER_N + 10 if is_polyvec else KYBER_N + 10):
        yield clkedge  # optional

    raise tb.scoreboard.result


# # Tests
factory = TestFactory(func_test)

# # Test configs
factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])
factory.add_option("is_polyvec", [True, False])
factory.add_option("debug", [False])

factory.generate_tests()
