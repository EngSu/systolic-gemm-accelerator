# Systolic Array Specification

## Overview

The array computes `C = A x B` for signed `DATA_WIDTH` operands with `ACC_WIDTH` accumulators that wrap modulo 2^`ACC_WIDTH`.

| Module | File | Dataflow | Status |
|---|---|---|---|
| `os_array_param` | `rtl/array/os/os_array_param.v` | Output-stationary, ROWS x COLS | Shipped (inside `os_gemm_banked_top`) |
| `systolic_array_os_2x2` | `rtl/array/os/systolic_array_os_2x2.v` | Output-stationary, fixed 2x2 | Legacy reference |
| `ws_array_param` | `rtl/array/ws/ws_array_param.v` | Weight-stationary, K_STAGES x COLS | Comparison design |
| `ws_array_2x2`, `ws_chain_2` | `rtl/array/ws/` | Weight-stationary, fixed size | Legacy reference |

## Output-stationary array (`os_array_param`)

### Parameters

| Parameter | Default | Description |
|---|---|---|
| `DATA_WIDTH` | 16 | Signed operand width |
| `ACC_WIDTH` | 32 | Accumulator width |
| `ROWS` | 2 | Rows of C (M) |
| `COLS` | 2 | Columns of C (N) |

K is not a parameter of the array. It is how many valid beats the controller sends.

### Ports

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock, active-low reset |
| `clear_acc` | in | 1 | Clear every accumulator |
| `a_left_flat` | in | `ROWS*DATA_WIDTH` | One A value per row, row r at bits `[r*DATA_WIDTH +: DATA_WIDTH]` |
| `a_valid_left` | in | `ROWS` | Valid bit per row |
| `b_top_flat` | in | `COLS*DATA_WIDTH` | One B value per column, column c at bits `[c*DATA_WIDTH +: DATA_WIDTH]` |
| `b_valid_top` | in | `COLS` | Valid bit per column |
| `c_flat` | out | `ROWS*COLS*ACC_WIDTH` | Accumulators, row-major: C[r][c] at `[(r*COLS+c)*ACC_WIDTH +: ACC_WIDTH]` |

### Structure

- A ROWS x COLS grid of `pe_os` cells.
- A moves east one cell per clock through the PE's `a_out`. B moves south one cell per clock through `b_out`.
- Each cell has its own `a_valid` and `b_valid` registers, which move with the operands.
- Cell (r,c) accumulates only when both its A valid and its B valid are high.

### Functional requirements

FR-1: Cell (r,c) shall hold C[r][c] in its accumulator.

FR-2: The array shall not skew inputs. The caller shall present A[r][k] on row r at clock `k + r` and B[k][c] on column c at clock `k + c`, measured from the first beat.

FR-3: With that skew, A[r][k] and B[k][c] shall meet at cell (r,c) on clock `k + r + c`.

FR-4: The last product reaches cell (ROWS-1, COLS-1) after `K + ROWS + COLS - 2` clock edges from the first beat. For 4x4x4 this is 10.

FR-5: `clear_acc` shall zero every accumulator before a new product is computed.

### Who supplies the skew

| Controller | File | Use |
|---|---|---|
| `os_input_scheduler` | `rtl/control/os_input_scheduler.v` | Test only: takes whole matrices on buses, zero memory latency |
| `os_mem_prefetch_ctrl` | `rtl/control/os_mem_prefetch_ctrl.v` | Shipped: reads synchronous memory banks one edge ahead |

### Resource note

With the synchronous-reset PE, each cell's multiply and accumulate map to one DSP48E1, using the P register. The 4x4x4 configuration uses 16 DSP48E1 (Vivado 2025.2, out of context). See the README results table.

## Weight-stationary array (`ws_array_param`)

### Parameters

`DATA_WIDTH` (16), `ACC_WIDTH` (32), `K_STAGES` (2, the reduction depth K) and `COLS` (2).

### Ports

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock, active-low reset |
| `load_weights` | in | 1 | Load all weights at once |
| `weights_flat` | in | `K_STAGES*COLS*DATA_WIDTH` | Weight (k,c) at offset `(k*COLS + c)*DATA_WIDTH` |
| `activation_flat` | in | `K_STAGES*DATA_WIDTH` | One activation per stage, shared by all columns |
| `activation_valid` | in | `K_STAGES` | Valid per stage |
| `result_flat` | out | `COLS*ACC_WIDTH` | One result per column |
| `result_valid` | out | `COLS` | Valid per column |

### Behaviour

Partial sums ripple down the K stages of each column. The caller supplies the activation skew. This array is a comparison design and is not connected to the memory or AXI path.

## Verification

| Testbench | Design |
|---|---|
| `tb/array/os/os_array_param_tb.v` | `os_array_param` |
| `tb/array/os/systolic_array_os_2x2_tb.v` | `systolic_array_os_2x2` |
| `tb/array/ws/ws_array_param_tb.v` | `ws_array_param` |
| `tb/array/ws/ws_array_2x2_tb.v`, `ws_chain_2_tb.v` | Fixed-size WS designs |

The Python regressions `run_param_gemm_regression.py` (async PE) and `run_param_gemm_regression_os_sync.py` (sync PE) compare both arrays with `gemm_reference.py` on 2x2x2, 3x3x3, 4x4x4 and 2x4x3 shapes.
