# Standalone OOC synthesis of an already verified OS or WS GEMM datapath.
# Run from the repository root on Windows, with Vivado 2025.2, e.g.:
# vivado -mode batch -source scripts/vivado/synth_gemm_ooc_windows.tcl -tclargs os 2 2 2
# vivado -mode batch -source scripts/vivado/synth_gemm_ooc_windows.tcl -tclargs ws 2 2 2
# Arguments: DATAFLOW M K N, for C[M x N] = A[M x K] * B[K x N].
# This is *not* a board-programming or routed-timing flow.

if {[llength $argv] != 4} {
    error "Usage: -tclargs <os|ws> <M> <K> <N>; example: os 2 2 2"
}

set dataflow [string tolower [lindex $argv 0]]
foreach {arg_idx name} {1 M 2 K 3 N} {
    set raw [lindex $argv $arg_idx]
    if {![string is integer -strict $raw] || $raw < 1} {
        error "$name must be a positive integer; got '$raw'"
    }
    set $name $raw
}
if {$dataflow ne "os" && $dataflow ne "ws"} {
    error "Dataflow must be 'os' or 'ws'"
}

set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir .. ..]]
set part "xc7z020clg484-1"
set output_dir [file join $root_dir reports synth_ooc "${dataflow}_M${M}_K${K}_N${N}"]
file mkdir $output_dir

if {$dataflow eq "os"} {
    set top "os_array_param"
    set rtl [list \
        [file join $root_dir rtl pe pe_os.v] \
        [file join $root_dir rtl array os os_array_param.v]]
    set generics [list "ROWS=$M" "COLS=$N"]
} else {
    set top "ws_array_param"
    set rtl [list \
        [file join $root_dir rtl pe pe_ws.v] \
        [file join $root_dir rtl array ws ws_array_param.v]]
    set generics [list "K_STAGES=$K" "COLS=$N"]
}

set xdc [file join $root_dir fpga zedboard constraints core_100mhz_ooc.xdc]
foreach path [concat $rtl [list $xdc]] {
    if {![file exists $path]} {error "Required input file not found: $path"}
}

puts "=== Standalone $dataflow synthesis for GEMM $M x $K x $N ==="
puts "Root: $root_dir"
puts "Part: $part; top: $top; parameters: $generics"
puts "Reports: $output_dir"

create_project -in_memory -part $part
foreach path $rtl {read_verilog -sv $path}
read_xdc $xdc

# Vivado documentation specifies a separate -generic for each parameter.
set cmd [list synth_design -top $top -part $part -mode out_of_context]
foreach assignment $generics {lappend cmd -generic $assignment}
puts "Command: $cmd"
{*}$cmd

report_utilization -file [file join $output_dir utilization.rpt]
report_timing_summary -file [file join $output_dir timing_summary.rpt]
report_drc -file [file join $output_dir drc.rpt]
write_checkpoint -force [file join $output_dir synthesized.dcp]
puts "SUCCESS: $dataflow $M x $K x $N"
puts "Open utilization.rpt and timing_summary.rpt under: $output_dir"
