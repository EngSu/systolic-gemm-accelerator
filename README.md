# Systolic GEMM Accelerator

A parameterized, signed-integer **output-stationary (OS) systolic GEMM accelerator** in Verilog for the ZedBoard (Zynq-7000 XC7Z020), with a weight-stationary (WS) array kept as a comparison baseline. The design is verified in simulation against a Python reference model, characterized with out-of-context Vivado synthesis and routing, and wrapped in an AXI4-Lite register interface.

**Status:** simulation-verified and routed out of context. **Not yet run on hardware.** See [What is and is not demonstrated](#what-is-and-is-not-demonstrated).

## Architecture

Computes `C = A × B` for signed 16-bit `A[M,K]` and `B[K,N]`, with 32-bit accumulators that wrap modulo 2^32.

```text
PS / CPU (future)
   │  AXI4-Lite
   ▼
os_gemm_axi_lite_top      COMMAND / STATUS / staging registers / result window
   └─ os_gemm_banked_top
        ├─ gemm_sync_bank × (ROWS + COLS)   one A bank per row, one B bank per column
        ├─ os_mem_prefetch_ctrl             IDLE → CLEAR → RUN → DONE, read prefetch + valid alignment
        └─ os_array_param                   ROWS × COLS output-stationary PEs (pe_os)
```

- **OS array:** each PE owns one `C[r,c]`; A moves right, B moves down. Processing takes `K + ROWS + COLS − 2` edges (10 for 4×4×4), excluding clear, done, and data loading.
- **Banked memory:** synchronous-read banks with one-edge prefetch, so operand and valid signals stay aligned with the array.
- **AXI4-Lite wrapper:** value-encoded COMMAND register (`1` START, `2` LOAD_BEGIN, `4` COMMIT), sticky DONE, SLVERR on illegal accesses. Register map: [`docs/design/stage13_axi4lite.md`](docs/design/stage13_axi4lite.md).

## Results

All implementation numbers are for a **4×4×4** configuration, Vivado 2025.2, XC7Z020-CLG484-1, **out of context with a 10 ns clock**.

### OS vs WS datapath (post-route)

| Variant | Slice LUTs | Slice FFs | DSP48E1 | DSP PREG | WNS (ns) |
|---|---:|---:|---:|---|---:|
| OS, async accumulator reset | 266 | 920 | 16 | 0 (all 16) | +2.991 |
| OS, sync accumulator reset | 18 | 408 | 16 | 1 (all 16) | +4.311 |
| WS | 68 | 265 | 16 | 1 (all 16) | +5.080 |

### Integrated designs (post-route)

| Design | Slice LUTs | Slice FFs | DSP48E1 | RAM32M | WNS (ns) | WHS (ns) |
|---|---:|---:|---:|---:|---:|---:|
| Banked memory + scheduler + array (Stage 12) | 155 | 546 | 16 | 24 | +2.606 | +0.110 |
| + AXI4-Lite wrapper (Stage 14) | 459 | 774 | 16 | 24 | +1.620 | +0.028 |

Both integrated designs routed with zero routing errors.

### Verification (simulation)

| Test | Result |
|---|---|
| Python-vs-RTL, OS and WS, 4 shapes × 2 patterns | 8 / 8 workloads match |
| Scheduler + array integration, 4 shapes × 3 cases | 12 / 12 pass |
| Banked-memory integration, 4 shapes × 3 cases | 12 / 12 pass |
| AXI4-Lite integration, 4 shapes × 3 cases | 12 / 12 pass |
| Python reference-model unit tests | 6 / 6 pass |

Shapes (M×K×N): 2×2×2, 3×3×3, 4×4×4, 2×4×3. Cases: positive, mixed-sign, and maximum-positive values that exercise 32-bit wrap. Simulator: Icarus Verilog.

## Key finding: reset style changes DSP inference

Changing only the OS accumulator from asynchronous to synchronous reset moved the accumulator register from fabric into the DSP48E1 P register (PREG 0 → 1 for all 16 DSPs). Routed LUTs fell from 266 to 18 and FFs from 920 to 408.

**What this does and does not show.** It shows a coding choice can dominate resource counts for identical arithmetic. It does **not** show that OS is a better dataflow than WS, that the two reset styles are interchangeable (the reset contract changed: the accumulator no longer clears before a clock edge), or anything about end-to-end throughput. Details: [`README_OS_RESET_EXPERIMENT.md`](README_OS_RESET_EXPERIMENT.md).

> `rtl/pe/pe_os.v` (async) and `rtl/pe/experimental/pe_os_sync.v` (sync) both define module `pe_os`. Compile **one or the other**, never both.

## What is and is not demonstrated

| Demonstrated | Not demonstrated yet |
|---|---|
| Functional correctness in simulation for the listed shapes and cases | Operation on the ZedBoard |
| Out-of-context routed timing at a 10 ns clock | Full-system timing: I/O delays and PS clock source are unconstrained |
| DSP and memory inference reports | Maximum clock frequency (WNS is not Fmax) |
| AXI4-Lite register protocol in simulation | AXI protocol compliance, DMA, or throughput |
| | Power, or end-to-end latency including data loading |

Loading a 4×4×4 problem through the register interface takes 41 AXI writes before START. This is a deliberately simple first integration, not a high-bandwidth data path. AXI-Stream with DMA is the planned next step if measurements justify it.

## Repository layout

```text
rtl/
  pe/            pe_os.v, pe_ws.v, experimental/pe_os_sync.v
  array/os|ws/   os_array_param.v, ws_array_param.v (+ 2x2 reference versions)
  memory/        gemm_sync_bank.v
  control/       os_mem_prefetch_ctrl.v, os_input_scheduler.v
  top/           os_gemm_banked_top.v
  axi/           os_gemm_axi_lite_top.v
tb/              unit, array, integration, and comparison testbenches
verification/    Python reference model, unit tests, co-simulation regressions
scripts/         sim (PowerShell), synth + implementation (Vivado Tcl)
reports/         curated Vivado reports and regression logs
docs/            specifications and per-stage design notes
fpga/zedboard/   constraints
```

## Reproducing results

Requirements: Icarus Verilog, Python 3, Vivado 2025.2. Commands run from the repository root (Windows PowerShell).

```powershell
# Python
python -m unittest discover -s verification/regressions -p "test_*.py" -v
python verification/regressions/run_param_gemm_regression_os_sync.py

# Icarus regressions
.\scripts\sim\run_os_scheduler_scaling.ps1
.\scripts\sim\run_stage11_banked_memory.ps1
.\scripts\sim\run_stage13_axi4lite.ps1

# Vivado out-of-context synthesis and routing (Stage 14)
$vivado = 'C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/synth/synth_stage14_axi_ooc.tcl -tclargs 4 4 4
& $vivado -mode batch -source scripts/implementation/route_stage14_axi_ooc.tcl -tclargs 4 4 4
```

## Roadmap

1. Run PS-only Hello World on the ZedBoard (Vitis 2025.2, standalone, Cortex-A9).
2. Package `os_gemm_axi_lite_top` as IP and integrate with the Zynq PS (M_AXI_GP0).
3. Bare-metal C test: load, start, poll, read back, compare with a software reference; measure load, compute, and readback time separately.
4. Add randomized tests on the shipped design (parameterized array, banked top, AXI top), plus start-while-busy and mid-transaction reset.
5. Evaluate AXI-Stream/DMA only if step 3 shows data movement dominates.

## References

- AMD UG479, *7 Series DSP48E1 Slice User Guide*
- AMD UG901, *Vivado Synthesis*; UG904, *Vivado Implementation*; UG906, *Design Analysis and Closure Techniques*
- AMD UG1037, *Vivado AXI Reference Guide*
- Google TPU and UC Berkeley Gemmini for systolic-array background

This is an engineering and learning project, not a production accelerator.
