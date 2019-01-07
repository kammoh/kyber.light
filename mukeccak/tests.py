import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, Join, NextTimeStep
from cocotb.binary import BinaryValue
from cocotb.result import TestFailure, TestError, TestSuccess, ReturnValue
from cocotb.log import SimLog
from cocotb.wavedrom import Wavedrom

import random


import tiny_keccak

## yield:
# a = yield Trigger <-- yield returns a value!
# can yield a list of triggers! == join_any, returns the trigger that fired first!

def discover(obj, indent=0):
    try: 
        for thing in obj:
            print(">>"*  indent + "%s (%s)" % (thing._name, type(thing)) )
            discover(thing, indent + 1)
    except:
        print("StopIteration")

def dump_state(dut):
    print(dut._id('state_mem.ginfer.ram', extended=False))

@cocotb.coroutine
def reset(clk, rst):
    rst <= 1
    yield RisingEdge(clk)
    yield RisingEdge(clk)
    yield FallingEdge(clk)
    rst <= 0
    yield RisingEdge(clk)


@cocotb.test()
def test_slice(dut):
    log = SimLog("cocotb.%s" % dut._name)
    log.info('this is ' + dut._name)
    cocotb.fork(Clock(dut.clk, 1000, units='ns').start())
    yield reset(dut.clk, dut.rst)
    # yield RisingEdge(dut.clk)
    # yield RisingEdge(dut.clk)
    # yield RisingEdge(dut.clk)
    # yield RisingEdge(dut.clk)

    # discover(dut.state_mem)

    # for s in dut.state_mem.ginfer:
    #     print(s._name)
    yield RisingEdge(dut.clk)
    yield RisingEdge(dut.clk)
    for _ in range(0, 26):
        # yield Edge(dut.controller.state)
        yield Edge(dut.controller.round_cntr)
        print('round_cntr changed to', int(dut.controller.round_cntr.value) )
    # dump_state(dut)




