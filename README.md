# Systolic GEMM Accelerator

**A Verilog-based FPGA accelerator project exploring output-stationary and weight-stationary systolic architectures for General Matrix Multiplication (GEMM).**

This project focuses on designing, verifying, and evaluating reusable hardware building blocks for matrix-multiplication acceleration, progressing from individual multiply-accumulate units to parameterized systolic arrays and FPGA/SoC integration.

The long-term objective is to study architectural trade-offs involving dataflow, parallelism, pipelining, memory organization, resource utilization, latency, and throughput.

## Project Objectives

- Design reusable and parameterized Verilog RTL modules.
- Implement output-stationary (OS) and weight-stationary (WS) dataflows.
- Develop scalable processing-element arrays.
- Build automated RTL verification using Python reference models.
- Explore pipelining, tiling, and memory architectures.
- Evaluate FPGA synthesis, resource utilization, and timing.
- Integrate accelerator hardware with an embedded processor using AXI interfaces.

## Architecture Overview

GEMM computes:

\[
C = A \times B
\]

where:

- \(A\) is an \(M \times K\) matrix.
- \(B\) is a \(K \times N\) matrix.
- \(C\) is an \(M \times N\) output matrix.

The project investigates two hardware dataflows.

### Output-Stationary (OS)

Each processing element retains its output partial sum locally while A and B operands move across the array.

**Key characteristic:** Local accumulation minimizes movement of intermediate output partial sums.

### Weight-Stationary (WS)

Each processing element stores a weight and reuses it while activations and partial sums move through the computation.

**Key characteristic:** Weight reuse reduces repeated weight delivery during a computation.

Both implementations are being developed and verified independently to support meaningful architectural comparisons.

## Repository Structure

```text
systolic-gemm-accelerator/
├── rtl/
│   ├── mac/               # Multiply-accumulate unit
│   ├── pe/                # Processing elements (OS and WS)
│   ├── array/
│   │   ├── os/            # Output-stationary arrays
│   │   └── ws/            # Weight-stationary arrays
│   ├── tile/              # Future tile-level architectures
│   ├── mesh/              # Future mesh-level architectures
│   ├── memory/            # Future memory interfaces
│   └── control/           # Future accelerator control
│
├── tb/
│   ├── mac_tb/
│   ├── pe_tb/
│   ├── array/
│   │   ├── os/
│   │   └── ws/
│   ├── tile/
│   └── mesh/
│
├── verification/
│   ├── reference_models/  # Python golden models
│   ├── regressions/       # Automated verification
│   └── vectors/
│
├── fpga/
│   └── zedboard/          # FPGA projects and constraints
│
├── docs/                  # Specifications and design notes
├── scripts/               # Development utilities
├── reports/               # Future implementation and comparisons
└── diary/                 # Engineering development journal
```

## Implementation Progress

### Completed and Verified

- [x] Signed multiply-accumulate (MAC) unit.
- [x] Initial processing element with external partial-sum input.
- [x] Output-stationary processing element.
- [x] Weight-stationary processing element.
- [x] Two-stage weight-stationary reduction chain.
- [x] 2×2 weight-stationary GEMM array.
- [x] 2×2 output-stationary GEMM array.
- [x] Parameterized output-stationary array — 2×2 configuration verified.
- [x] Python fixed-width GEMM reference model.
- [x] Automated OS/WS RTL-versus-Python co-simulation for 2×2 matrices.

### In Progress / Planned

- [ ] Verify parameterized OS configurations beyond 2×2.
- [ ] Generalize the weight-stationary array.
- [ ] Extend randomized verification to multiple matrix dimensions.
- [ ] Implement parameterized tiles and meshes.
- [ ] Investigate pipeline boundaries and timing optimization.
- [ ] Develop accelerator control and memory interfaces.
- [ ] Perform comparable FPGA synthesis and timing analysis.
- [ ] Integrate AXI interfaces and processor-side software.
- [ ] Demonstrate the accelerator on ZedBoard.

## Verification

Verification combines:

- Directed Verilog testbenches.
- Icarus Verilog simulation.
- Python unit tests.
- Fixed-width signed arithmetic reference models.
- Automated RTL-versus-software result comparison.
- Reproducible randomized test vectors.

### Current Verification Results

| Design / Verification | Result |
|---|---|
| MAC | 3 directed tests passed |
| Initial PE | 3 directed tests passed |
| OS PE | 8 directed tests passed |
| WS PE | 11 directed tests passed |
| Two-stage WS chain | 9 directed tests passed |
| 2×2 WS GEMM array | 10 directed tests passed |
| 2×2 OS GEMM array | 11 directed tests passed |
| Python GEMM unit tests | 6 passed |
| 2×2 OS/WS RTL co-simulation | 31 matrix cases, 0 failures |
| Parameterized OS array (2×2) | Positive and signed matrix tests passed |

These results demonstrate functional correctness for the tested configurations and workloads. They do not yet constitute exhaustive verification or establish FPGA performance.

## Running the Simulations

**Prerequisites**

- Icarus Verilog (`iverilog` and `vvp`)
- Python 3
- Git

Run commands from the repository root.

### Python GEMM reference model

```bash
python3 -m verification.reference_models.gemm_reference
```

### Python unit tests

```bash
python3 -m unittest discover \
  -s verification/regressions \
  -p 'test_*.py' -v
```

### Automated OS/WS regression

```bash
python3 -m verification.regressions.run_gemm_cosim
```

### Parameterized OS array (2×2)

```bash
iverilog -g2012 -s os_array_param_tb \
  -o /tmp/os_param_2x2.vvp \
  rtl/pe/pe_os.v \
  rtl/array/os/os_array_param.v \
  tb/array/os/os_array_param_tb.v

vvp /tmp/os_param_2x2.vvp
```

## Target FPGA Platform

**ZedBoard — AMD/Xilinx Zynq-7000 XC7Z020**

FPGA development and future SoC integration will investigate:

- RTL synthesis and implementation.
- DSP, LUT, flip-flop, and memory resource utilization.
- Maximum clock frequency and timing closure.
- AXI-based communication between processor and programmable logic.
- Hardware/software partitioning and accelerator control.

The current GEMM architectures are simulation-verified prototypes; complete board-level accelerator integration is a future milestone.

## Technologies

- **RTL:** Verilog HDL
- **Simulation:** Icarus Verilog
- **Verification:** Python, Verilog testbenches
- **FPGA tools:** AMD/Xilinx Vivado
- **Automation:** Shell scripts, Tcl (planned integration)
- **Development:** VS Code, Git, GitHub

## Technical References

The project draws architectural inspiration from:

- Google TPU systolic matrix-multiplication architectures.
- UC Berkeley Gemmini accelerator generator.
- Established digital design, computer architecture, and FPGA verification practices.

See `docs/architecture/references.md` for architectural references and further reading.

## Development Approach

The project follows an incremental engineering workflow:

**Architecture specification → RTL implementation → Directed verification → Automated regression → Parameterization → FPGA evaluation → SoC integration**

Design decisions, experiments, and implementation results will be documented throughout development.

## Project Status

**Active development — Functional GEMM dataflows verified; scalable architecture and FPGA evaluation in progress.**

The repository is an engineering learning and experimentation platform rather than a production-ready accelerator.
