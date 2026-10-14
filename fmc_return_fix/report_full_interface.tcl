# Read-only timing audit of the newly routed complete design.
set fix_root [file normalize [file dirname [info script]]]
if {[llength $argv] != 1} { error "Supply the completed implementation directory" }
set completed_run [file normalize [lindex $argv 0]]
open_checkpoint [file join $completed_run adc_ddr_fbg484_top_routed.dcp]
set report_root [file join $fix_root reports]
report_timing_summary -file [file join $report_root full_project_timing.rpt]
set data_pins [get_ports {MCU_FMC_D[*]}]
if {[llength $data_pins] != 16} {
    # Use the actual top-level naming from this project's FMC XDC.
    set data_pins [get_ports {FMC_D[*]}]
}
if {[llength $data_pins] != 16} { error "Cannot uniquely identify all 16 FMC data ports" }
report_timing -to $data_pins -delay_type max -max_paths 16 -file [file join $report_root full_fmc_output_setup.rpt]
report_timing -to $data_pins -delay_type min -max_paths 16 -file [file join $report_root full_fmc_output_hold.rpt]
report_drc -file [file join $report_root full_project_drc.rpt]
set audit_channel [open [file join $report_root full_interface_audit.txt] w]
puts $audit_channel "checkpoint=$completed_run"
puts $audit_channel "data_ports=$data_pins"
puts $audit_channel "debug_cores=[get_debug_cores -quiet]"
puts $audit_channel "extra_drive_data_registers=[get_cells -quiet -hierarchical -filter {NAME =~ u_fmc_port/drive_data_reg*}]"
puts $audit_channel "tristate_register_count=[llength [get_cells -quiet -hierarchical -filter {NAME =~ u_fmc_port/drive_tristate_reg*}]]"
close $audit_channel
close_design
exit
