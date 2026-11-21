# Systolic GEMM Accelerator

A Verilog FPGA accelerator project exploring output-stationary (OS) and weight-stationary (WS) systolic architectures for General Matrix Multiplication (GEMM), targeting the ZedBoard (Zynq-7000 XC7Z020).

The project progresses from a single multiply-accumulate unit to parameterized systolic arrays, banked operand memories, a prefetch controller, and an AXI4-Lite register interface. It is verified in simulation against a Python reference model and characterized with out-of-context Vivado synthesis and routing.

**Status:** simulation-verified and routed out of context. **Not yet run on hardware.** See [What is and is not demonstrated](#what-is-and-is-not-demonstrated).

## Objectives

- Design reusable, parameterized Verilog RTL modules.
- Implement OS and WS dataflows and compare them fairly.
- Verify RTL automatically against Python fixed-width reference models.
- Evaluate FPGA resource use and timing, and explain what drives them.
- Integrate the accelerator with the Zynq processing system over AXI.

## Dataflows

GEMM computes `C = A x B`, with `A` of size M x K, `B` of size K x N and `C` of size M x N.

- **Output-stationary (OS):** each processing element keeps its own output partial sum while A and B operands move across the array. Local accumulation avoids moving partial sums.
- **Weight-stationary (WS):** each processing element holds a weight and reuses it while activations and partial sums move through. Weight reuse reduces repeated weight delivery.

Both were built and verified independently so they can be compared. The OS design is the one wired to memory and AXI.

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

### Per-module directed tests

| Design | Directed tests |
|---|---|
| MAC | 3 |
| Initial PE | 3 |
| OS PE | 8 |
| WS PE | 11 |
| Two-stage WS chain | 9 |
| 2x2 WS GEMM array | 10 |
| 2x2 OS GEMM array | 11 |
| 2x2 OS/WS RTL co-simulation | 31 matrix cases, 0 failures |

These counts are carried over from the earlier README and were not re-run for this edit.

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

Requirements: Icarus Verilog, Python 3, and Vivado 2025.2 for synthesis. Run commands from the repository root.

### Python and Icarus (macOS, Linux, Windows)

```bash
python3 -m verification.reference_models.gemm_reference
python3 -m unittest discover -s verification/regressions -p 'test_*.py' -v
python3 -m verification.regressions.run_gemm_cosim
python3 verification/regressions/run_param_gemm_regression_os_sync.py

# Parameterized OS array, 2x2
iverilog -g2012 -s os_array_param_tb -o /tmp/os_param_2x2.vvp \
  rtl/pe/pe_os.v rtl/array/os/os_array_param.v tb/array/os/os_array_param_tb.v
vvp /tmp/os_param_2x2.vvp
```

### Integration regressions and Vivado (Windows PowerShell)

These scripts were written on Windows. The Vivado path below is the author's install location.

```powershell
.\scripts\sim\run_os_scheduler_scaling.ps1
.\scripts\sim\run_stage11_banked_memory.ps1
.\scripts\sim\run_stage13_axi4lite.ps1

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

## Development approach

Architecture specification, RTL, directed verification, automated regression, parameterization, FPGA evaluation, then SoC integration. Design decisions and experiments are documented in `docs/`, `reports/` and the `diary/` journal. Further reading: [`docs/architecture/references.md`](docs/architecture/references.md).

This is an engineering and learning project, not a production accelerator.
