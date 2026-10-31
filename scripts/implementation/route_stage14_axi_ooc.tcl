# Stage 14B: post-route implementation of Stage 14 synthesized AXI GEMM core.
# Uses the Stage 14A synthesized checkpoint (not the Stage 11 checkpoint).
# OOC timing constraint covers internal paths; AXI I/O delays not signoff-ready.

if {$argc != 3} { error "Usage: -tclargs ROWS K COLS (e.g. 4 4 4)" }
set M [lindex $argv 0]
set K [lindex $argv 1]
set N [lindex $argv 2]
foreach item [list $M $K $N] {
    if {![string is integer -strict $item] || $item < 1} {
        error "ROWS, K and COLS must be positive integers"
    }
}
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ../..]]
set out_dir [file join $root reports stage14 "axi_os_${M}x${K}x${N}"]
set checkpoint [file join $out_dir synthesized.dcp]
if {![file exists $checkpoint]} {error "Missing checkpoint: $checkpoint. Run Stage 14A first."}

puts "STAGE14B: placing and routing AXI GEMM M=$M K=$K N=$N"
open_checkpoint $checkpoint
if {[llength [get_clocks -quiet]] == 0} {
    error "No clock in checkpoint. Expected s_axi_aclk at 10ns."
}
opt_design
place_design
report_utilization -file [file join $out_dir utilization_place.rpt]
report_timing_summary -report_unconstrained \
    -file [file join $out_dir timing_place.rpt]
route_design

report_utilization -file [file join $out_dir utilization_route.rpt]
report_timing_summary -report_unconstrained \
    -file [file join $out_dir timing_route.rpt]
report_timing -delay_type max -max_paths 5 \
    -file [file join $out_dir worst5_setup_route.rpt]
report_timing -delay_type min -max_paths 5 \
    -file [file join $out_dir worst5_hold_route.rpt]
report_route_status -file [file join $out_dir route_status.rpt]
report_drc -file [file join $out_dir drc_route.rpt]
check_timing -verbose -file [file join $out_dir check_timing_route.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]

set fp [open [file join $out_dir primitives_route.txt] w]
foreach prim {DSP48E1 RAM32M RAM64M RAMB18E1 RAMB36E1} {
    puts $fp "$prim=[llength [get_cells -quiet -hier -filter "REF_NAME == $prim"]]"
}
foreach dsp [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}
close $fp
puts "STAGE14B COMPLETE: $out_dir"
