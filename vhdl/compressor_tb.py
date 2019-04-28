############################################################################################################
##
# @description:  CocoTB testbench for compressor
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.7+, CocoTB 1.1+
# @copyright:    (c) 2019 Kamyar Mohajerani
##
############################################################################################################


import cocotb
from cocotb.utils import hexdump
from cocotb.clock import Clock
from cocotb.binary import BinaryValue
from cocotb.result import ReturnValue, TestError, TestSuccess
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, Event
from cocotb.regression import TestFactory

from cmd_tester import ValidReadyTester

round2 = True

if round2:
    import pyber2 as pyber
    from pyber2 import KYBER_K, KYBER_N, KYBER_POLYCOMPRESSEDBYTES, KYBER_POLYVECCOMPRESSEDBYTES, poly_tomsg, Polynomial
else:
    import pyber
    from pyber import KYBER_K, KYBER_N, KYBER_POLYCOMPRESSEDBYTES, KYBER_POLYVECCOMPRESSEDBYTES, poly_tomsg, Polynomial


@cocotb.coroutine
def func_test(dut, debug=True, is_polyvec=False, is_msg=True, valid_generator=None, ready_generator=None):

    tb = ValidReadyTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)
    yield tb.reset()
    
    clkedge = RisingEdge(dut.clk)

    dut.i_is_polyvec <= is_polyvec
    dut.i_is_msg <= is_msg
    
    if debug:
        poly_bytes = [i & 0xff for i in range(KYBER_POLYCOMPRESSEDBYTES)]
        polyvec_bytes = [i & 0xff for i in range(KYBER_POLYVECCOMPRESSEDBYTES)]
    else:
        poly_bytes = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_POLYCOMPRESSEDBYTES)]
        polyvec_bytes = [tb.rnd.randint(0, 0xff) for _ in range(KYBER_POLYVECCOMPRESSEDBYTES)]
        
    
    if is_polyvec:
        pass
    else:
        poly = Polynomial.random(tb.rnd)
        exp = poly_tomsg(poly)
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

# # # Test configs
# factory.add_option("valid_generator", [intermittent_single_cycles, random_50_percent])
# factory.add_option("ready_generator", [intermittent_single_cycles, random_50_percent])
# factory.add_option("is_polyvec", [True, False])
# factory.add_option("debug", [False])

factory.generate_tests()
