# Controlled DSP-inference experiment for the 2x2 OS array.
# Execute from repository root:
# vivado -mode batch -source scripts/synth/synth_os_sync_ooc.tcl
# Do NOT read rtl/pe/pe_os.v in this run.

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir ../..]]
set part xc7z020clg484-1
set out_dir [file join $repo_root reports experiments os_sync_2x2]
file mkdir $out_dir

set pe_file [file join $repo_root rtl pe experimental pe_os_sync.v]
set array_file [file join $repo_root rtl array os os_array_param.v]
foreach f [list $pe_file $array_file] {
    if {![file exists $f]} {error "Missing source: $f"}
}

create_project -in_memory -part $part
read_verilog -sv $pe_file
read_verilog -sv $array_file
synth_design -top os_array_param -part $part -mode out_of_context \
    -generic ROWS=2 -generic COLS=2
create_clock -name core_clk -period 10.000 [get_ports clk]

report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_synth.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]

set fp [open [file join $out_dir dsp_pipeline_synth.txt] w]
foreach dsp [get_cells -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}
close $fp

# Use the same implementation stages as the original baseline.
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
foreach dsp [get_cells -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}
close $fp

puts "EXPERIMENT COMPLETED. Reports: $out_dir"
