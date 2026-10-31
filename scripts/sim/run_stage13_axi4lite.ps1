# Stage 13 - AXI4-Lite / banked-memory OS GEMM integration regression
# Run from any location; paths resolve relative to the repository.
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Push-Location $root
try {
    if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) { throw 'iverilog not found in PATH' }
    if (-not (Get-Command vvp -ErrorAction SilentlyContinue)) { throw 'vvp not found in PATH' }

    New-Item -ItemType Directory -Force build/integration | Out-Null
    New-Item -ItemType Directory -Force reports/verification | Out-Null

    $configs = @(
        @(2,2,2),
        @(3,3,3),
        @(4,4,4),
        @(2,4,3)
    )
    foreach ($cfg in $configs) {
        $m = $cfg[0]; $k = $cfg[1]; $n = $cfg[2]
        $tag = "${m}x${k}x${n}"
        $exe = "build/integration/stage13_axi4lite_${tag}.vvp"
        $log = "reports/verification/stage13_axi4lite_${tag}.log"
        Write-Host "`n=== Stage 13 AXI4-Lite M=$m K=$k N=$n ==="
        & iverilog -g2012 -s os_axi4lite_gemm_tb `
            -P "os_axi4lite_gemm_tb.ROWS=$m" `
            -P "os_axi4lite_gemm_tb.K=$k" `
            -P "os_axi4lite_gemm_tb.COLS=$n" `
            -o $exe `
            rtl/pe/experimental/pe_os_sync.v `
            rtl/array/os/os_array_param.v `
            rtl/memory/gemm_sync_bank.v `
            rtl/control/os_mem_prefetch_ctrl.v `
            rtl/top/os_gemm_banked_top.v `
            rtl/axi/os_gemm_axi_lite_top.v `
            tb/integration/os_axi4lite_gemm_tb.v
        if ($LASTEXITCODE -ne 0) { throw "Icarus compilation failed: $tag" }

        & vvp $exe | Tee-Object -FilePath $log
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $tag (see $log)" }
        if (-not (Select-String -Path $log -Pattern "ALL STAGE 13 AXI4-LITE TESTS PASSED M=$m K=$k N=$n" -Quiet)) {
            throw "Missing PASS marker in $log"
        }
    }
    Write-Host "`nALL STAGE 13 AXI4-LITE REGRESSIONS COMPLETED: 12 CASES"
} finally {
    Pop-Location
}
