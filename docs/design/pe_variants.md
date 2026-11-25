# PE variants: two files, one module name

Two files define the same Verilog module, `pe_os`:

| File | Accumulator reset | Used by |
|---|---|---|
| `rtl/pe/pe_os.v` | Asynchronous (baseline) | PE and array testbenches, 2x2 OS/WS co-simulation, `run_param_gemm_regression.py`, `synth_gemm_ooc.tcl` |
| `rtl/pe/experimental/pe_os_sync.v` | Synchronous (shipped) | Banked, AXI and Stage 14 flows, `run_param_gemm_regression_os_sync.py`, `synth_os_sync_ooc.tcl` |

Ports and arithmetic are identical. Only the accumulator reset differs. The synchronous version lets Vivado place the accumulator in the DSP48E1 P register (see `README_OS_RESET_EXPERIMENT.md`).

## Why the name is shared

`os_array_param.v` and `systolic_array_os_2x2.v` instantiate `pe_os`. Sharing the name lets the same array RTL be built with either PE, chosen only by which file a script compiles. That is what made the reset experiment a one-variable change.

## Rule

Every build compiles exactly one of the two files. Compiling both gives two definitions of one module.

## Check

```bash
python3 scripts/check/check_pe_variant.py
```

The check lists which scripts use which PE and fails if an unreviewed script references both files. Comment lines are ignored. `compare_gemm_ooc.tcl` references both on purpose: it picks one per variant into a single `pe_file` variable, so it is on the reviewed list in the script.

## Possible future change

Give the two modules distinct names and pick one with a parameter in `os_array_param`. That changes shipped RTL, so it needs the regressions re-run and the resource numbers re-measured.
