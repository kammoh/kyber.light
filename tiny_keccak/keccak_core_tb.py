############################################################################################################
##
## @description:  CocoTB testbench for keccak_core
##
## @author:       Kamyar Mohajerani
##
## @requirements: Python 3.5+, CocoTB 1.1+
## @copyright:    (c) 2019
##
############################################################################################################
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, Join, NextTimeStep
from cocotb.binary import BinaryValue
from cocotb.result import TestFailure, TestError, TestSuccess, ReturnValue
from cocotb.log import SimLog
from cocotb.wavedrom import Wavedrom
from cocotb.monitors import BusMonitor
import random
from collections import deque
import tiny_keccak

# yield:
# yield <coroutine>: run and wait on completion
# a = yield Trigger <-- yield returns a value!
# can yield a list of triggers! == join_any, returns the trigger that fired first!


def dump_state(dut):
    print(dut._id('state_mem.ginfer.ram', extended=False))


def golden_result(input_bytes, rate, delim=0x06):
    k = tiny_keccak.Keccak(rate=rate , delim=delim)

    for b in input_bytes:
        k.py_update(bytes([b]))
    #k.pad()
    k.xorin()
    # k.dump_state() # currently does not work with GHDL :(
    k.keccakf()
    return ''.join(format(x, '016X')[::-1] for x in k.state[:rate // 8])


@cocotb.coroutine
def reset(clk, rst):
    rst <= 1
    yield RisingEdge(clk)
    yield RisingEdge(clk)
    yield FallingEdge(clk)
    rst <= 0
    yield RisingEdge(clk)



class StreamTester:

    def __init__(self, dut):
        self.dut = dut
        self.inputs = deque()
        self.outputs = []
        self.log = SimLog("cocotb.%s" % dut._name)
        
        self.driver_thread = cocotb.fork(self.start_driver())
        self.monitor_thread = cocotb.fork(self.start_monitor())
        
    def add_inputs(self, inputs):
        self.inputs.extend(inputs)

    @cocotb.coroutine
    def start_driver(self):
        clkedge = RisingEdge(self.dut.clk)
        while True:
            while len(self.inputs) == 0:
                yield clkedge
            while len(self.inputs) > 0:
                i = self.inputs.popleft()
                for d in [i % 16, i // 16]:
                    self.dut.i_din_data <= d
                    while True:
                        self.dut.i_din_valid <= random.randint(0, 1)
                        yield clkedge
                        if self.dut.o_din_ready == 1 and self.dut.i_din_valid == 1:
                            break
            self.dut.i_din_valid <= 0
            self.log.info("all inputs consumed!")

    @cocotb.coroutine
    def start_monitor(self):
        while True:
            self.dut.i_dout_ready <= random.randint(0, 1)
            yield RisingEdge(self.dut.clk)
            if self.dut.i_dout_ready == 1 and self.dut.o_dout_valid == 1:
                self.outputs.append(int((self.dut.o_dout_data.value)))
        self.log.info("monitor exiting...")
    
    @cocotb.coroutine
    def wait_for_done(self):
        dut = self.dut
        while True:
            yield RisingEdge(dut.clk)
            if dut.o_done == 1:
                self.log.info("done signal asserted")
                break
    
    def output(self):
        r = ''.join(format(x, '1X') for x in self.outputs)
        self.outputs.clear()
        return r


# @cocotb.test()
# def test_keccak(dut):
#     log = SimLog("cocotb.%s" % dut._name)
#     log.info('this is ' + dut._name)
#     cocotb.fork(Clock(dut.clk, 10, units='ns').start())
#     yield reset(dut.clk, dut.rst)
#     yield RisingEdge(dut.clk)
    
#     tester = StreamTester(dut)
    
#     dut.i_squeeze <= 0
#     dut.i_absorb <= 0
#     dut.i_init <= 1
#     log.info("init: waiting for done")
#     yield tester.wait_for_done()
#     dut.i_init <= 0
#     yield RisingEdge(dut.clk)

#     for _ in range(0, 5):
#         input_bytes = []
#         rate = random.randint(1, 25) * 8
#         log.info(f"rate={rate}")
#         for _ in range(0, rate):
#             input_bytes.append(random.randint(0, 255))
#         dut.i_rate <= rate // 8
        
#         tester.add_inputs(input_bytes)
        
#         dut.i_absorb <= 1
#         log.info("absorb: waiting for done")
#         yield tester.wait_for_done()
#         dut.i_absorb <= 0
#         yield RisingEdge(dut.clk)
        
#         dut.i_squeeze <= 1
#         dut.i_init <= 1
#         log.info("squeeze: waiting for done")
#         yield tester.wait_for_done()
#         dut.i_squeeze <= 0
#         dut.i_init <= 0
#         yield RisingEdge(dut.clk)
        
#         expected = golden_result(input_bytes, rate)
#         dout_str = tester.output()
#         if dout_str != expected:
#             raise TestFailure(f"dout_str={dout_str} expected={expected}")
#         else:
#             log.info(f"Test PASSED! output was: {dout_str}")
    # dump_state(dut)

@cocotb.test()
def test_keccak(dut):
    log = SimLog("cocotb.%s" % dut._name)
    log.info('this is ' + dut._name)
    cocotb.fork(Clock(dut.clk, 10, units='ns').start())
    yield reset(dut.clk, dut.rst)
    yield RisingEdge(dut.clk)

    for c in dut:
            dut.log.info(f" got {c._name}")
    
    
    tester = StreamTester(dut)
    
    dut.i_squeeze <= 0
    dut.i_absorb <= 0
    dut.i_init <= 1
    log.info("init: waiting for done")
    yield tester.wait_for_done()
    dut.i_init <= 0
    yield RisingEdge(dut.clk)

    for _ in range(0, 5):
        input_bytes = []
        rate = random.randint(1, 25) * 8
        log.info(f"rate={rate}")
        for _ in range(0, rate):
            input_bytes.append(random.randint(0, 255))
        dut.i_rate <= rate // 8
        
        tester.add_inputs(input_bytes)
        
        dut.i_absorb <= 1
        log.info("absorb: waiting for done")
        yield tester.wait_for_done()
        dut.i_absorb <= 0
        yield RisingEdge(dut.clk)
        
        dut.i_squeeze <= 1
        dut.i_init <= 1
        log.info("squeeze: waiting for done")
        yield tester.wait_for_done()
        dut.i_squeeze <= 0
        dut.i_init <= 0
        yield RisingEdge(dut.clk)
        
        expected = golden_result(input_bytes, rate)
        dout_str = tester.output()
        if dout_str != expected:
            raise TestFailure(f"dout_str={dout_str} expected={expected}")
        else:
            log.info(f"Test PASSED! output was: {dout_str}")