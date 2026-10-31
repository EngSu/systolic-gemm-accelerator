# PowerShell 5.1 compatible. Run from repository root.
$ErrorActionPreference = 'Stop'
$buildDir = 'build/integration'
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
    $out = "$buildDir/os_integrated_${M}x${K}x${N}.vvp"
    Write-Host "`n=== Integrated OS M=$M K=$K N=$N ==="
    & iverilog -g2012 -s os_scheduler_param_tb `
        -P "os_scheduler_param_tb.ROWS=$M" `
        -P "os_scheduler_param_tb.K=$K" `
        -P "os_scheduler_param_tb.COLS=$N" `
        -o $out `
        rtl/control/os_input_scheduler.v `
        rtl/pe/experimental/pe_os_sync.v `
        rtl/array/os/os_array_param.v `
        tb/integration/os_scheduler_param_tb.v
    if ($LASTEXITCODE -ne 0) { throw "Icarus compile failed for $M x $K x $N" }
    & vvp $out
    if ($LASTEXITCODE -ne 0) { throw "Icarus simulation failed for $M x $K x $N" }
}
Write-Host "`nALL INTEGRATED OS SCALING RUNS COMPLETED"
