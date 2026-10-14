# Read the generated project and check the complete board top with real IP RTL.
# Usage: vivado -mode batch -source check_elaboration.tcl -tclargs <project.xpr>
if {[llength $argv]!=1} {error "Pass the generated project .xpr"}
open_project [lindex $argv 0]
if {[get_property PART [current_project]] ne "xc7a200tfbg484-2"} {error "Wrong part"}
update_compile_order -fileset sources_1
synth_design -rtl -top adc_ddr_fbg484_top -part xc7a200tfbg484-2 -name rtl_check
set blackboxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
if {[llength $blackboxes]} {error "Unresolved black boxes: $blackboxes"}
puts "PASS board elaboration: FBG484 top, actual MIG/clock/VIO/FIFO RTL, no unresolved black boxes"
close_project
exit
