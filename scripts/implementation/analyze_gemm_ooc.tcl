# analyze_gemm_ooc.tcl
# OOC physical implementation and timing reporting for the existing
# 2x2 OS/WS synthesized checkpoints. Does not change RTL or source checkpoints.
# Usage, from repository root:
# vivado -mode batch -source scripts/implementation/analyze_gemm_ooc.tcl -tclargs os
# vivado -mode batch -source scripts/implementation/analyze_gemm_ooc.tcl -tclargs ws

if {[llength $argv] != 1} {
    error "Usage: -tclargs os|ws"
}

set dataflow [string tolower [lindex $argv 0]]
if {$dataflow ne "os" && $dataflow ne "ws"} {
    error "Expected 'os' or 'ws', got '$dataflow'"
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]
set synth_dir [file join $repo_root reports synth ${dataflow}_2x2]
set dcp [file join $synth_dir synthesized.dcp]
set out_dir [file join $repo_root reports implementation ${dataflow}_2x2]

if {![file exists $dcp]} {
    error "Synthesized checkpoint not found: $dcp"
}
file mkdir $out_dir

puts "============================================================"
puts "Analysis target: $dataflow 2x2"
puts "Input checkpoint: $dcp"
puts "Output directory: $out_dir"
puts "============================================================"

open_checkpoint $dcp

# A clock should have been saved in the synthesis checkpoint.
set clocks [get_clocks -quiet]
if {[llength $clocks] == 0} {
    error "No clocks found in checkpoint. Add a clock constraint to the synthesis flow and regenerate its DCP."
}
puts "Clock objects: $clocks"

# Preserve detailed post-synthesis path evidence separately.
report_timing -delay_type max -max_paths 5 -path_type full_clock_expanded \
    -input_pins -file [file join $out_dir presynth_worst5_setup.rpt]

# Physical implementation, without a top-level board/PS/AXI design.
opt_design
place_design
report_timing_summary -file [file join $out_dir post_place_timing_summary.rpt]

route_design
report_route_status -file [file join $out_dir route_status.rpt]
report_timing_summary -file [file join $out_dir post_route_timing_summary.rpt]
report_timing -delay_type max -max_paths 5 -path_type full_clock_expanded \
    -input_pins -file [file join $out_dir post_route_worst5_setup.rpt]
report_utilization -file [file join $out_dir post_route_utilization.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]

puts "============================================================"
puts "Finished $dataflow 2x2 OOC physical implementation."
puts "Reports: $out_dir"
puts "============================================================"
