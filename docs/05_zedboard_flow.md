# ZedBoard Flow

**Status: planned. None of the steps below has been run on the board yet.** This page is the procedure to follow, and it will be updated with real results as each step is done.

## Starting point

- Shipped RTL: `os_gemm_axi_lite_top` (AXI4-Lite slave) and everything under it, built with `rtl/pe/experimental/pe_os_sync.v`.
- Verified so far: simulation against the Python model, and out-of-context synthesis and routing at a 10 ns clock with unconstrained I/O.
- Not yet verified: full-system timing with the PS clock, and any run on hardware.

## Target

| Item | Value |
|---|---|
| Board | ZedBoard |
| Device | XC7Z020-CLG484-1 |
| Tools | Vivado 2025.2, Vitis 2025.2 |
| Processor | Cortex-A9, standalone (bare metal) |
| PS to PL link | M_AXI_GP0, AXI4-Lite |

## Steps

### 1. PS-only Hello World

Build a block design with only the Zynq PS, export the hardware, and print over UART from a Vitis standalone application. This proves the board, cable, boot mode and toolchain before any PL logic is involved.

Done when: the UART terminal shows the message.

### 2. Package the accelerator as IP

Package `os_gemm_axi_lite_top` with its AXI4-Lite interface inferred. Set ROWS, COLS and K to 4, 4 and 4 for the first build.

Done when: the IP appears in the IP catalog and its interface shows as one AXI4-Lite slave.

### 3. Block design

- Zynq PS with M_AXI_GP0 enabled and FCLK_CLK0 as the PL clock.
- AXI interconnect (or SmartConnect) from M_AXI_GP0 to the accelerator.
- Processor System Reset driving the accelerator's active-low reset.
- Assign an address and record the base address in the C header.

Start at a conservative FCLK_CLK0 and raise it only after full-system timing passes. The OOC result at 10 ns is not a guarantee for the system build.

Done when: validation passes, implementation meets timing with no failing paths, and the bitstream is written.

### 4. Bare-metal test

Follow the register map in `docs/design/stage13_axi4lite.md`:

1. Write COMMAND = 2 (LOAD_BEGIN).
2. For each k: write LOAD_INDEX, the A_STAGE and B_STAGE words, then COMMAND = 4 (COMMIT). For 4x4x4 this is 41 writes in total.
3. Poll STATUS until START_READY is set, then write COMMAND = 1 (START).
4. Poll STATUS until DONE_STICKY is set.
5. Read the 16 RESULT words and compare with a C reference using the same 32-bit wrap.
6. Repeat with signed and overflow cases, and report pass or fail per case over UART.

Done when: every case matches the reference on the board.

### 5. Record results

Save the UART log, utilization and timing reports of the system build, and the FCLK frequency used, under `reports/`. Measure load, compute and readback time separately with the A9 global timer.

## Risks to check

| Risk | Check |
|---|---|
| Wrong base address | Read STATUS first and compare with its reset value |
| Reset polarity or missing reset | Accelerator must report LOAD_READY after reset |
| SLVERR from illegal access | Read the AXI response in the debugger if a write appears to be ignored |
| Timing at the chosen FCLK | Full implementation timing report, not the OOC one |
