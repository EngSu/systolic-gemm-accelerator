# Run from any location:
# powershell -ExecutionPolicy Bypass -File scripts/windows/run_verified_checks.ps1
# Assumes you already installed Python and Icarus Verilog.
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repoRoot

function Assert-File([string] $Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing $Path. Check that you cloned/pulled the committed project files."
    }
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'Python not found. Reopen PowerShell or install Python.'
}
if (-not (Get-Command iverilog -ErrorAction SilentlyContinue)) {
    throw 'iverilog not found. Install Icarus Verilog and reopen PowerShell.'
}
if (-not (Get-Command vvp -ErrorAction SilentlyContinue)) {
    throw 'vvp not found. Check your Icarus Verilog installation.'
}

Write-Host '=== Python golden-model unit tests ==='
Assert-File 'verification/reference_models/gemm_reference.py'
& python -m unittest discover -s verification/regressions -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) {throw 'Python unit tests FAILED.'}

Write-Host '=== OS vs WS 2x2 cycle-level cosimulation ==='
$files = @(
    'rtl/pe/pe_os.v',
    'rtl/pe/pe_ws.v',
    'rtl/array/os/os_array_param.v',
    'rtl/array/ws/ws_array_param.v',
    'tb/comparison/gemm_latency_2x2_tb.v'
)
foreach ($file in $files) {Assert-File $file}
New-Item -ItemType Directory -Path 'build/windows' -Force | Out-Null
$outFile = 'build/windows/gemm_latency_2x2.vvp'
& iverilog -g2012 -s gemm_latency_2x2_tb -o $outFile @files
if ($LASTEXITCODE -ne 0) {throw 'Icarus compilation FAILED.'}
& vvp $outFile
if ($LASTEXITCODE -ne 0) {throw '2x2 OS/WS simulation FAILED.'}

# Optional: only if the previously drafted scheduler and its TB are checked in.
$scheduler = 'rtl/control/os_input_scheduler.v'
$schedulerTb = 'tb/control/os_scheduler_integration_tb.v'
if ((Test-Path $scheduler) -and (Test-Path $schedulerTb)) {
    Write-Host '=== Optional OS scheduler integration simulation ==='
    $osInputs = @(
        'rtl/pe/pe_os.v',
        'rtl/array/os/os_array_param.v',
        $scheduler,
        $schedulerTb
    )
    & iverilog -g2012 -s os_scheduler_integration_tb -o 'build/windows/os_scheduler.vvp' @osInputs
    if ($LASTEXITCODE -ne 0) {throw 'OS scheduler compilation FAILED.'}
    & vvp 'build/windows/os_scheduler.vvp'
    if ($LASTEXITCODE -ne 0) {throw 'OS scheduler simulation FAILED.'}
} else {
    Write-Host 'Optional scheduler integration skipped (RTL or testbench not found).'
}
Write-Host 'PASS: Available Windows RTL checks completed.'
