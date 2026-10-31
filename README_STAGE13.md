# Stage 13: AXI4-Lite Control + Register-Mapped GEMM Results

**Preserves the working Stage 11 modules.** New files only.

## Windows PowerShell install

From `C:\Users\sumay\systolic-gemm-accelerator`:

```powershell
Expand-Archive -LiteralPath "$HOME\Downloads\stage13_axi4lite_gemm.zip" -DestinationPath .
```

## Run simulations

```powershell
& .\scripts\sim\run_stage13_axi4lite.ps1
```

If PowerShell prevents the script from executing:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sim\run_stage13_axi4lite.ps1
```

Four configurations, three cases each. **Expected**, not yet confirmed:

```text
PASS Stage13 AXI4-Lite M=2 K=2 N=2 case=0
...
ALL STAGE 13 AXI4-LITE REGRESSIONS COMPLETED: 12 CASES
```

If compilation fails, paste the *first compilation error* and the following
context. If simulation fails, paste the first `FAIL` line plus surrounding
results. Do not ignore `SLVERR`: invalid transactions are deliberately tested.

## File inventory

- `rtl/axi/os_gemm_axi_lite_top.v`: AXI4-Lite bus, register decode, staging and readback.
- `tb/integration/os_axi4lite_gemm_tb.v`: self-checking AXI transaction testbench.
- `scripts/sim/run_stage13_axi4lite.ps1`: 4-configuration Windows runner and log capture.
- `docs/design/stage13_axi4lite.md`: register map, programming sequence and limitations.

## Required existing Stage 11 source files

- `rtl/pe/experimental/pe_os_sync.v`
- `rtl/array/os/os_array_param.v`
- `rtl/memory/gemm_sync_bank.v`
- `rtl/control/os_mem_prefetch_ctrl.v`
- `rtl/top/os_gemm_banked_top.v`

This package deliberately does not overwrite any of those existing files.
It does not perform Vivado synthesis or actual Zynq PS/PL integration yet.
