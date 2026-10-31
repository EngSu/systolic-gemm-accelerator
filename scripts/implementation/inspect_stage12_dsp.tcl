set root [file normalize [pwd]]
set dir [file join $root reports stage12 banked_os_4x4x4]

open_checkpoint [file join $dir routed.dcp]

set fp [open [file join $dir dsp_register_details.txt] w]

foreach dsp [get_cells -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}

close $fp

check_timing -verbose \
    -file [file join $dir check_timing_route.rpt]

report_timing_summary -report_unconstrained \
    -file [file join $dir timing_constraints_review.rpt]

puts "Stage 12 DSP and timing inspection complete."
