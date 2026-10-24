# Architecture roadmap

## Purpose

Create a reusable, parameterized Verilog matrix-multiplication accelerator testbed that implements both output-stationary (OS) and weight-stationary (WS) dataflows. Study cycle-level behavior before adding higher-level structure.

## Phase 0 — Preserve and characterize existing RTL

- Keep `rtl/mac/mac.v`, `rtl/pe/pe.v`, and `rtl/pe/pe_os.v` unchanged during restructuring.
- Run and record all current directed testbenches on a named commit.
- Capture current repository tree (`find rtl tb -maxdepth 4 -type f | sort`).
- Add notes specifying interface widths, reset polarity, signedness and accumulation semantics.

## Phase 1 — Reproducible OS and WS baselines

- Finish control/reset/forwarding verification of existing OS PE.
- Verify 2x2 OS array with explicit skew schedule, including independent A/B stream validity.
- Define WS PE with weight loading and a specific registered partial-sum path.
- Define WS array placement and preload/drain schedule.
- Test both against the same independent matrix-multiplication reference.

### Function contracts

`OS`: local accumulator holds `C[i,j]`, operands travel, and each valid paired operand updates the local sum.

`WS`: stored weight remains local across several operations, while activations and partial sums flow according to an explicit schedule. For reductions larger than the physical dimension, define temporal accumulation across passes.

## Phase 2 — Parameterization and matrix tiling

- Separate matrix shape (`M,K,N`) from physical array shape (`ARRAY_ROWS,ARRAY_COLS`).
- Support legal array dimensions beyond 2x2, with meaningful compile-time parameter checks.
- Define overflow/precision policy and sign extension.
- Define tile addresses, partial-tile masks and accumulation across K-tiles.
- Verify corner cases: rectangular and non-multiple-of-array dimensions.

## Phase 3 — Gemmini-inspired hierarchy

- Introduce `Tile` (collection of PEs) and `Mesh` (collection of tiles).
- Choose pipelining boundary explicitly; retime payload, partial sum and valid together.
- Compare fully registered PE-to-PE baseline with tile combinational chains + boundary registers.
- Never add a register to the accumulator feedback path without revisiting recurrence scheduling.

## Phase 4 — TPU-inspired data supply

- Add input/weight staging, preloading, output collection and occupancy counters.
- Keep compute-only and end-to-end performance separate.
- Optional double buffering and overlapping data movement can follow functional validation.

## Phase 5 — FPGA assessment

- Synthesize and implement the same arithmetic workload/configurations on a specified Zynq FPGA.
- Report achieved timing, resources, latency, throughput and bandwidth pressure.
- Avoid declaring a winning dataflow using only 2x2 numerical tests.

## Exit criteria for each phase

A phase is complete only with a checked-in interface specification, cycle-level schedule, automated self-checking tests and a reproducible run command. Timing/performance claims require actual synthesis/implementation reports.
