# Processing Element Specification

## Overview

A processing element (PE) is one multiply-accumulate cell of the systolic array. The repository has three PE designs:

| Module | File | Dataflow | Status |
|---|---|---|---|
| `pe` | `rtl/pe/pe.v` | External partial sum | First generation, superseded |
| `pe_os` | `rtl/pe/pe_os.v` | Output-stationary, async accumulator reset | Baseline |
| `pe_os` | `rtl/pe/experimental/pe_os_sync.v` | Output-stationary, sync accumulator reset | Shipped in banked and AXI designs |
| `pe_ws` | `rtl/pe/pe_ws.v` | Weight-stationary | Comparison design |

Both `pe_os` files define the same module name on purpose. Compile exactly one per build. See `docs/design/pe_variants.md`.

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `DATA_WIDTH` | 16 | Signed operand width |
| `ACC_WIDTH` | 32 | Signed accumulator width; must be at least `2*DATA_WIDTH` |

## Output-stationary PE (`pe_os`)

The PE keeps one output element in a local accumulator while A and B pass through.

### Ports

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk` | in | 1 | Clock |
| `rst_n` | in | 1 | Active-low reset |
| `clear_acc` | in | 1 | Zero the accumulator on the next clock edge |
| `valid_in` | in | 1 | Accumulate `a_in * b_in` this cycle |
| `a_in` | in | `DATA_WIDTH` | Signed A operand |
| `b_in` | in | `DATA_WIDTH` | Signed B operand |
| `a_out` | out | `DATA_WIDTH` | `a_in` registered one clock (to the east neighbour) |
| `b_out` | out | `DATA_WIDTH` | `b_in` registered one clock (to the south neighbour) |
| `valid_out` | out | 1 | `valid_in` registered one clock |
| `acc_out` | out | `ACC_WIDTH` | Local accumulator |

### Functional requirements

FR-1: The full-width signed product `a_in * b_in` shall be sign-extended to `ACC_WIDTH`.

FR-2: On a clock edge, the accumulator shall update with this priority: reset, then `clear_acc` (to 0), then `valid_in` (`acc_out + product`). Otherwise it holds.

FR-3: Accumulation shall wrap modulo 2^`ACC_WIDTH`. There is no saturation.

FR-4: `a_out`, `b_out` and `valid_out` shall be `a_in`, `b_in` and `valid_in` delayed by one clock, independent of `clear_acc`.

FR-5: Reset shall clear `a_out`, `b_out`, `valid_out` and `acc_out`.

### Reset variants

| | `pe_os.v` | `pe_os_sync.v` |
|---|---|---|
| Forwarding registers | Asynchronous reset | Asynchronous reset |
| Accumulator | Asynchronous reset | Synchronous reset |
| Accumulator cleared | When `rst_n` falls | On the first clock edge with `rst_n` low |
| DSP48E1 P register used (4x4x4, routed OOC) | No (PREG 0) | Yes (PREG 1) |

Ports and arithmetic are identical. The synchronous version needs at least one clock edge while `rst_n` is low to clear the accumulator.

### Timing

- Latency: operands and valid are forwarded after 1 clock.
- Accumulator: updated 1 clock after a valid cycle.
- Throughput: one multiply-accumulate per clock.

### Use in the array

`os_array_param` drives `valid_in` with `a_valid & b_valid` for that cell and tracks validity with its own registers. It does not use the PE's `valid_out`.

## Weight-stationary PE (`pe_ws`)

The PE holds one weight and adds its product to a partial sum passing through.

### Ports

| Signal | Dir | Width | Description |
|---|---|---|---|
| `clk`, `rst_n` | in | 1 | Clock, active-low reset |
| `load_weight` | in | 1 | Store `weight_in` |
| `weight_in` | in | `DATA_WIDTH` | Weight to store |
| `activation_in` | in | `DATA_WIDTH` | Signed activation |
| `psum_in` | in | `ACC_WIDTH` | Incoming partial sum |
| `valid_in` | in | 1 | Inputs valid this cycle |
| `psum_out` | out | `ACC_WIDTH` | `psum_in + activation_in * weight`, registered |
| `valid_out` | out | 1 | `psum_out` is a new valid result |

### Functional requirements

FR-1: `load_weight` shall store the weight and mark it loaded.

FR-2: Loading has priority: during a load cycle `valid_out` shall be 0.

FR-3: A computation shall happen only when `valid_in` is high and a weight has been loaded.

FR-4: When no computation happens, `psum_out` shall hold and `valid_out` shall be 0.

FR-5: The PE does not forward activations. The array broadcasts them.

## Verification

| Testbench | PE |
|---|---|
| `tb/pe_tb/pe_tb.v` | `pe` |
| `tb/pe_tb/pe_os_tb.v` | `pe_os` |
| `tb/pe_tb/pe_os_reset_characterization_tb.v` | `pe_os` reset behaviour |
| `tb/pe_tb/pe_ws_tb.v` | `pe_ws` |

All are directed tests checked against expected values.
