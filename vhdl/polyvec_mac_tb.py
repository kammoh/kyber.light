############################################################################################################
##
# @description:  CocoTB testbench for polyvec_mac
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.6+, CocoTB 1.1.xnorme
# @copyright:    (c) 2019
##
############################################################################################################
import random
import logging
import math
import cocotb
from collections.abc import Iterable
from cocotb.clock import Clock
from cocotb.drivers import BusDriver, ValidatedBusDriver
from cocotb.monitors import BusMonitor
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, NextTimeStep, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.generators.bit import wave, intermittent_single_cycles, random_50_percent
from cmd_tester import CmdDoneTester


@cocotb.coroutine
def run_test(dut, subtract=True, valid_generator=None, ready_generator=None):

    tb = CmdDoneTester(dut, dut.clk, valid_generator=valid_generator, ready_generator=ready_generator)

    
    yield tb.reset()
    clkedge = RisingEdge(dut.clk)

    ###
    if tb.dut.DUMMY_NIST_ROUND == 1:
        import pyber
        from pyber import (Polynomial, PolynomialVector, KYBER_N, KYBER_Q)
    else:
        import pyber2 as pyber
        from pyber2 import (Polynomial, PolynomialVector, KYBER_N, KYBER_Q)
    ###

    dut.i_rama_blk <= 0

    tb.dut.i_recv_aa <= 0
    tb.dut.i_recv_bb <= 0
    tb.dut.i_recv_v <= 0
    tb.dut.i_do_mac <= 0
    tb.dut.i_send_v <= 0

    dut.i_subtract <= subtract

    yield clkedge

    a = PolynomialVector.random(tb.rnd)
    # a = PolynomialVector.zero()
    # a.polys[0].coeffs[0] = 1
    # a.polys[1].coeffs[0] = 1
    # a.polys[2].coeffs[0] = 1
    # a.polys[0].coeffs[1] = 1
    # a.polys[1].coeffs[1] = 1
    # a.polys[2].coeffs[1] = 1
    # print("a--------")
    # a.dump()
    b = PolynomialVector.random(tb.rnd)
    # b = PolynomialVector.zero()
    # b.polys[0].coeffs[0] = 1
    # b.polys[1].coeffs[0] = 1
    # b.polys[2].coeffs[0] = 1
    # b.polys[0].coeffs[1] = 1
    # b.polys[1].coeffs[1] = 1
    # b.polys[2].coeffs[1] = 1
    # print("\nb--------")
    # b.dump()
    # r = Polynomial.zero()
    v = Polynomial.random(tb.rnd)
    
    # print("r--------")
    # r.dump()

    if subtract:
        exp = v - (a * b)
    else:
        exp = v + (a * b)

    print("Expected Output: --------")
    exp.dump()

    tb.expect_output('dout', list(exp))

    
    
    tb.dut.i_recv_aa <= 1
    yield tb.drive_input('din', list(a))
    yield tb.wait_for_done()
    tb.dut.i_recv_aa <= 0
    yield clkedge
    
    tb.dut.i_recv_bb <= 1
    yield tb.drive_input('din', list(b))
    yield tb.wait_for_done()
    tb.dut.i_recv_bb <= 0
    yield clkedge

    tb.dut.i_recv_v <= 1
    yield tb.drive_input('din', list(v))
    yield tb.wait_for_done()
    tb.dut.i_recv_v <= 0
    yield clkedge

    tb.dut.i_do_mac <= 1
    yield clkedge
    yield tb.wait_for_done()
    tb.dut.i_do_mac <= 0
    yield clkedge

    tb.dut.i_send_v <= 1
    yield tb.wait_for_done()
    tb.dut.i_send_v <= 0
    yield clkedge

    for _ in range(3):
        yield clkedge

    raise tb.scoreboard.result

# Tests
factory = TestFactory(run_test)

# factory.add_option("valid_generator", [None, intermittent_single_cycles, random_50_percent])
# factory.add_option("ready_generator", [None, intermittent_single_cycles, random_50_percent])
# factory.add_option("subtract", [True, False])

factory.generate_tests()
