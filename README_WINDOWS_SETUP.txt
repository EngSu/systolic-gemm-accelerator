SYSTOLIC GEMM ACCELERATOR — WINDOWS STARTER FILES

Extract this ZIP from the root of your Windows repository checkout.
It contains new utility files only; it does not contain or replace your RTL.

New files:
  scripts/windows/run_verified_checks.ps1
  scripts/vivado/synth_gemm_ooc_windows.tcl
  fpga/zedboard/constraints/core_100mhz_ooc.xdc

Requirements:
  - Committed repo containing rtl/pe, rtl/array, tb/comparison sources
  - PowerShell, Python 3, Icarus Verilog (iverilog and vvp)
  - Vivado 2025.2 with Zynq-7000 device support

From PowerShell in repository root:
  powershell -ExecutionPolicy Bypass -File scripts/windows/run_verified_checks.ps1

Then with Vivado available on PATH:
  vivado -mode batch -source scripts/vivado/synth_gemm_ooc_windows.tcl -tclargs os 2 2 2
  vivado -mode batch -source scripts/vivado/synth_gemm_ooc_windows.tcl -tclargs ws 2 2 2

Use full path to vivado.bat when it is not on PATH.
More details and limits are in the ChatGPT walkthrough.
This bundle has been source-inspected, but actual Vivado and Windows execution
cannot be performed in the current Linux environment.
