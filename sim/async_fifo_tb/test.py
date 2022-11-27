import random

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.regression import TestFactory
from cocotb.triggers import (ClockCycles, FallingEdge, ReadOnly, ReadWrite,
                             RisingEdge, Timer)


class Interface:
    def __init__(self, clk, rst) -> None:
        self.clk = clk
        self.rst = rst

    async def redge(self):
        await RisingEdge(self.clk)

    async def fedge(self):
        await FallingEdge(self.clk)

    async def reset(self, cycles: int = 5, active_high: bool = False):
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


class Driver:
    def __init__(self, wif: WriteInterface) -> None:
        self._if = wif

    async def write(self, value: int):
        await self._if.redge()
        await ReadOnly()
        while not self._if.wrdy.value:
            await self._if.redge()
            await ReadOnly()
        await self._if.fedge()
        self._if.wdata.setimmediatevalue(value)
        self._if.we.setimmediatevalue(1)
        await self._if.fedge()
        self._if.we.setimmediatevalue(0)


class Receiver:
    def __init__(self, rif: ReadInterface) -> None:
        self._if = rif
        self.received = []

    async def read_constantly(self):
        while True:
            await self._if.redge()
            await ReadOnly()
            if self._if.rrdy.value:
                await self._if.fedge()
                self._if.re.setimmediatevalue(1)
                await self._if.fedge()
                self._if.re.setimmediatevalue(0)
                self.received.append(self._if.rdata.value.integer)


class asyncFTB:
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
        return np.random.randint(0, pow(2, data_width) - 1, n, dtype=np.int32)

    def check(self, inputs):
        return (np.array(self.reader.received, dtype=np.int32) == inputs).all()

    async def reset(self, cycles=5):
        rst_w = cocotb.start_soon(self.wif.reset(cycles))
        rst_r = cocotb.start_soon(self.rif.reset(cycles))
        await cocotb.triggers.Combine(rst_r, rst_w)
        cocotb.log.info("Reset Done!")


async def clk_gen(
    clk_sig,
    period: int = 10,
    init_phase_offset: int = 0,
    duty_cycle: float = 0.5,
    dc_jitter: float = 0.1,
    period_jitter: float = 0.1,
    start_val: bool = True,
):

    assert 0 < duty_cycle < 1
    assert 0 <= dc_jitter <= 0.2
    assert 0 <= period_jitter <= 0.2

    initial_phase_offset = init_phase_offset
    clk_val = start_val

    clk_sig.setimmediatevalue(not clk_val)  # Stage 0
    if initial_phase_offset:
        await Timer(initial_phase_offset, "ps")  # Phase offset

    while True:
        p_jitt = random.gauss(1, period_jitter / 2)
        dc_jitt = random.gauss(1, dc_jitter / 2)
        period_jittered = period * p_jitt
        duty_cycle_jittered = duty_cycle * dc_jitt
        high_p = period_jittered * duty_cycle_jittered
        low_p = period_jittered * (1 - duty_cycle_jittered)
        high_p_round = round(high_p, 3)
        low_p_round = round(low_p, 3)

        clk_sig.setimmediatevalue(clk_val)  # Stage 0
        clk_val = not clk_val
        await Timer(time=int(high_p_round * 1000), units="ps")
        clk_sig.setimmediatevalue(clk_val)  # Stage 1
        clk_val = not clk_val
        await Timer(time=int(low_p_round * 1000), units="ps")


async def test(
    dut,
    clkA_period: int,
    clkB_period: int,
    clkB_offset: int,
    simple_clocks: bool = False,
):
    # Init TB class
    afifo_tb = asyncFTB(dut)

    # Generate clocks
    if simple_clocks:
        cocotb.start_soon(Clock(dut.clkA_i, clkA_period, "ns").start())
        await Timer(clkB_offset, "ps")
        cocotb.start_soon(Clock(dut.clkB_i, clkB_period, "ns").start())
    else:
        cocotb.start_soon(
            clk_gen(dut.clkA_i, clkA_period, period_jitter=0.1, dc_jitter=0)
        )
        cocotb.start_soon(
            clk_gen(
                dut.clkB_i, clkB_period, clkB_offset, period_jitter=0.1, dc_jitter=0
            )
        )

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
    if afifo_tb.check(inputs):
        cocotb.log.info("Every value has matched!, test passed")
    else:
        raise ValueError("Not every value has matched!")


period_n = 2
clkA_periods = [random.randrange(1, 20, 1) for x in range(period_n)]
clkB_periods = [random.randrange(1, 10, 1) for x in range(period_n)]
clk_periods = np.concatenate([np.array(clkA_periods), np.array(clkB_periods)])
offsets = [random.randrange(1, 3000, 1) for x in range(len(clk_periods))]

tf = TestFactory(test)
tf.add_option("clkA_period", clk_periods)
tf.add_option("clkB_period", clk_periods)
tf.add_option("clkB_offset", offsets)
tf.generate_tests("generic test")
