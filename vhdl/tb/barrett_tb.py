import random
import logging

import cocotb

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import TestFailure
from collections import deque
from random import randint


@cocotb.coroutine
def reset_dut(reset_n, duration, is_neg=False):
    reset_n <= (not is_neg)
    yield Timer(duration, 'ns')
    reset_n <= is_neg
    reset_n._log.debug("Reset complete")


M = 3329

expected = deque()

def golden(x):
  return {'U': x, 'r': x % M, 'q': x // M}
  
def gen(min, max):
  while True:
    yield randint(min, max)
  
@cocotb.coroutine
def feeder(dut, portname, gen):
  data = getattr(dut, portname)
  valid = getattr(dut, portname + '_valid')
  ready = getattr(dut, portname + '_ready')
  in_width = data.value.n_bits

  for x in gen(0, 2**in_width - 1):
      data <= x
      valid <= 1

      yield RisingEdge(dut.clk)
      while(ready != True):
        yield RisingEdge(dut.clk)

      expected.append(golden(x))


@cocotb.test()
def test(dut):
    """
    test constant reduction
    """
    clock = dut.clk if hasattr(dut, 'clk') else None
    reset = dut.rst if hasattr(dut, 'rst') else None

    cocotb.fork(Clock(clock, 1, 'ns').start())

    dut.U_valid <= 0
    dut.rq_ready <= 0
    
    yield reset_dut(reset, 3)

    n = 30000
    yield RisingEdge(dut.clk)
    cocotb.fork(feeder(dut, 'U', gen))


    for t in range(0, n):
      dut.rq_ready <= 1

      yield RisingEdge(dut.clk)

      while len(expected) < 1:
        yield RisingEdge(dut.clk)
      exp = expected.popleft()

      while(dut.rq_valid != True):
        yield RisingEdge(dut.clk)

      r = dut.r.value.integer
      q = dut.q.value.integer
      if r != exp['r'] or q != exp['q']:
          raise TestFailure(
              f"Output {t} didn't match! U={exp['U']} \n r:{r} expected:{exp['r']}\n q={q} expected={exp['q']}")
