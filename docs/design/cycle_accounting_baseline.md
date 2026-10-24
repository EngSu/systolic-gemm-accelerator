# OS vs WS — baseline cycle-accounting protocol

## Scope
Current parameterized GEMM implementations with signed 16-bit operands, 32-bit accumulators, and input schedules used by `os_array_param_tb.v` and `ws_array_param_tb.v`.

## Counting conventions
- **Processing edge E0**: first positive clock edge with valid matrix operands, following setup.
- **OS setup**: one edge with `clear_acc=1`, assuming the operand pipelines are drained and the next calculation is independently scheduled.
- **WS setup**: one edge with `load_weights=1`, assuming all `K*N` weights are presented simultaneously on `weights_flat`.
- **Processing edges OS**: `K+M+N-2` through the edge at which the final accumulator becomes correct.
- **Processing edges WS**: `M+K-1` through the edge at which the last output row becomes valid.
- **Total modeled edges**: one setup edge plus processing edges.
- **Excluded**: reset, host/memory delivery, handshake stalls, writeback/readout, row buffering, clock period, and software overhead.

## Resource scaling (structural only)
- OS: `M*N` processing elements; `M+N` 16-bit boundary operand lanes per processing edge; `M*N` stationary 32-bit accumulators exposed on `c_flat`.
- WS: `K*N` processing elements; `K` 16-bit activation lanes per processing edge; `K*N` 16-bit weights presented in parallel for the one-cycle preload assumption; `N` 32-bit result lanes each with validity.
- PE counts are not LUT, FF, DSP, BRAM, timing, power or area measurements.

## Mandatory output handling
- OS keeps the whole output tile in local accumulators. A real memory interface or register transfer is needed to export it.
- WS emits rows sequentially. Collect each valid row before it is overwritten; a complete output tile is **not** available concurrently on `result_flat`.

## Benchmark rules
1. Verify identical `A` and `B` with the Python golden model, including signed cases and wrapping behavior.
2. Run the same dimensions and operand widths on both designs.
3. Explicitly log preload/clear, first valid input, first completed output, last completed output, and output collection.
4. Report **compute-only**, **setup+compute**, and later **end-to-end memory+compute+readout** separately.
5. Use the same target FPGA and synthesis constraints. Report DSP, LUT, FF, BRAM, post-implementation Fmax and achieved MAC/s; never infer hardware speed solely from clock counts.
6. Document whether weights are reused across consecutive GEMM calls, which changes the amortized WS preload cost.

## Current baseline
Run `python3 scripts/compare_gemm_cycles.py` to generate `reports/comparison/baseline_cycle_estimates.csv`. This script produces **analytical estimates**, not measured RTL timing.
