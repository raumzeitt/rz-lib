import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer,  First, Edge
from cocotbext.spi import SpiMaster, SpiBus, SpiConfig
from cocotb_bus.bus import Bus

import sys, os, time, random, logging

async def clock_n_reset(c, r, f=0, n=5, t=10):
    if r is not None:
        r.value = 0
    if c is not None:
        period = round(10e9/f, 2) # in ns
        cocotb.start_soon(Clock(c, period, units="ns").start())
        await ClockCycles(c, n)
    else:
        await Timer(t, 'us')
    if r is not None:
        r.value = 1


class SpiTransactor:
    def __init__(self, dut):
        self.dut = dut
        self.log = logging.getLogger("SPI Transactor")
        self.log.setLevel(self.dut._log.level)

        # Define bus as recommended
        self.bus = Bus(dut, None, 
            {
                "sclk": "spi_clock_in",
                "miso": "spi_data_out",
                "mosi": "spi_data_in",
                "cs":   "spi_select_in",
            }, optional_signals=[]
        )

        # Define SPI config
        self.config = SpiConfig(
            word_width  = 8,        # 8 bits
            sclk_freq   = 8e6,      # 8 MHz
            cpol        = 0,
            cpha        = 0,
            msb_first   = True,
            frame_spacing_ns = 125,
            #ignore_rx_value = None,
            cs_active_low = True,   # optional (assumed True)
        )

        self.source = SpiMaster(self.bus, self.config)

    async def spi_write(self, address, data):
        try:
            if len(data) == 0:
                data = [0]
        except TypeError:
            data = [data]
        self.log.info(f"SPI WRITE: ADDRESS=0x{address:02x} DATA={[hex(i) for i in data]} ")
        await self.source.write([address] + data, burst=True)
        _ = await self.source.read() # flush read queue

    async def spi_command(self, address):
        self.log.info(f"SPI COMMAND: ADDRESS=0x{address:02x}")
        await self.source.write([address], burst=True)
        _ = await self.source.read() # flush read queue

    async def spi_read(self, address, n=1):
        d = [address] + [0]*n
        await self.source.write([address] + [0]*n, burst=True)
        read_bytes = await self.source.read()
        read_bytes = read_bytes[1:]
        self.log.info(f"SPI READ:  ADDRESS=0x{address:02x} DATA={[hex(i) for i in read_bytes]} ")
        return [int(i) for i in read_bytes]


@cocotb.test()
async def spi_test(dut):
    log_level = os.environ.get('LOG_LEVEL', 'INFO') # NOTSET=0 DEBUG=10 INFO=20 WARN=30 ERROR=40 CRITICAL=50
    dut._log.setLevel(log_level)

    # Hack/Fix for missing "negedge reset" in verilator
    dut.spi_select_in.value = 0
    dut.reset_n_in.value = 1
    await Timer(1, 'ps')

    # Transactor
    t = SpiTransactor(dut)

    # 5 us reset
    cr = cocotb.start_soon(clock_n_reset(None, dut.reset_n_in, t=5))       
    await RisingEdge(dut.reset_n_in)
    await Timer(1, 'us')
    
    # test Command
    await t.spi_command(0x14)
    await t.spi_command(0x20)
    await Timer(5, 'us')

    # test single byte write followed by byte read
    a = 0x7c
    d = [0x8e]
    await t.spi_write(a, d)
    read_bytes = await t.spi_read(a + 128)
    assert [int(i) for i in read_bytes] == d
    await Timer(5, 'us')

    # test 2 byte write followed by 2 byte read
    a = 0x3c
    d = [0xa5, 0xff]
    await t.spi_write(a, d)
    read_bytes = await t.spi_read(a + 128, len(d))
    assert [int(i) for i in read_bytes] == d
    await Timer(5, 'us')

    # test random byte write followed by 2 byte read
    for _ in range(random.randrange(4, 16)):
        a = random.randrange(128)
        d = [random.randrange(256) for _ in range(random.randrange(1, 32))]
        await t.spi_write(a, d)
        read_bytes = await t.spi_read(a + 128, len(d))
        assert [int(i) for i in read_bytes] == d
        await Timer(5, 'us')
