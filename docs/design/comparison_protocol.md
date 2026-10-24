# OS/WS comparison protocol

## Fixed workload

Define A[M×K], B[K×N], C=A×B. Test signed operands, zero values, alternating signs, nonsquare shapes and dimensions not divisible by physical tile dimensions. Include a fixed seed for pseudo-random test vectors.

## Experimental controls

| Variable | Control |
|---|---|
| Operand precision | Same signed input width and numerical interpretation |
| Accumulation | Same output width, overflow/rounding contract |
| Operation | Same matrix shapes and operand values |
| Target | Same FPGA part, tool versions and speed grade |
| Timing | Same clock and I/O constraints |
| Resource budget | Report matched array dimensions or matched DSP budget, not silently different designs |
| Pipelines | Report clock-cycle latency and max clock frequency separately |
| Data transfers | Report compute-only and inclusive-of-transfer results |

## Metrics

- Functional correctness against software reference.
- `cycles_compute`: first accepted operand to last computational result, specifying the interval convention.
- `cycles_total`: includes weights/preload, input staging, drain and output collection.
- `latency_ns = cycles / achieved_clock_hz * 1e9` only when a clock frequency has been established.
- Steady-state throughput for repeated matrix jobs in results/s and useful MAC/s.
- Utilization: useful MACs / (PE_count × active_cycles), with precisely defined active interval.
- LUT, FF, DSP, BRAM, Fmax, worst negative slack, dynamic power estimate (if available).

## Architectural fairness

OS and WS do not need identical internal control schemes, but the same external matrix job must be executed. Note whether weight preloads are amortized over one or many matrix multiplications. Document memory configuration and buffering; do not compare compute core of one against full subsystem of the other.

## Expected reports

`reports/os/`, `reports/ws/`, `reports/comparison/`. No benchmark numbers should be written until they are measured.
