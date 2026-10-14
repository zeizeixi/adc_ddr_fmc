# Usage: vivado -mode batch -source run_vivado_tests.tcl -tclargs /absolute/work-dir
# Creates an isolated SIMULATION project for an arbitrary supported Artix-7 part.
# That part is NOT a claim about the user's board. No project on E: is touched.
set root [file dirname [file dirname [info script]]]
if {[llength $argv] != 1} { error "Pass a fresh writable simulation work directory" }
set test_dir [string map {\\ /} [lindex $argv 0]]
create_project capture_test $test_dir -part xc7a200tsbg484-1
set_property target_language Verilog [current_project]
source [file join $root scripts create_fifo_ip.tcl]
add_files [glob [file join $root rtl *.v]]
add_files -fileset sim_1 [glob [file join $root tb *.sv]]
set_property top ads62p24_to_mig256 [current_fileset]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
foreach top {tb_capture tb_overflow} {
    set_property top $top [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation -simset sim_1 -mode behavioral
    run all
    close_sim
}
close_project
exit
