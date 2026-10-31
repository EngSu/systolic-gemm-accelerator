# Stage 9 — OS Scheduler + Parameterized Array Integration

## Scope

- Connect an input scheduler to the existing `os_array_param` module.
- Use the experimentally verified synchronous-accumulator-reset `pe_os` implementation.
- Verify two consecutive 2x2 GEMM operations without resetting the entire design between cases.
- Check per-edge operand streams, valid bits, clear timing, complete C matrix and done pulse.

This is a **register-backed/flattened-bus scheduler** for learning and functional
integration. It does not implement BRAM, DMA, AXI or physical memory timing.
Matrix buses must remain stable from `start` through `done`.

## Install

From the Windows PowerShell terminal in the `systolic-gemm-accelerator` root:

    Expand-Archive -LiteralPath "$HOME\Downloads\stage9_scheduler_integration.zip" -DestinationPath .

## Compile

    New-Item -ItemType Directory -Force build\integration | Out-Null

    iverilog -g2012 -s os_scheduler_integration_tb `
      -o build/integration/os_scheduler_integration.vvp `
      rtl/control/os_input_scheduler.v `
      rtl/pe/experimental/pe_os_sync.v `
      rtl/array/os/os_array_param.v `
      tb/integration/os_scheduler_integration_tb.v

## Run

    vvp build/integration/os_scheduler_integration.vvp

Expected *success marker* (not yet run on the user's PC):

    ALL OS SCHEDULER INTEGRATION TESTS PASSED

## Controller behavior

- IDLE: accept `start` (only in IDLE).
- CLEAR: assert `clear_acc` for one clock edge.
- RUN: present one set of skewed operands per edge for `K + ROWS + COLS - 2` edges.
- DONE: assert one-cycle `done` pulse.

For processing edge E(t):
- `A_left[r] = A[r][t-r]` when `0 <= t-r < K`.
- `B_top[c] = B[t-c][c]` when `0 <= t-c < K`.

The final output C is valid after the last RUN rising edge. When DONE is high,
the result is ready to read. Do not assert a new `start` while busy.

## Not tested here

Icarus Verilog and Vivado are unavailable in this assistant runtime. The
files are supplied for the user's local simulation. No PASS is asserted on their behalf.

## Next checks

1. Execute both 2x2 cases.
2. Add 3x3/4x4 and rectangular configurations.
3. Cover mid-operation reset, start-during-busy, and out-of-range cases.
4. Replace flattened matrix muxing with addressable input buffer / BRAM reads.
