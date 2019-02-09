############################################################################################################
##
# @description:  CocoTB testbench for polyvec_mac
##
# @author:       Kamyar Mohajerani
##
# @requirements: Python 3.5+, CocoTB 1.1+
# @copyright:    (c) 2019
##
############################################################################################################
import random
import logging
import cocotb
from cocotb.clock import Clock
from cocotb.drivers import BusDriver, ValidatedBusDriver
from cocotb.monitors import BusMonitor
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ReadOnly, NextTimeStep, Event
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.generators.bit import (
    wave, intermittent_single_cycles, random_50_percent)
import math
from pyber import *
from collections import Iterable
from cmd_tester import CmdDoneTester

@cocotb.coroutine
def run_test(dut, valid_gen=None, ready_gen=None, subtract=True):
    clkedge = RisingEdge(dut.clk)
    tb = CmdDoneTester(dut, input_name="din",
                       output_name="dout", num_out_words=KYBER_N)

    yield tb.start()

    if subtract:
        dut.i_subtract <= 1
    else:
        dut.i_subtract <= 0
    dut.i_recv_a <= 0
    dut.i_recv_b <= 0
    dut.i_recv_r <= 0
    dut.i_do_mac <= 0
    dut.i_send_r <= 0

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
    r = Polynomial.random(tb.rnd)
    
    # print("r--------")
    # r.dump()

    if subtract:
        exp = r - (a * b)
    else:
        exp = r + (a * b)

    print("Expected Output: --------")
    exp.dump()

    tb.expected_output.clear()
    tb.expected_output.append(list(exp))

    yield tb.command(dut.i_recv_a, list(a))
    yield tb.command(dut.i_recv_b, list(b))
    yield tb.command(dut.i_recv_r, list(r))
    yield tb.command(dut.i_do_mac)
    yield tb.command(dut.i_send_r)

    for _ in range(3):
        yield clkedge

    raise tb.scoreboard.result




# Tests
factory = TestFactory(run_test)

factory.add_option("valid_gen", [None, intermittent_single_cycles, random_50_percent])
# factory.add_option("valid_gen", [None])
factory.add_option("subtract", [True, False])
# factory.add_option("subtract", [False])

factory.generate_tests()
