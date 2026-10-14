if {[llength $argv]!=1} {error "Pass a fresh simulation project directory"}
create_project capture_test [lindex $argv 0] -part xc7a200tfbg484-2
set_property target_language Verilog [current_project]
source [file join [file dirname [info script]] create_fifo_ip.tcl]
close_project
exit
