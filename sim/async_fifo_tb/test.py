import random

import cocotb
import numpy as np
from cocotb.clock import Clock
from cocotb.regression import TestFactory
from cocotb.triggers import ClockCycles, FallingEdge, ReadOnly, RisingEdge, Timer

import os


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


class CustomClk(Clock):
    def __init__(
        self,
        signal,
        period,
        init_phase: int = 0,
        duty_cycle: float = 0.5,
        dc_jitter: float = 0,
        period_jitter: float = 0,
    ):
        assert 0 < duty_cycle < 1
        assert 0 <= dc_jitter <= 0.2
        assert 0 <= period_jitter <= 0.2
        self.signal = signal
        self.period = period
        self.init_phase = init_phase
        self.duty_cycle = duty_cycle
        self.dc_jitter = dc_jitter
        self.period_jitter = period_jitter

    async def start(self, start_high: int = True):
        st0_val = start_high
        st1_val = not start_high

        # Phase Shift impact on the starting_val
        ph_switch = self.period * self.duty_cycle
        ph_arg = self.period * ((self.init_phase / 360) % 1)
        if ph_arg >= ph_switch:
            self.signal.setimmediatevalue(st1_val)
            ph_wait = int(round(self.period - ph_arg, 3) * 1000)
            await Timer(ph_wait, units="ps")
        else:
            self.signal.setimmediatevalue(st0_val)
            p_st0 = int(round(ph_switch - ph_arg, 3) * 1000)
            p_st1 = int(round(self.period - ph_switch, 3) * 1000)
            await Timer(p_st0, units="ps")
            self.signal.setimmediatevalue(st1_val)
            await Timer(p_st1, units="ps")

        while True:
            # calc new period + duty_cycle
            p_jitt = random.gauss(1, self.period_jitter / 2)
            dc_jitt = random.gauss(1, self.dc_jitter / 2)
            period_jittered = self.period * p_jitt
            duty_cycle_jittered = self.duty_cycle * dc_jitt
            high_p = period_jittered * duty_cycle_jittered
            low_p = period_jittered * (1 - duty_cycle_jittered)
            st0_round = round(high_p, 3)
            st1_round = round(low_p, 3)
            # apply
            self.signal.setimmediatevalue(st0_val)  # Stage 0
            await Timer(time=int(st0_round * 1000), units="ps")
            self.signal.setimmediatevalue(st1_val)  # Stage 1
            await Timer(time=int(st1_round * 1000), units="ps")


async def test(
    dut,
    clkA_period: int,
    clkB_period: int,
    clkB_offset: int,
    simple_clocks: bool = False,
):
    # Init TB class
    afifo_tb = asyncFTB(dut)
    cocotb.start_soon(afifo_tb.reader.read_constantly())

    # Generate clocks
    if simple_clocks:
        cocotb.start_soon(Clock(dut.clkA_i, clkA_period, "ns").start())
        await Timer(clkB_offset, "ps")
        cocotb.start_soon(Clock(dut.clkB_i, clkB_period, "ns").start())
    else:
        cocotb.start_soon(
            CustomClk(
                dut.clkA_i, clkA_period, dc_jitter=0.05, period_jitter=0.2
            ).start()
        )
        cocotb.start_soon(
            CustomClk(
                dut.clkB_i,
                clkB_period,
                init_phase=clkB_offset,
                dc_jitter=0.05,
                period_jitter=0.2,
            ).start()
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
    rif = afifo_tb.rif
    while rif.rrdy.value == 1:
        await rif.redge()
    await ClockCycles(rif.clk, 10)

    # Verify correctness
    if afifo_tb.check(inputs):
        cocotb.log.info("Every value has matched!, test passed")
    else:
        raise ValueError("Not every value has matched!")


@cocotb.test()
async def full_test(
    dut,
    clkA_period: int = 5,
    clkB_period: int = 20,
    clkB_offset: int = 0,
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
            CustomClk(
                dut.clkA_i, clkA_period, dc_jitter=0.05, period_jitter=0.2
            ).start()
        )
        cocotb.start_soon(
            CustomClk(
                dut.clkB_i,
                clkB_period,
                init_phase=clkB_offset,
                dc_jitter=0.05,
                period_jitter=0.2,
            ).start()
        )

    # Reset
    await ClockCycles(dut.clkB_i, 10)
    await afifo_tb.reset()
    await ClockCycles(dut.clkB_i, 10)

    # Generate inputs to fully fill the FIFO
    input_len = pow(2, dut.BUFFER_DEPTH_POWER.value) - 1
    print(input_len)
    inputs = afifo_tb.gen_inputs(8, input_len)

    # Send N values to the DUT
    for id, val in enumerate(inputs):
        cocotb.log.info(f"{id} ,{val}")
        await afifo_tb.driver.write(int(val))
        await afifo_tb.wif.redge()
        await ReadOnly()
        if afifo_tb.wif.wrdy.value == 0:
            break

    cocotb.start_soon(afifo_tb.reader.read_constantly())
    rif = afifo_tb.rif
    while rif.rrdy.value == 1:
        await rif.redge()
    await ClockCycles(rif.clk, 10)

    if len(afifo_tb.reader.received) != input_len:
        raise ValueError(
            f"Received less than what has been sent {len(afifo_tb.reader.received)} != {input_len}"
        )

    # Verify correctness
    if afifo_tb.check(inputs):
        cocotb.log.info("Every value has matched!, test passed")
    else:
        raise ValueError("Not every value has matched!")


period_n = 2
offset_n = 2
clkA_periods = [random.randrange(1, 50, 1) for x in range(period_n)]
clkB_periods = [random.randrange(1, 5, 1) for x in range(period_n)]
clk_periods = np.concatenate([np.array(clkA_periods), np.array(clkB_periods)])
offsets = [random.randrange(0, 360, 1) for x in range(offset_n)]

tf1 = TestFactory(test)
tf1.add_option("clkA_period", clk_periods)
tf1.add_option("clkB_period", clk_periods)
tf1.add_option("clkB_offset", offsets)
tf1.generate_tests("generic test")