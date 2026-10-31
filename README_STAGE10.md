# Stage 10: Parameterized scheduler + optimized OS array integration regression

This package adds a **new** testbench and PowerShell runner to your existing
Stage 9 integration. It does not modify your RTL or the Stage 9 testbench.

## Installation

From your repository root in PowerShell:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\stage10_integrated_regression.zip" -DestinationPath .
```

## Run

```powershell
& .\scripts\sim\run_os_scheduler_scaling.ps1
```

If PowerShell execution policy prevents scripts, run without changing policy
for the current Windows user:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sim\run_os_scheduler_scaling.ps1
```

You need `iverilog` and `vvp` accessible on PATH.

## Coverage

M x K x N dimensions: 2x2x2, 3x3x3, 4x4x4, and 2x4x3.
Three cases per dimension: positive values, mixed signs, and maximum-positive
16-bit inputs to exercise 32-bit signed accumulation overflow/wrap.
Checks: operand streams, valid bits, clearing, busy/done transition,
one-cycle done, and each output PE's cumulative sum after each processing edge.
Each workload is started independently without resetting the design between
cases. Both the controller and the array are simulated together.

**Not covered yet:** reset in the middle of a transaction, start while busy,
clock-domain crossing, BRAM access latency, AXI, physical Zynq integration.

## Important

This is an Icarus Verilog simulation testbench and has NOT been executed in the
assistant runtime. The test must be run on your Windows machine. The expected
success marker is `ALL INTEGRATED OS SCALING RUNS COMPLETED`.
