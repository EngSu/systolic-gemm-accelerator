
# Systolic GEMM Accelerator
# Out-of-context synthesis baseline
#
# Usage:
# vivado -mode batch -source scripts/synth/synth_gemm_ooc.tcl \
#   -tclargs os 2 2
#
# vivado -mode batch -source scripts/synth/synth_gemm_ooc.tcl \
#   -tclargs ws 2 2

if {[llength $argv] != 3} {
    error "Usage: <os|ws> <first_dimension> <columns>"
}

set dataflow [lindex $argv 0]
set first_dim [lindex $argv 1]
set cols [lindex $argv 2]

if {$first_dim < 1 || $cols < 1} {
    error "Dimensions must be positive"
}

set part xc7z020clg484-1

# Resolve repository root from this script's location.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir ../..]]

if {$dataflow eq "os"} {

    set top os_array_param
    set generics [list "ROWS=$first_dim" "COLS=$cols"]

    set sources [list \
        [file join $repo_root rtl pe pe_os.v] \
        [file join $repo_root rtl array os os_array_param.v] \
    ]

} elseif {$dataflow eq "ws"} {

    set top ws_array_param
    set generics [list "K_STAGES=$first_dim" "COLS=$cols"]

    set sources [list \
        [file join $repo_root rtl pe pe_ws.v] \
        [file join $repo_root rtl array ws ws_array_param.v] \
    ]

} else {
    error "Invalid dataflow. Use os or ws."
}

set report_dir [file join \
    $repo_root reports synth \
    "${dataflow}_${first_dim}x${cols}" \
]

file mkdir $report_dir

puts "========================================"
puts "Systolic GEMM synthesis"
puts "Dataflow: $dataflow"
puts "Top:      $top"
puts "Part:     $part"
puts "Generics: $generics"
puts "Reports:  $report_dir"
puts "========================================"

# Use an in-memory Vivado project.
create_project -in_memory -part $part

# Load existing, simulation-verified RTL.
foreach source $sources {
    if {![file exists $source]} {
        error "Missing RTL source: $source"
    }

    read_verilog -sv $source
}

# Synthesize as internal logic, not a board pin-level design.
synth_design \
    -top $top \
    -part $part \
    -mode out_of_context \
    -generic $generics

# Preliminary internal clock constraint.
# This is NOT a measured maximum clock frequency.
create_clock \
    -name core_clk \
    -period 10.000 \
    [get_ports clk]

# Synthesis reports.
report_utilization \
    -file [file join $report_dir utilization.rpt]

report_timing_summary \
    -file [file join $report_dir timing_summary.rpt]

# Preserve synthesized netlist for inspection.
write_checkpoint -force \
    [file join $report_dir synthesized.dcp]

puts "========================================"
puts "Synthesis completed: $dataflow"
puts "Reports saved in: $report_dir"
puts "========================================"

