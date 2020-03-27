import random
import logging

import cocotb

from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.result import TestFailure
from collections import deque
from random import randint


async def reset_dut(reset_n, duration, is_neg=False):
    reset_n <= (not is_neg)
    await Timer(duration, 'ns')
    reset_n <= is_neg
    reset_n._log.debug("Reset complete")




expected = deque()



def gen(min, max):
  while True:
    yield {'u': randint(min, max)}
  
async def feeder(dut, portname, data_gen):
  global expected
  
  in_width = getattr(dut, "io_in_data_u").value.n_bits # TODO FIXME change data_gen
  
  M = int(dut._name.split("_")[1])
  def golden(x):
    x = x['u']
    return {'U': x, 'r': x % M, 'q': x // M}

  
  valid = getattr(dut, portname + '_valid')
  ready = getattr(dut, portname + '_ready')


  for x in data_gen(0, 2**in_width - 1):
      for p,v in x.items():
        getattr(dut, portname + '_data_' + p) <= v
      valid <= 1

      await RisingEdge(dut.clk)
      while(ready != True):
        await RisingEdge(dut.clk)

      expected.append(golden(x))


@cocotb.test()
async def test(dut):
    """
    test constant reduction
    """
    clock_name = 'clk'
    reset_name = 'rst'
    
    outport_name = 'io_out'
    
    global expected
    clock = dut.clk if hasattr(dut, clock_name) else None
    reset = dut.rst if hasattr(dut, reset_name) else None

    cocotb.fork(Clock(clock, 1, 'ns').start())

    # dut.U_valid <= 0
    
    out_ready = getattr(dut, outport_name + '_ready')
    out_valid = getattr(dut, outport_name + '_valid')
    out_ready <= 0
    
    await reset_dut(reset, 3)

    n = 10000
    await RisingEdge(dut.clk)
    cocotb.fork(feeder(dut, 'io_in', gen))


    for t in range(0, n):
      out_ready <= 1

      await RisingEdge(dut.clk)

      while len(expected) < 1:
        await RisingEdge(dut.clk)
      exp = expected.popleft()

      while(not out_valid.value):
        await RisingEdge(dut.clk)

      r = getattr(dut, outport_name + '_data_' + 'r').value.integer
      q = getattr(dut, outport_name + '_data_' + 'q').value.integer if hasattr(dut,
                                                                             outport_name + '_data_' + 'q') else exp['q']
      if r != exp['r'] or q != exp['q']:
          raise TestFailure(
              f"Output {t} didn't match! U={exp['U']} \n r:{r} expected:{exp['r']}\n q={q} expected={exp['q']}")
