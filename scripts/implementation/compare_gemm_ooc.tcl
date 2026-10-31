# Scalable out-of-context GEMM comparison on XC7Z020.
# Usage (from repository root):
#   vivado -mode batch -source scripts/implementation/compare_gemm_ooc.tcl -tclargs os_async 4 4 4
#   vivado -mode batch -source scripts/implementation/compare_gemm_ooc.tcl -tclargs os_sync  4 4 4
#   vivado -mode batch -source scripts/implementation/compare_gemm_ooc.tcl -tclargs ws       4 4 4
#
# Arguments: variant M K N for C[M,N] = A[M,K] * B[K,N]
# For OS, hardware dimensions are ROWS=M, COLS=N.
# For WS, hardware dimensions are K_STAGES=K, COLS=N.
# K does not affect standalone OS physical resources until the scheduler is included.
#
# NOTE: OOC only; top-level interfaces and clock source are not fully constrained.
# Do not treat resulting WNS as fully integrated system Fmax.

if {$argc != 4} {
    error "Usage: -tclargs <os_async|os_sync|ws> <M> <K> <N>"
}
set variant [lindex $argv 0]
set M [lindex $argv 1]
set K [lindex $argv 2]
set N [lindex $argv 3]

if {$variant ni {os_async os_sync ws}} {
    error "Unknown variant '$variant' (use os_async, os_sync, or ws)"
}
foreach v [list $M $K $N] {
    if {![string is integer -strict $v] || $v < 1 || $v > 64} {
        error "M, K, N must be integers between 1 and 64"
    }
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set part xc7z020clg484-1
set out_dir [file join $repo_root reports scaling "${variant}_${M}x${K}x${N}"]
file mkdir $out_dir

switch -- $variant {
    os_async {
        set pe_file [file join $repo_root rtl pe pe_os.v]
        set array_file [file join $repo_root rtl array os os_array_param.v]
        set top_name os_array_param
        set generics [list "ROWS=$M" "COLS=$N"]
    }
    os_sync {
        set pe_file [file join $repo_root rtl pe experimental pe_os_sync.v]
        set array_file [file join $repo_root rtl array os os_array_param.v]
        set top_name os_array_param
        set generics [list "ROWS=$M" "COLS=$N"]
    }
    ws {
        set pe_file [file join $repo_root rtl pe pe_ws.v]
        set array_file [file join $repo_root rtl array ws ws_array_param.v]
        set top_name ws_array_param
        set generics [list "K_STAGES=$K" "COLS=$N"]
    }
}
foreach f [list $pe_file $array_file] {
    if {![file exists $f]} { error "Missing source: $f" }
}

puts "=== GEMM OOC SCALING ==="
puts "Variant: $variant"
puts "GEMM dimensions: M=$M K=$K N=$N"
puts "PE source: $pe_file"
puts "Array source: $array_file"
puts "Reports: $out_dir"

create_project -in_memory -part $part
read_verilog -sv $pe_file
read_verilog -sv $array_file

set synth_args [list -top $top_name -part $part -mode out_of_context]
foreach g $generics {
    lappend synth_args -generic $g
}
synth_design {*}$synth_args
create_clock -name core_clk -period 10.000 [get_ports clk]

report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_synth.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]

opt_design
place_design
route_design

report_route_status -file [file join $out_dir route_status.rpt]
report_utilization -file [file join $out_dir utilization_route.rpt]
report_timing_summary -file [file join $out_dir timing_route.rpt]
report_timing -delay_type max -max_paths 5 -path_type full_clock_expanded \
    -file [file join $out_dir worst5_route.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]

set fp [open [file join $out_dir dsp_pipeline_route.txt] w]
set dsps [get_cells -hier -filter {REF_NAME == DSP48E1}]
puts $fp "DSP_COUNT=[llength $dsps]"
foreach dsp $dsps {
    puts $fp "$dsp LOC=[get_property LOC $dsp] AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}
close $fp

puts "=== COMPLETED: $variant M=$M K=$K N=$N ==="
puts "Reports: $out_dir"
