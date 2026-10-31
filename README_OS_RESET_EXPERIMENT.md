# OS accumulator reset experiment

This is an isolated experiment; it **does not modify** the baseline `rtl/pe/pe_os.v`.

## What changes

Only the accumulator process uses `always @(posedge clk)` instead of `always @(posedge clk or negedge rst_n)`. The forwarding registers stay asynchronously reset. The experimental file deliberately uses the same module name `pe_os`; supply **only one** of the two definitions in any Vivado or Icarus compilation.

## Tests: from the Windows repository root in PowerShell

```powershell
New-Item -ItemType Directory -Force build\experiments | Out-Null
iverilog -g2012 -s pe_os_reset_characterization_tb -o build/experiments/baseline_reset.vvp rtl/pe/pe_os.v tb/pe_tb/pe_os_reset_characterization_tb.v
if ($LASTEXITCODE -ne 0) { throw "Baseline compile failed" }
vvp build/experiments/baseline_reset.vvp
if ($LASTEXITCODE -ne 0) { throw "Baseline test failed" }
iverilog -g2012 -DEXPECT_SYNC_ACC_RESET -s pe_os_reset_characterization_tb -o build/experiments/sync_reset.vvp rtl/pe/experimental/pe_os_sync.v tb/pe_tb/pe_os_reset_characterization_tb.v
if ($LASTEXITCODE -ne 0) { throw "Experiment compile failed" }
vvp build/experiments/sync_reset.vvp
if ($LASTEXITCODE -ne 0) { throw "Experiment test failed" }
```

Verify regular 2x2 matrix results (reuse the original combined testbench, but compile the experimental PE instead of the baseline):

```powershell
iverilog -g2012 -s gemm_latency_2x2_tb -o build/experiments/os_sync_gemm.vvp rtl/pe/experimental/pe_os_sync.v rtl/pe/pe_ws.v rtl/array/os/os_array_param.v rtl/array/ws/ws_array_param.v tb/comparison/gemm_latency_2x2_tb.v
if ($LASTEXITCODE -ne 0) { throw "GEMM compile failed" }
vvp build/experiments/os_sync_gemm.vvp
if ($LASTEXITCODE -ne 0) { throw "GEMM test failed" }
```

## Synthesis and routing

```powershell
$vivado = 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/synth/synth_os_sync_ooc.tcl
```

Check `reports/experiments/os_sync_2x2/dsp_pipeline_route.txt`, `utilization_route.rpt`, and `timing_route.rpt` against the baseline.

This experiment **changes reset semantics**. Passing the functional GEMM tests does not mean the design is a drop-in replacement. Synthesis/implementation results are not known until the user runs Vivado.
