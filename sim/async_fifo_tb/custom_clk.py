from random import gauss

from cocotb.triggers import Timer
from cocotb.utils import _get_simulator_precision


class CustomClk:
    _supported_timeunits = {
        "step": None,
        "ps": -12,
        "ns": -9,
        "us": -6,
        "ms": -3,
        "s": 0,
    }

    def __init__(
        self,
        signal,
        period: float,
        duty_cycle: float = 0.5,
        phase_shift: int = 0,
        dc_jitt_sigma: float = 0,
        p_jitt_sigma: float = 0,
        units: str = "ns",
        precision: str = "ps",
    ):
        assert 0 < duty_cycle < 1
        assert 0 <= dc_jitt_sigma <= 0.1
        assert 0 <= p_jitt_sigma <= 0.1
        self.signal = signal
        self.period = period
        self.phase_shift = phase_shift
        self.duty_cycle = duty_cycle
        self.dc_jitt_sigma = dc_jitt_sigma
        self.p_jitt_sigma = p_jitt_sigma

        if precision == "step":
            if _get_simulator_precision() not in self._supported_timeunits.items():
                self._supported_timeunits["step"] = _get_simulator_precision()
        else:
            if precision not in self._supported_timeunits.keys():
                raise ValueError(f"This time precision is not supported")

        if units not in self._supported_timeunits.keys():
            raise ValueError(f"This time unit is not supported")

        self.units = units
        self.precision = precision
        self.precision_diff = (
            self._supported_timeunits[precision] - self._supported_timeunits[units]
        )

    def jitt_str(self) -> str:
        def ranger(mu, sigma):
            return f"({mu * (1-sigma*3)}, {mu * (1 + sigma*3)})"

        return (
            f"Given that we use GAUSSIAN distribution of jitter: \n"
            f"- Period range = gauss(mu={self.period}, sigma={self.p_jitt_sigma}) ~= {ranger(self.period, self.p_jitt_sigma)} {self.units} \n"
            f"- Duty cycle range = gauss(mu={self.duty_cycle}, sigma={self.dc_jitt_sigma}) ~= {ranger(self.duty_cycle, self.dc_jitt_sigma)}"
        )

    def t_unit_to_prec(self, period: float):
        return period * pow(10, abs(self.precision_diff))

    async def _Timer(self, period: float):
        period_ps = int(self.t_unit_to_prec(period))
        await Timer(period_ps, units=self.precision)

    async def start(self, start_high: int = True):
        st0_val = start_high
        st1_val = not start_high

        # Phase Shift impact on the starting_val
        ph_switch = self.period * self.duty_cycle
        ph_arg = self.period * ((self.phase_shift / 360) % 1)
        if ph_arg >= ph_switch:
            self.signal.setimmediatevalue(st1_val)
            ph_wait = self.period - ph_arg
            await self._Timer(ph_wait)
        else:
            self.signal.setimmediatevalue(st0_val)
            p_st0 = ph_switch - ph_arg
            p_st1 = self.period - ph_switch
            await self._Timer(p_st0)
            self.signal.setimmediatevalue(st1_val)
            await self._Timer(p_st1)

        while True:
            # calc new period + duty_cycle
            p_jitt = gauss(1, self.p_jitt_sigma)
            dc_jitt = gauss(1, self.dc_jitt_sigma)
            period_jittered = self.period * p_jitt
            duty_cycle_jittered = self.duty_cycle * dc_jitt
            st0_round = period_jittered * duty_cycle_jittered
            st1_round = period_jittered * (1 - duty_cycle_jittered)
            self.signal.setimmediatevalue(st0_val)  # Stage 0
            await self._Timer(st0_round)
            self.signal.setimmediatevalue(st1_val)  # Stage 1
            await self._Timer(st1_round)


if __name__ == "__main__":
    a = CustomClk(0, 10, dc_jitt_sigma=0, p_jitt_sigma=0.1)
    print(a.jitt_str())
