# Stage 11 — Banked synchronous-read operands for output-stationary GEMM

**Target:** Xilinx Zynq-7020 (ZedBoard); Verilog RTL; Icarus simulation; Vivado 2025.2.

**Status:** New Stage 11 implementation supplied for local test; it is NOT yet
verified in Vivado or Icarus. Earlier Stages 8–10 were verified on the user's
Windows machine. This document does not imply Stage 11 has passed.

## Why this is a separate experiment

Stage 10's scheduler selected operands from entire flattened A/B matrix buses.
It was functionally correct, but selection was combinational and did not model
synchronous RAM latency or an actual loading protocol. Stage 11 replaces those
matrix buses with addressable memory banks and explicit prefetch timing.

## Physical/logical organization

For `C[M,N] = A[M,K] x B[K,N]`:

- `M` independent A banks; each stores `K` `DATA_WIDTH`-bit words. A bank `r`
  contains `A[r][0..K-1]`.
- `N` independent B banks; each stores `K` `DATA_WIDTH`-bit words. B bank `c`
  contains `B[0..K-1][c]`.
- One synchronous-read / synchronous-write port per bank. A and B can have
  individual read addresses per bank on each edge.
- The loader uses a common `wr_addr=k` and separate packed write data buses
  (`M*DATA_WIDTH` for A, `N*DATA_WIDTH` for B). With both enables asserted, one
  column across A's row banks and one row across B's column banks load per edge.
  Thus, **K loading edges**, given this wide loader interface.
- The systolic array remains `M*N` output-stationary PEs.

This loader is a functional interface, not a bandwidth claim about Zynq AXI.
There is no AXI, PS DDR, DMA, or clock-domain crossing in Stage 11.

## Schedule and latency

Define processing edges `t = 0 ... K+M+N-3` (total count `K+M+N-2`).

- A request for row `r` at time `t` selects address `t-r` when `0 <= t-r < K`.
- B request for column `c` at time `t` selects address `t-c` when `0 <= t-c < K`.
- During the **CLEAR** edge, request operands for E0 and clear PE accumulators.
- During processing edge E(t), the array uses operands from the *previous*
  synchronous RAM read, while the memory reads data for E(t+1).
- After the last RUN edge, `done` is high for one clock cycle and the full C
  matrix is valid. A fresh `start` is accepted only after the DONE cycle.

### 2x2x2 worked example

A = `[[1,2],[3,4]]`; B = `[[5,6],[7,8]]`.

| Rising edge | Bank read request | Data consumed by PE array | Selected partial C |
|---|---|---|---|
| CLEAR | E0: A row0=1, B col0=5 | Clear all accumulators | `[[0,0],[0,0]]` |
| E0 | E1: A row0=2,row1=3; B col0=7,col1=6 | A row0=1; B col0=5 | `[[5,0],[0,0]]` |
| E1 | E2: A row1=4; B col1=8 | E1 operands | `[[19,6],[15,0]]` |
| E2 | E3: no external operands needed | E2 operands | `[[19,22],[43,18]]` |
| E3 | No further reads | E3 operands already inside array | `[[19,22],[43,50]]` |
| DONE | No read | Hold C | `done=1` (pulse) |

The valid bits are registered alongside each RAM's read data. **Read data may
be stale or unknown when its corresponding valid bit is 0.** Never use an
invalid bank output as a meaningful operand. The PE array gates accumulation
on aligned valid signals.

## Load and restart contract

1. When idle (`load_ready=1`), pulse `load_begin` for one edge. This clears
   *metadata* marking which addresses have been written, not RAM contents.
2. For k=0..K-1, while still idle: set `wr_addr=k`, present A values for every
   row and B values for every column, and assert `a_wr_en` and `b_wr_en`.
3. After all K addresses have been written to both bank sets, `start_ready=1`.
4. Deassert both write enables, assert `start` for one clock edge.
5. Wait for the one-cycle `done` pulse; C is valid during DONE.
6. To load a different workload, pulse `load_begin` *after* the DONE cycle and
   reload every address before the next start.

If the user asserts `start` before `start_ready`, it is ignored. Writes are
blocked while computing. `load_begin` has precedence over writes in IDLE.

The model assumes all data and control signals are synchronous to the same
clock and valid before the sampling edge. No `ready/valid` backpressure on the
loader beyond `load_ready` has been implemented.

## RAM inference and constraints

The RAM array is *not reset*; its read data is clocked and also not reset.
This is compatible with inference-oriented styles, but **small K depths may map
into distributed RAM or flip-flops rather than block RAM**. Inspect
`reports/stage11/.../memory_dsp_cells.txt` after synthesis before claiming BRAM.

The standalone testbench is not a complete AXI or real ZedBoard integration.
OOC timing checks have not characterized the external data/control ports nor
real PS/PL clock-source skew. These must be addressed in the later top-level
constraints, placed/routed integration, and real hardware tests.

## Module ownership

| File | Responsibility |
| --- | --- |
| `rtl/memory/gemm_sync_bank.v` | Synchronous 1-read/1-write memory |
| `rtl/control/os_mem_prefetch_ctrl.v` | Load markers, FSM, addresses, registered valids |
| `rtl/top/os_gemm_banked_top.v` | Per-row/per-column banks and OS array connection |
| `tb/integration/os_banked_gemm_tb.v` | Per-edge self-checking 3-case regression |
| `scripts/sim/run_stage11_banked_memory.ps1` | Runs 4 GEMM dimension sets |
| `scripts/synth/synth_stage11_banked_ooc.tcl` | Optional Vivado synthesis-only evaluation |

## Completion criteria

- Simulation passes positive/mixed-signed/high-magnitude workloads for
  2x2x2, 3x3x3, 4x4x4 and 2x4x3.
- Two subsequent matrix sets run without a global reset (clear is controlled).
- Each input bank returns the correct word on the intended processing edge.
- Read-valid flags align with every returned RAM value.
- Partial sums and complete results match the software mathematical model.
- No attempt is made to read before full loading.
- Vivado inference is inspected, rather than assuming a particular RAM primitive.

**References:** AMD UG901 memory inference examples and UG949 inferred-memory
register/reset guidelines:
- https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Memory-Inference-Capabilities
- https://docs.amd.com/r/en-US/ug901-vivado-synthesis/Simple-Dual-Port-Block-RAM-Examples
- https://docs.amd.com/r/en-US/ug949-vivado-design-methodology/Scenarios-Preventing-Block-RAM-Output-Register-Inference
