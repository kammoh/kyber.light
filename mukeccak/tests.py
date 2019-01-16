import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge, Edge, Join, NextTimeStep
from cocotb.binary import BinaryValue
from cocotb.result import TestFailure, TestError, TestSuccess, ReturnValue
from cocotb.log import SimLog
from cocotb.wavedrom import Wavedrom
import random

import tiny_keccak

# yield:
# a = yield Trigger <-- yield returns a value!
# can yield a list of triggers! == join_any, returns the trigger that fired first!


def dump_state(dut):
    print(dut._id('state_mem.ginfer.ram', extended=False))


def golden_result(input_bytes, rate, delim=0x06):
    k = tiny_keccak.Keccak(rate=rate , delim=delim)

    for i in range(0,rate):
        k.py_update(bytes([input_bytes[i]]))
    k.xorin()
    # k.dump_state()
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


from collections import deque

class StreamDriver:
    def __init__(self, dut, inputs=None):
        self.dut = dut
        self.inputs = deque()
        if inputs:
            self.inputs.extend(inputs)
        self.log = SimLog("cocotb.%s" % dut._name)

    @cocotb.coroutine
    def start(self):
        while len(self.inputs) > 0:
            i = self.inputs.popleft()
            for d in [i % 16, i // 16]:
                self.dut.din <= d
                while True:
                    self.dut.din_valid <= random.randint(0,1)
                    yield RisingEdge(self.dut.clk)
                    if self.dut.din_ready == 1 and self.dut.din_valid == 1:
                        break
        self.dut.din_valid <= 0
        self.log.info("all inputs consumed!")

class StreamMonitor:
    def __init__(self, dut):
        self.dut = dut
        self.log = SimLog("cocotb.%s" % dut._name)
        self.outputs = []

    @cocotb.coroutine
    def start(self):
        while True:
            self.dut.dout_ready <= random.randint(0,1)
            yield RisingEdge(self.dut.clk)
            if self.dut.dout_ready == 1 and self.dut.dout_valid == 1:
                self.outputs.append(int((self.dut.dout.value)))
        self.log.info("monitor exiting...")

    
    def string(self):
        return ''.join(format(x, '1X') for x in self.outputs)


@cocotb.test()
def test_keccak(dut):
    log = SimLog("cocotb.%s" % dut._name)
    log.info('this is ' + dut._name)
    cocotb.fork(Clock(dut.clk, 10, units='ns').start())
    yield reset(dut.clk, dut.rst)

    for _ in range(0,5):
        input_bytes=[]
        rate = random.randint(1,25) * 8
        log.info(f"rate={rate}")
        for _ in range(0,rate):
            input_bytes.append(random.randint(0,255))
        dut.rate <= rate // 8
        driver = cocotb.fork(StreamDriver(dut, input_bytes).start())
        monitor = StreamMonitor(dut)
        cocotb.fork(monitor.start())
        
        dut.absorb <= 1
        dut.squeeze <= 0
        yield RisingEdge(dut.clk)
        log.info("absorb: waiting for done")
        while True:
            yield RisingEdge(dut.clk)
            if dut.done == 1:
                log.info("done signal asserted (1)")
                break
        
        dut.absorb <= 0
        dut.squeeze <= 1
        yield RisingEdge(dut.clk)
        log.info("squeeze: waiting for done")
        while True:
            yield RisingEdge(dut.clk)
            if dut.done == 1:
                log.info("done signal asserted (2)")
                break
        
        # yield driver.join()

        expected = golden_result(input_bytes, rate)
        dout_str = monitor.string()
        if dout_str != expected:
            raise TestFailure(f"dout_str={dout_str} expected={expected}")
        else:
            log.info(f"Test PASSED! output was: {dout_str}")
    # dump_state(dut)
