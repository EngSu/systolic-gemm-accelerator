# Stage 13 — Zynq-oriented AXI4-Lite control and result access

## Purpose and boundary

This stage adds a memory-mapped control interface **without changing Stage 11's
banked memory, prefetch controller, or optimized output-stationary systolic
array**. The new top module is `os_gemm_axi_lite_top`.

It uses the five AXI4-Lite channels (AW, W, B, AR, R), a shared clock
`s_axi_aclk`, and active-low reset `s_axi_aresetn`. The design accepts one
outstanding write and one outstanding read. The write address and write data
channels are buffered *independently* and can arrive in either order.

This is an **experimental, simulation-first custom AXI slave**, not yet proven
on the ZedBoard or audited against the full AMBA AXI specification. Do not claim
PS/PL integration, AXI protocol certification, throughput, or physical timing
closure until verified separately.

## Supported parameters

- `ROWS` / `COLS`: 1..16 (stage-register windows reserve 16 addresses each).
- `K`: 1..255 (8-bit displayed in CONFIG).
- Data width: **16-bit signed**, accumulation width: **32-bit signed**.
- AXI data width: **32 bits**; AXI byte address width default: 12 bits.
- **Full-word writes only:** `WSTRB=4'b1111`. All other write strobes
  return `SLVERR` without side effects. This is an intentional limitation.
- All AXI and accelerator signals use the **same clock** in this stage.
- Little-endian memory-mapped 32-bit words. Register offsets are relative
  to the AXI peripheral base address assigned in the Zynq address map.

## Register map

| Offset | Name | R/W | Meaning |
|---|---|---|---|
| 0x000 | COMMAND | W | Exact write value `1`=START, `2`=LOAD_BEGIN, `4`=COMMIT, `0`=NOP. Commands must be independent transactions. |
| 0x004 | STATUS | R | bit0 LOAD_READY, bit1 START_READY, bit2 BUSY, bit3 DONE_STICKY, bit4 DONE_PULSE, bit5 STAGING_COMPLETE. Remaining bits zero. |
| 0x008 | LOAD_INDEX | R/W | Reduction index `q` (0..K-1) used at the next COMMIT. |
| 0x00C | CONFIG | R | bits [7:0] ROWS, [15:8] COLS, [23:16] K. |
| 0x100 + 4*r | A_STAGE[r] | R/W | Signed 16-bit `A[r][q]` in low 16 bits; upper 16 ignored on write, sign-extended on read. r=0..ROWS-1. |
| 0x140 + 4*c | B_STAGE[c] | R/W | Signed 16-bit `B[q][c]` in low 16 bits. c=0..COLS-1. |
| 0x200 + 4*(r*COLS+c) | RESULT[r,c] | R | Signed 32-bit `C[r][c]` in row-major order; reads before DONE_STICKY are rejected. |

Invalid addresses, misaligned accesses, unsupported write strobes, invalid
commands, premature START, incomplete COMMIT, and out-of-range LOAD_INDEX
return `2'b10` (AXI `SLVERR`). Successful accesses return `2'b00` (`OKAY`).

## Matrix loading/compute protocol

1. Reset AXI and accelerator using `s_axi_aresetn`.
2. Write `COMMAND=2` to begin a new matrix load; it invalidates old loaded
   markers and clears DONE_STICKY but **does not erase SRAM contents**.
3. For each reduction index `q=0..K-1`:
   - Write `LOAD_INDEX=q`.
   - Write all A_STAGE[r] = A[r,q] for `r=0..ROWS-1`.
   - Write all B_STAGE[c] = B[q,c] for `c=0..COLS-1`.
   - Check STATUS.bit5=1 (optional but useful for debugging).
   - Write `COMMAND=4` (COMMIT). Both bank sets are written on a shared clock.
   - COMMIT clears the per-stage write-valid masks; all stage words must be
     refreshed for the next reduction index. A premature COMMIT returns SLVERR.
4. Check STATUS.bit1=1 (START_READY) after all q values are committed.
5. Write `COMMAND=1` (START). The controller performs CLEAR, RUN and DONE.
6. Poll STATUS.bit3 (DONE_STICKY), **not** the one-cycle bit4 pulse.
7. Read `ROWS*COLS` result words from the RESULT window.
8. For a new operation, repeat beginning with COMMAND=2.

NOTE: This is a deliberately low-bandwidth CPU-register loading approach. A
4x4x4 workload requires 32 individual A/B staging writes, 4 index writes,
4 commit writes, and control accesses. It is suitable as a functional first
AXI integration, not an optimal high-throughput GEMM data path. AXI4-Stream +
DMA or addressable shared RAM is a future optimization after correctness.

## Simulation test scope

The Stage 13 testbench attempts:

- Concurrent AW and W, AW-first, and W-first acceptance.
- BVALID and RVALID stability with two clock cycles of backpressure.
- Invalid command/address/strobe/index/early-result handling.
- Incomplete row/column staging rejection.
- Three operations without global reset: positive, mixed signed, large signed.
- End-to-end readback of every C entry against a separate testbench model.
- Sticky completion read after DONE_PULSE has deasserted.
- Four sizes: 2x2x2, 3x3x3, 4x4x4, 2x4x3.

**Status**: RTL and testbench drafted; user must run `run_stage13_axi4lite.ps1`.
No PASS claim is made until the local regression output is reviewed.

## Future verification and integration gates

- Exercise arbitrary AXI master backpressure and simultaneous read/write
  channel activity, including multi-cycle valid holds.
- Validate APB/AXI integration with an external AXI verification component,
  and review the logic against the AXI4-Lite channel ordering requirements.
- Define reset sequencing, PS clock generation, CDC policy, memory ordering,
  interrupts if needed, and real Zynq address-space allocation.
- Check synthesis mapping, post-route timing, and full-system I/O constraints.
- Implement a C driver using MMIO helpers rather than unguarded pointer casts;
  account for barriers and cacheability where applicable.

## Authoritative references

AMD, *Vivado Design Suite AXI Reference Guide* (UG1037):
https://www.amd.com/content/dam/xilinx/support/documents/ip_documentation/axi_ref_guide/latest/ug1037-vivado-axi-reference-guide.pdf

AMD, *AMBA AXI4 Interface Protocol*:
https://www.amd.com/en/products/adaptive-socs-and-fpgas/intellectual-property/axi.html
