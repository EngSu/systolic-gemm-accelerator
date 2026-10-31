set root [file normalize [pwd]]
set dir [file join $root reports stage14 axi_os_4x4x4]

open_checkpoint [file join $dir routed.dcp]

check_timing -verbose \
    -file [file join $dir check_timing_route.rpt]

report_drc \
    -file [file join $dir drc_audit.rpt]

report_timing_summary -report_unconstrained \
    -file [file join $dir timing_audit.rpt]

puts "Stage 14 timing and DRC audit complete."
