# Stage 14 — Physical characterization of AXI4-Lite banked OS GEMM accelerator

## Goal

Characterize the **Stage 13 `os_gemm_axi_lite_top`**, not the older Stage 11 `os_gemm_banked_top`, using the existing full functional regression (12/12 PASS from user on Oct. 31, 2026). Preserve existing RTL. Run 4x4x4 synthesis first, route the resulting checkpoint, then compare with Stage 12.

## Tools and parameters

- AMD Vivado 2025.2 (Windows), ZedBoard `xc7z020clg484-1`.
- Config: ROWS=M=4, reduction K=4, COLS=N=4, signed 16-bit operands, 32-bit accumulation.
- 100 MHz (`10.000 ns`) AXI clock for **OOC internal-only** exploration.
- Top: `os_gemm_axi_lite_top` with one shared `s_axi_aclk` and active-low `s_axi_aresetn`.

## Windows PowerShell

Install this package by extracting at repository root. Then run:

```powershell
$vivado = 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/synth/synth_stage14_axi_ooc.tcl -tclargs 4 4 4
& $vivado -mode batch -source scripts/implementation/route_stage14_axi_ooc.tcl -tclargs 4 4 4
```

Review:

```powershell
$dir = 'reports/stage14/axi_os_4x4x4'
Select-String -Path "$dir/utilization_route.rpt" -Pattern 'Slice LUTs|Slice Registers|DSPs|RAMB'
Select-String -Path "$dir/timing_route.rpt" -Pattern 'Design Timing Summary' -Context 0,9
Get-Content "$dir/primitives_route.txt" | Select-Object -First 22
Get-Content "$dir/worst5_setup_route.rpt" | Select-Object -First 85
Get-Content "$dir/route_status.rpt"
Get-Content "$dir/check_timing_route.rpt" | Select-Object -First 28
```

## Baseline measured from Stage 12 4x4x4

|Metric|Stage 12 post-route|
|---|---:|
|Slice LUTs|155|
|Slice registers|546|
|DSP48E1|16|
|RAM32M|24|
|Block RAM|0|
|WNS|+2.606 ns|
|WHS|+0.110 ns|
|Routable nets|724 of 724, 0 errors|

Post-route AXI-specific results are **pending**. These Stage 12 data omit the AXI4-Lite register fabric, response FSM, result readback mux, address decode and data-staging paths.

## Critical constraints and interpretations

- The 10ns clock is present in the OOC checkpoint; **external AXI interface input/output delays are not modeled**. Reports may flag `no_input_delay` and `no_output_delay` on ports. This is expected OOC incompleteness, not full-system signoff.
- `check_timing` should report 0 `no_clock` and 0 `unconstrained_internal_endpoints`; investigate any nonzero values.
- `AREG/BREG/PREG` data are a netlist mapping observation; do not assume specific RTL register absorption without netlist trace.
- The next physical critical path may involve AXI address decoder, result mux, or banked-memory address logic. **Don't infer the critical path before reading the routed report.**
- Do not call Stage 13 AXI protocol-certified: its own self-checking regression is not exhaustive. Full AXI verification is still required (stall/ordering/error/reset/collision scenarios and external protocol checker/AXI VIP).
- Use the same standalone-clock OOC context for rough comparison, but integration into a full PS/PL block design (with proper clocks, interconnect and constraints) will change timing and resource totals.
- 16 PE DSPs and 24 RAM32Ms are Stage 12 results, not promised Stage 14 results. Measure them.

## Follow-up gate before PS/PL integration

1. Review full implementation: timing summary, worst setup/hold paths, DRC, route status and clock/constraint coverage.
2. Inspect AXI ready/valid protocol behavior under randomized independent channel stalls and reset. In particular test writes issued while start is pending; review unhandled SLVERR conditions.
3. Review memory map capacity (`A_STAGE`/`B_STAGE` fixed 16 entries, `RESULT` results row-major), AXI base address assignment, clocking and reset conventions.
4. Package IP using the 2025.2 IP Packager or bring the RTL in as a module reference, then make a Zynq PS7 -> AXI interconnect -> custom IP block design. Those steps are **not** included in this OOC synthesis/implementation package.

## References

AMD Vivado 2025.2 Creating and Packaging Custom IP, UG1119: https://docs.amd.com/r/2025.2-English/ug1119-vivado-creating-packaging-ip-tutorial

AMD Vivado Synthesis UG901: https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Running-Synthesis-with-Tcl
