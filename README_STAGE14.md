# Stage 14 — AXI4-Lite GEMM: Synthesis and Post-Route Characterization

**Purpose:** Synthesize and route the *full* Stage 13 `os_gemm_axi_lite_top` at 4x4x4. Use Vivado 2025.2 on ZedBoard XC7Z020. No verified RTL is overwritten.

### Install

From PowerShell at the root of the existing repository:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\stage14_axi_physical.zip" -DestinationPath .
```

### Stage 14A — Synthesis

```powershell
$vivado = 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/synth/synth_stage14_axi_ooc.tcl -tclargs 4 4 4
```

Stage 14A writes `reports/stage14/axi_os_4x4x4/synthesized.dcp`, `timing_synth.rpt`, `utilization_synth.rpt`, `check_timing_synth.rpt`, `primitives_synth.txt`.

### Stage 14B — Place and route

Run only if synthesis succeeds:

```powershell
& $vivado -mode batch -source scripts/implementation/route_stage14_axi_ooc.tcl -tclargs 4 4 4
```

Stage 14B writes `routed.dcp`, `utilization_route.rpt`, `timing_route.rpt`, `worst5_setup_route.rpt`, `worst5_hold_route.rpt`, `route_status.rpt`, `check_timing_route.rpt`, `primitives_route.txt`.

### Report extraction

```powershell
$dir = 'reports/stage14/axi_os_4x4x4'
Select-String -Path "$dir/utilization_route.rpt" -Pattern 'Slice LUTs|Slice Registers|DSPs|RAMB'
Select-String -Path "$dir/timing_route.rpt" -Pattern 'Design Timing Summary' -Context 0,9
Get-Content "$dir/worst5_setup_route.rpt" | Select-Object -First 85
Get-Content "$dir/route_status.rpt"
Get-Content "$dir/primitives_route.txt" | Select-Object -First 20
```

**Current status:** 12/12 Stage 13 functional tests confirmed by user. **Stage 14 synthesis and timing are not yet measured.** Full AXI protocol compliance and full PS/PL timing closure remain separate future gates.
