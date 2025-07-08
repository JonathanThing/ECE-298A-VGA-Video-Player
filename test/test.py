# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 40, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.uo_out.value = 0
    dut.uio_out.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    dut._log.info("Awaiting CS Low")
    while dut.uio_out.value & (1 << 2) != 0:
        await ClockCycles(dut.clk, 1)

    instruction = 0x6b
    dut._log.info("Sending QSPI Instruction")

    for i in range(8):
        dataOutput = dut.uio_out.value & (1 << 3)
        print(f"Bit {i} val: {instruction & (1 << (7 - i))} out: {dataOutput}")

        if (instruction & (1 << (7 - i))): # 1
            assert dataOutput > 0, f"Expected bit {i} to be 1, got {dataOutput}"
        else:  # 0
            assert dataOutput == 0, f"Expected bit {i} to be 0, got {dataOutput}"
        await ClockCycles(dut.clk, 1)

    dut._log.info("Instruction sent successfully, Sending 32 bits of dummy data")

    for i in range(32):
        # Check if hold pin is held high
        outputEnable = dut.uio_oe.value & (1 << 7)
        dataOutput = dut.uio_out.value & (1 << 7)
        assert outputEnable > 0, f"Expected output enable to be high at bit {i}, got {outputEnable}"
        assert dataOutput > 0, f"Expected hold pin to be high at bit {i}, got {dataOutput}"
        await ClockCycles(dut.clk, 1)
        
    outputEnable = dut.uio_oe.value & (1 << 7)  
    # assert outputEnable == 0, f"Expected output enable to be low at end of instruction, got {outputEnable}"

    await ClockCycles(dut.clk, 20)

    assert True