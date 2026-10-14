# Upload an existing completed acquisition. Do not arm or program the FPGA.
open_hw_manager
connect_hw_server -url localhost:3121
set fmc_read_targets [get_hw_targets -quiet *xilinx_tcf/Xilinx/00000000000000]
if {[llength $fmc_read_targets] != 1} { error "Expected exactly the user's existing Xilinx target" }
open_hw_target $fmc_read_targets
set fmc_read_device [get_hw_devices -quiet xc7a200t_0]
if {[llength $fmc_read_device] != 1} { error "Expected xc7a200t_0" }
current_hw_device $fmc_read_device
set fmc_read_ltx {./local_inputs/fmc_id_debug.ltx}
set_property PROBES.FILE $fmc_read_ltx $fmc_read_device
set_property FULL_PROBES.FILE $fmc_read_ltx $fmc_read_device
refresh_hw_device $fmc_read_device
set fmc_read_core [get_hw_ilas -quiet -of_objects $fmc_read_device -filter {CELL_NAME =~ *u_ila_fmc_bus*}]
if {[llength $fmc_read_core] != 1} { error "Expected exactly u_ila_fmc_bus" }
set fmc_read_data [upload_hw_ila_data $fmc_read_core]
set fmc_read_output [file join [file dirname [info script]] "captured_fmc_[clock format [clock seconds] -format %Y%m%d_%H%M%S].csv"]
write_hw_ila_data -csv_file $fmc_read_output $fmc_read_data
puts "FMC_CAPTURE_UPLOAD_OK=$fmc_read_output"
close_hw_target
disconnect_hw_server
close_hw_manager
exit
