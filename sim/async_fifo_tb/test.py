import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, ClockCycles, ReadWrite
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from pyuvm import *
import numpy as np

import random

class Interface:
  def __init__(self, clk, rst) -> None:
    self.clk = clk
    self.rst = rst

  async def redge(self):
    await RisingEdge(self.clk)

  async def fedge(self):
    await FallingEdge(self.clk)

  async def reset(self, cycles : int = 5, active_high : bool =False):
    self.rst.setimmediatevalue(active_high)
    await ClockCycles(self.clk, cycles)
    self.rst.setimmediatevalue(not active_high)

class WriteInterface(Interface):
  def __init__(self, dut) -> None:
    self.we = dut.cA_we_i
    self.wdata = dut.cA_din_i
    self.wrdy = dut.cA_wrdy_o
    super().__init__(dut.clkA_i, dut.cA_rst_ni)

class ReadInterface(Interface):
  def __init__(self, dut) -> None:
    self.re = dut.cB_re_i
    self.rdata = dut.cB_dout_o
    self.rrdy = dut.cB_rrdy_o
    super().__init__(dut.clkB_i, dut.cB_rst_ni)

class Driver():
  def __init__(self, wif : WriteInterface) -> None:
    self._if = wif

  async def write(self, value : int):
    await self._if.redge()
    await ReadOnly()
    while (not self._if.wrdy.value):
      await self._if.redge()
      await ReadOnly()
    await self._if.fedge()
    self._if.wdata.setimmediatevalue(value)
    self._if.we.setimmediatevalue(1)
    await self._if.fedge()
    self._if.we.setimmediatevalue(0)

class Receiver():
  def __init__(self, rif : ReadInterface) -> None:
    self._if = rif
    self.received = []

  async def read_constantly(self):
    while True:
      await self._if.redge()
      await ReadOnly()
      if (self._if.rrdy.value):
        await self._if.fedge()
        self._if.re.setimmediatevalue(1)
        await self._if.fedge()
        self._if.re.setimmediatevalue(0)
        self.received.append(self._if.rdata.value.integer)

class asyncFTB():
  def __init__(self, dut) -> None:
    self.dut = dut
    self.wif = WriteInterface(dut)
    self.rif = ReadInterface(dut)
    self.driver = Driver(self.wif)
    self.reader = Receiver(self.rif)
    self.init_ports()
    cocotb.start_soon(self.reader.read_constantly())

  def init_ports(self):
    self.dut.cA_din_i.setimmediatevalue(0)
    self.dut.cA_we_i.setimmediatevalue(0)
    self.dut.cB_re_i.setimmediatevalue(0)
    self.dut.cA_rst_ni.setimmediatevalue(1)
    self.dut.cB_rst_ni.setimmediatevalue(1)

  def gen_inputs(self, data_width, n):
    return np.random.randint(0, pow(2,data_width)-1, n, dtype=np.int32)

  def check(self, inputs):
    return (np.array(self.reader.received, dtype=np.int32) == inputs).all()

  async def reset(self, cycles=5):
    rst_w = cocotb.start_soon(self.wif.reset(cycles))
    rst_r = cocotb.start_soon(self.rif.reset(cycles))
    await cocotb.triggers.Combine(rst_r, rst_w)
    cocotb.log.info("Reset Done!")


async def test(dut, clkA_period, clkB_period):
  # Check test environment
  if clkA_period % 2 or clkB_period % 2:
    raise ValueError(f"Periods non-divisible by 2, {[clkA_period, clkB_period]}")

  # Init TB class
  afifo_tb = asyncFTB(dut)

  # Generate clocks
  cocotb.start_soon(Clock(dut.clkA_i, clkA_period).start())
  cocotb.start_soon(Clock(dut.clkB_i, clkB_period).start())

  # Reset
  await ClockCycles(dut.clkB_i, 10)
  await afifo_tb.reset()
  await ClockCycles(dut.clkB_i, 10)

  # Generate inputs
  inputs = afifo_tb.gen_inputs(8, 1000)

  # Send N values to the DUT
  for val in inputs:
    await afifo_tb.driver.write(int(val))

  # Give reader the time to read last value
  await ClockCycles(dut.clkB_i, 10)

  # Verify correctness
  if (afifo_tb.check(inputs)):
    cocotb.log.info("Every value has matched!, test passed")
  else:
    raise ValueError("Not every value has matched!")


period_n = 5
clkA_periods = [random.randrange(2, 20, 2) for x in range(period_n)]
clkB_periods = [random.randrange(2, 20, 2) for x in range(period_n)]

tf = TestFactory(test)
tf.add_option("clkA_period", clkA_periods)
tf.add_option("clkB_period", clkB_periods)
tf.generate_tests("generic test")