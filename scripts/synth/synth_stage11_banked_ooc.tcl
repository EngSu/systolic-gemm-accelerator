# Stage 11 standalone OOC synthesis. Run from repo root with:
#   vivado -mode batch -source scripts/synth/synth_stage11_banked_ooc.tcl -tclargs 4 4 4
# Params are M K N. OOC 10ns constraint is NOT full system timing signoff.
if {$argc != 3} { error "Usage: -tclargs M K N" }
set M [lindex $argv 0]
set K [lindex $argv 1]
set N [lindex $argv 2]
foreach dim [list $M $K $N] {
    if {![string is integer -strict $dim] || $dim < 1} {
        error "All dimensions must be positive integers"
    }
}
set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ../..]]
set out_dir [file join $root reports stage11 "banked_os_${M}x${K}x${N}"]
file mkdir $out_dir
set sources [list \
    [file join $root rtl memory gemm_sync_bank.v] \
    [file join $root rtl control os_mem_prefetch_ctrl.v] \
    [file join $root rtl top os_gemm_banked_top.v] \
    [file join $root rtl pe experimental pe_os_sync.v] \
    [file join $root rtl array os os_array_param.v]]
foreach src $sources {
    if {![file exists $src]} {error "Missing source: $src"}
}
create_project -in_memory -part xc7z020clg484-1
foreach src $sources { read_verilog -sv $src }
synth_design -top os_gemm_banked_top -part xc7z020clg484-1 \
    -mode out_of_context -generic "ROWS=$M" -generic "K=$K" -generic "COLS=$N"
create_clock -name core_clk -period 10.000 [get_ports clk]
report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_synth.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]

set fp [open [file join $out_dir memory_dsp_cells.txt] w]
foreach prim {RAMB18E1 RAMB36E1 RAM32M RAM64M DSP48E1} {
    set matches [get_cells -hier -filter "REF_NAME == $prim"]
    puts $fp "$prim=[llength $matches]"
}
foreach dsp [get_cells -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp PREG=[get_property PREG $dsp] MREG=[get_property MREG $dsp]"
}
close $fp
puts "Stage11 OOC synthesis complete. Reports: $out_dir"
