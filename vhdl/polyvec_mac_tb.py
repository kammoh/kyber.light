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
import pyber
from pyber import Polynomial, PolynomialVector, KYBER_N

@cocotb.coroutine
def run_test(dut, valid_gen=None, ready_gen=None, subtract=True):

    commands_dict = {'recv_aa': dut.i_recv_aa, 'recv_bb': dut.i_recv_bb,
                     'recv_v': dut.i_recv_v, 'do_mac': dut.i_do_mac, 'send_v': dut.i_send_v}
    tb = CmdDoneTester(dut, dut.clk, input_name="din",
                       output_name="dout", num_out_words=KYBER_N, valid_gen=valid_gen, commands_dict=commands_dict)
    
    yield tb.reset()
    clkedge = RisingEdge(dut.clk)

    if subtract:
        dut.i_subtract <= 1
    else:
        dut.i_subtract <= 0

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

    tb.set_expected(list(exp))

    dut.i_rama_blk <= 0
    yield tb.command('recv_aa', list(a))
    yield tb.command('recv_bb', list(b))
    yield tb.command('recv_v', list(v))
    yield tb.command('do_mac')
    yield tb.command('send_v')

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
