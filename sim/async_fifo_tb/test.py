import cocotb
from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge, FallingEdge, ReadOnly, ClockCycles, ReadWrite
from cocotb.clock import Clock
from pyuvm import *

class Word:
  def __init__(self, data) -> None:
    self.data = data

class WriteInterface:
  def __init__(self, dut) -> None:
    self.clk = dut.clkA_i
    self.rst = dut.cA_rst_ni
    self.we = dut.cA_we_i
    self.wdata = dut.cA_din_i
    self.wrdy = dut.cA_wrdy_o

  async def redge(self):
    await RisingEdge(self.clk)

  async def fedge(self):
    await FallingEdge(self.clk)

  async def reset(self, cycles=5, active_high=False):
    self.rst.setimmediatevalue(active_high)
    await ClockCycles(self.clk, cycles)
    self.rst.setimmediatevalue(not active_high)

class ReadInterface:
  def __init__(self, dut) -> None:
    self.clk = dut.clkB_i
    self.rst = dut.cB_rst_ni
    self.re = dut.cB_re_i
    self.rdata = dut.cB_dout_o
    self.rrdy = dut.cB_rrdy_o
  async def redge(self):
    await RisingEdge(self.clk)

  async def fedge(self):
    await FallingEdge(self.clk)

  async def reset(self, cycles=5, active_high=False):
    self.rst.setimmediatevalue(active_high)
    await ClockCycles(self.clk, cycles)
    self.rst.setimmediatevalue(not active_high)

class Driver():
  def __init__(self, wif : WriteInterface) -> None:
    self._if = wif
  async def write(self, transaction : Word):
    await self._if.redge()
    await ReadOnly()
    while (not self._if.wrdy.value):
      await self._if.redge()
      await ReadOnly()
    await self._if.fedge()
    self._if.wdata.setimmediatevalue(transaction.data)
    self._if.we.setimmediatevalue(1)
    await self._if.fedge()
    # await ReadWrite()
    self._if.we.setimmediatevalue(0)

class Receiver():
  def __init__(self, rif : ReadInterface) -> None:
    self._if = rif
    # self._sb_que = sb_que
  async def read_constantly(self):
    while True:
      await self._if.redge()
      await ReadOnly()
      if (self._if.rrdy.value):
        await self._if.fedge()
        self._if.re.setimmediatevalue(1)
        await self._if.fedge()
        self._if.re.setimmediatevalue(0)
        transaction = Word(self._if.rdata.value.integer)
        cocotb.log.info(f"Received: {transaction.data}")
        
        # self._sb_que.enque(transaction)

class asyncFTB():
  def __init__(self, dut) -> None:
    self.dut = dut
    self.wif = WriteInterface(dut)
    self.rif = ReadInterface(dut)
    self.driver = Driver(self.wif)
    # self.monitor = 
    self.reader = Receiver(self.rif)
    # self.sb = 
    self.init_ports()
    
    cocotb.start_soon(self.reader.read_constantly())
    
  def init_ports(self):
    
    self.dut.cA_din_i.setimmediatevalue(0)
    self.dut.cA_we_i.setimmediatevalue(0)
    self.dut.cB_re_i.setimmediatevalue(0)
    self.dut.cA_rst_ni.setimmediatevalue(1)
    self.dut.cB_rst_ni.setimmediatevalue(1)
    
    # self.dut.cB_dout_i.setimmediatevalue(0)

  async def reset(self, cycles=5):
    rst_w = cocotb.start_soon(self.wif.reset(cycles))
    rst_r = cocotb.start_soon(self.rif.reset(cycles))
    await cocotb.triggers.Combine(rst_r, rst_w)
    cocotb.log.info("Reset Done!")

@cocotb.test()
async def test(dut):
  cocotb.log.info("IN!")
  dut._discover_all()
  cocotb.log.info(dut._sub_handles)
  print('dut._sub_handles: ', dut._sub_handles)
  
  CLK_PERIOD_A = 10
  CLK_PERIOD_B = 100
  
  afifo_tb = asyncFTB(dut)
  
  clkA = cocotb.start_soon(Clock(dut.clkA_i, CLK_PERIOD_A).start())
  clkB = cocotb.start_soon(Clock(dut.clkB_i, CLK_PERIOD_B).start())
  
  await ClockCycles(dut.clkB_i, 10)
  
  await afifo_tb.reset()
  
  await ClockCycles(dut.clkB_i, 10)
  
  cocotb.log.info("WRITE & READ start ...")
  
  
  await afifo_tb.driver.write(Word(20))
  
  
  await ClockCycles(dut.clkB_i, 1000)
  
  
  
  
  
  
  