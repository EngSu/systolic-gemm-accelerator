# Stage 14A: synthesize complete AXI4-Lite + banked-memory OS GEMM core
# Execute from any directory with Vivado -mode batch -source ... -tclargs M K N
# Out-of-context 10ns clock; does NOT constrain external AXI I/O timing.

if {$argc != 3} { error "Usage: -tclargs ROWS K COLS (e.g. 4 4 4)" }
set M [lindex $argv 0]
set K [lindex $argv 1]
set N [lindex $argv 2]
foreach item [list $M $K $N] {
    if {![string is integer -strict $item] || $item < 1} {
        error "ROWS, K and COLS must be positive integers"
    }
}
if {$M > 16 || $N > 16 || $K > 255} {
    error "Stage 13 register-map limits: ROWS/COLS <= 16, K <= 255"
}

set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ../..]]
set part xc7z020clg484-1
set out_dir [file join $root reports stage14 "axi_os_${M}x${K}x${N}"]
file mkdir $out_dir

set sources [list \
    [file join $root rtl pe experimental pe_os_sync.v] \
    [file join $root rtl array os os_array_param.v] \
    [file join $root rtl memory gemm_sync_bank.v] \
    [file join $root rtl control os_mem_prefetch_ctrl.v] \
    [file join $root rtl top os_gemm_banked_top.v] \
    [file join $root rtl axi os_gemm_axi_lite_top.v] \
]
foreach src $sources {
    if {![file exists $src]} { error "Missing RTL source: $src" }
}

puts "STAGE14A: OOC synthesis: M=$M K=$K N=$N, part=$part"
create_project -in_memory -part $part
foreach src $sources { read_verilog -sv $src }
synth_design -top os_gemm_axi_lite_top -part $part \
    -mode out_of_context -generic "ROWS=$M" -generic "K=$K" -generic "COLS=$N"

set clk [get_ports -quiet s_axi_aclk]
if {[llength $clk] != 1} { error "s_axi_aclk port missing from synthesized top" }
create_clock -name s_axi_aclk -period 10.000 $clk

report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -report_unconstrained \
    -file [file join $out_dir timing_synth.rpt]
report_timing -delay_type max -max_paths 5 \
    -file [file join $out_dir worst5_setup_synth.rpt]
check_timing -verbose -file [file join $out_dir check_timing_synth.rpt]
write_checkpoint -force [file join $out_dir synthesized.dcp]

set fp [open [file join $out_dir primitives_synth.txt] w]
foreach prim {DSP48E1 RAM32M RAM64M RAMB18E1 RAMB36E1} {
    puts $fp "$prim=[llength [get_cells -quiet -hier -filter "REF_NAME == $prim"]]"
}
foreach dsp [get_cells -quiet -hier -filter {REF_NAME == DSP48E1}] {
    puts $fp "$dsp AREG=[get_property AREG $dsp] BREG=[get_property BREG $dsp] MREG=[get_property MREG $dsp] PREG=[get_property PREG $dsp]"
}
close $fp
puts "STAGE14A COMPLETE: $out_dir"
