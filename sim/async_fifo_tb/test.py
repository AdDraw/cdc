import cocotb
from cocotb.handle import SimHandleBase
from pyuvm import *

@cocotb.test()
async def test(dut):
  cocotb.log.info("IN!")
  dut._discover_all()
  cocotb.log.info(dut._sub_handles)
  cocotb.log.info(len(dut._sub_handles))
  cocotb.log.info(dut._path)
  cocotb.log.info(dut.__len__())