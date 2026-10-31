# Stage 12: Post-route implementation of Stage 11 banked OS GEMM
# Target: XC7Z020, using the existing synthesis checkpoint.

if {$argc != 3} {
    error "Usage: -tclargs M K N"
}

set M [lindex $argv 0]
set K [lindex $argv 1]
set N [lindex $argv 2]

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ../..]]

set synth_dir [file join $root reports stage11 "banked_os_${M}x${K}x${N}"]
set out_dir [file join $root reports stage12 "banked_os_${M}x${K}x${N}"]

set checkpoint [file join $synth_dir synthesized.dcp]

if {![file exists $checkpoint]} {
    error "Synthesis checkpoint missing: $checkpoint"
}

file mkdir $out_dir

puts "=== STAGE 12: BANKED OS POST-ROUTE IMPLEMENTATION ==="

open_checkpoint $checkpoint

if {[llength [get_clocks -quiet]] == 0} {
    error "No timing clock found in synthesis checkpoint"
}

# Optimize design
opt_design

# Placement
place_design

report_timing_summary \
    -file [file join $out_dir timing_place.rpt]

report_utilization \
    -file [file join $out_dir utilization_place.rpt]

# Routing
route_design

# Post-route reports
report_route_status \
    -file [file join $out_dir route_status.rpt]

report_timing_summary \
    -file [file join $out_dir timing_route.rpt]

report_utilization \
    -file [file join $out_dir utilization_route.rpt]

report_timing -delay_type max -max_paths 5 \
    -file [file join $out_dir worst5_setup_route.rpt]

report_timing -delay_type min -max_paths 5 \
    -file [file join $out_dir worst5_hold_route.rpt]

report_drc \
    -file [file join $out_dir drc_route.rpt]

# Save checkpoint
write_checkpoint -force \
    [file join $out_dir routed.dcp]

# Record inferred memory and DSP primitives
set fp [open [file join $out_dir primitives_route.txt] w]

foreach prim {DSP48E1 RAM32M RAM64M RAMB18E1 RAMB36E1} {
    set cells [get_cells -quiet -hier -filter "REF_NAME == $prim"]
    puts $fp "$prim=[llength $cells]"
}

foreach dsp [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp PREG=[get_property PREG $dsp] MREG=[get_property MREG $dsp]"
}

close $fp

puts "=== STAGE 12 IMPLEMENTATION FINISHED ==="
puts "Reports: $out_dir"
