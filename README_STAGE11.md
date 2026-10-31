# Stage 11 — Banked Memory + Synchronous Operand Prefetching

**Status: UNVERIFIED — run on your Windows development machine.**

## Install

Extract this ZIP into the `systolic-gemm-accelerator` repository root.
The archive only adds new files; it does not replace Stage 7–10 files.

## Compile and run all configurations (PowerShell)

    & .\scripts\sim\run_stage11_banked_memory.ps1

Alternative if PowerShell blocks the script:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sim\run_stage11_banked_memory.ps1

## Single 2x2 run

    New-Item -ItemType Directory -Force build/stage11 | Out-Null
    iverilog -g2012 -s os_banked_gemm_tb -o build/stage11/banked_2x2.vvp `
      rtl/memory/gemm_sync_bank.v `
      rtl/control/os_mem_prefetch_ctrl.v `
      rtl/top/os_gemm_banked_top.v `
      rtl/pe/experimental/pe_os_sync.v `
      rtl/array/os/os_array_param.v `
      tb/integration/os_banked_gemm_tb.v
    vvp build/stage11/banked_2x2.vvp

Expected pass text **if the local simulation succeeds**:

    ALL STAGE 11 BANKED MEMORY TESTS PASSED M=2 K=2 N=2 cases=3

For all four configurations, final runner prints:

    ALL STAGE 11 BANKED MEMORY REGRESSIONS COMPLETED

## Optional Vivado inference check, after simulations pass

    & $vivado -mode batch -source scripts/synth/synth_stage11_banked_ooc.tcl -tclargs 4 4 4

Report folder: `reports/stage11/banked_os_4x4x4/`.

Do not include both `rtl/pe/pe_os.v` and
`rtl/pe/experimental/pe_os_sync.v` in the same synthesis/simulation call,
because both define module `pe_os`.

This experiment models synchronous memory reads. It does NOT prove physical
BRAM mapping, AXI bandwidth, complete constraints or on-board correctness.
See `docs/design/stage11_banked_memory.md` for interfaces and edge schedule.
