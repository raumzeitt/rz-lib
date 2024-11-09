#
# Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
#
# CERN Open Hardware Licence Version 2 - Permissive
#
# Copyright (C) 2024 Robert Metchev
#
import logging
import random
import os

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer, with_timeout

from cocotbext.axi import AxiStreamBus, AxiStreamFrame, AxiStreamSource, AxiStreamSink

class Tester():
    def __init__(self, dut):
        self.dut = dut

        self.log = logging.getLogger("cocotb.tb")
        self.log.setLevel(logging.DEBUG)
        dut.log.setLevel(logging.DEBUG)

        if os.environ['FIFO'] == 'AFIFO':
            # Clock generation for s_axis_aclk
            S_AXIS_CLK_PERIOD = 8.77               # ~114MHz
            cocotb.start_soon(Clock(self.dut.s_axis_aclk, S_AXIS_CLK_PERIOD, units="ns").start())

            # Clock generation for m_axis_aclk
            M_AXIS_CLK_PERIOD = 13.47              # ~74.25MHz
            cocotb.start_soon(Clock(self.dut.m_axis_aclk, M_AXIS_CLK_PERIOD, units="ns").start())
            
            self.s_axis_aclk = self.dut.s_axis_aclk
            self.m_axis_aclk = self.dut.m_axis_aclk
            self.s_axis_aresetn = self.dut.s_axis_aresetn
            self.m_axis_aresetn = self.dut.m_axis_aresetn

        if os.environ['FIFO'] == 'SFIFO':
            # Clock generation for clk
            CLK_PERIOD = 12.5                       # ~80MHz
            cocotb.start_soon(Clock(self.dut.clk, CLK_PERIOD, units="ns").start())

            self.s_axis_aclk = self.dut.clk
            self.m_axis_aclk = self.dut.clk
            self.s_axis_aresetn = self.dut.resetn
            self.m_axis_aresetn = self.dut.resetn

        # Attach buses
        self.source = AxiStreamSource(AxiStreamBus.from_prefix(self.dut, "s_axis"), self.s_axis_aclk, self.s_axis_aresetn, False,  byte_lanes=1)
        self.sink = AxiStreamSink(AxiStreamBus.from_prefix(self.dut, "m_axis"), self.m_axis_aclk, self.m_axis_aresetn, False, byte_lanes=1)


    def set_idle_generator(self, generator=None):
        if generator:
            self.source.set_pause_generator(generator())

    def set_backpressure_generator(self, generator=None):
        if generator:
            self.sink.set_pause_generator(generator())


async def fifo_reset(c, r):
    for v in [1, 0, 1]:
        r.value = v
        await ClockCycles(c, 4)

def rand_generator():
    while True:
        yield random.randint(0, 1)

def zero_generator():
    while True:
        yield 0

def one_generator():
    while True:
        yield 1

@cocotb.test()
async def test_fifo(dut):
    # initializer tester
    tb = Tester(dut)
    
    # reset the FIFO
    if os.environ['FIFO'] == 'AFIFO':
        s = cocotb.start_soon(fifo_reset(dut.s_axis_aclk, dut.s_axis_aresetn))
        m = cocotb.start_soon(fifo_reset(dut.m_axis_aclk, dut.m_axis_aresetn))
        await cocotb.triggers.Combine(s, m)
    if os.environ['FIFO'] == 'SFIFO':
        await cocotb.start_soon(fifo_reset(dut.clk, dut.resetn))
    
    # Pause RX & TX
    tb.set_idle_generator(one_generator)
    tb.set_backpressure_generator(one_generator)

    # send N test frames
    depth = 8192
    n_vectors = 2*depth  # send n vectors = test frames
    tb.set_idle_generator(rand_generator) # schmoo backpressure & starvation
    test_frames = []
    dut._log.info(f"INFO: SEND {n_vectors} test frames")
    for test_data in range(n_vectors):
        test_frame = AxiStreamFrame([test_data])
        await tb.source.send(test_frame)
        test_frames.append(test_frame)

    # start receveing the test frames after a bunch of cycles
    await ClockCycles(tb.s_axis_aclk, int(2.5*depth))
    tb.set_backpressure_generator(rand_generator) # schmoo backpressure & starvation
    rx_frames = []
    dut._log.info(f"INFO: RECEIVE {n_vectors} test frames")
    for test_frame in test_frames:
        rx_frame = await tb.sink.recv()
        rx_frames.append(rx_frame)
        
    # Pause the receiver
    tb.set_backpressure_generator(one_generator)

    # Check results
    assert test_frames == rx_frames
    assert tb.sink.empty()
    assert tb.source.empty()

    await ClockCycles(tb.s_axis_aclk, 50)
