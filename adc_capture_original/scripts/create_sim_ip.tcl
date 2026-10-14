# Simulation-only target device; not a board pin assignment.
if {[llength $argv] != 1} { error "Pass a fresh simulation project directory" }
set project_dir [string map {\\ /} [lindex $argv 0]]
create_project capture_test $project_dir -part xc7a200tsbg484-1
set_property target_language Verilog [current_project]
source [file join [file dirname [info script]] create_fifo_ip.tcl]
close_project
exit
