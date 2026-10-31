# Windows PowerShell 5.1 / PowerShell 7 compatible.
# Run from systolic-gemm-accelerator repository root.
$ErrorActionPreference = 'Stop'
$buildDir = 'build/stage11'
New-Item -ItemType Directory -Force $buildDir | Out-Null
$shapes = @(
    @(2, 2, 2),
    @(3, 3, 3),
    @(4, 4, 4),
    @(2, 4, 3)
)
foreach ($shape in $shapes) {
    $M = $shape[0]
    $K = $shape[1]
    $N = $shape[2]
    $out = "$buildDir/banked_os_${M}x${K}x${N}.vvp"
    Write-Host "`n=== Stage11 Banked OS M=$M K=$K N=$N ==="
    & iverilog -g2012 -s os_banked_gemm_tb `
        -P "os_banked_gemm_tb.ROWS=$M" `
        -P "os_banked_gemm_tb.K=$K" `
        -P "os_banked_gemm_tb.COLS=$N" `
        -o $out `
        rtl/memory/gemm_sync_bank.v `
        rtl/control/os_mem_prefetch_ctrl.v `
        rtl/top/os_gemm_banked_top.v `
        rtl/pe/experimental/pe_os_sync.v `
        rtl/array/os/os_array_param.v `
        tb/integration/os_banked_gemm_tb.v
    if ($LASTEXITCODE -ne 0) { throw "Stage11 compilation failed: $M x $K x $N" }
    & vvp $out
    if ($LASTEXITCODE -ne 0) { throw "Stage11 simulation failed: $M x $K x $N" }
}
Write-Host "`nALL STAGE 11 BANKED MEMORY REGRESSIONS COMPLETED"
