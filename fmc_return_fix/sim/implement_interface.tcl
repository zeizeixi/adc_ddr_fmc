set fix_root [file normalize [file join [file dirname [info script]] ..]]
set reference_root [file normalize [file join $fix_root .. fmc_srcc]]
create_project -in_memory -part xc7a200tfbg484-2
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
read_verilog $fix_root/rtl/fmc_sdram_sync.v
read_verilog $reference_root/rtl/fmc_record_link.v
read_verilog [list $reference_root/sim/fmc_test_system.v $reference_root/sim/ddr_block_reader.v $reference_root/sim/ram256x16_8k.v $reference_root/sim/cdc_mailbox.v $reference_root/sim/level_sync.v $reference_root/sim/reset_sync.v]
read_xdc $fix_root/fmc_interface.xdc
read_xdc {./local_inputs/runtime_cdc.xdc}
synth_design -top fmc_test_system -part xc7a200tfbg484-2
create_clock -name fmc_read_sample -period 17.857 -waveform {0.000 8.929}
set_output_delay -clock fmc_read_sample -max 2.500 [get_ports {MCU_FMC_D[*]}]
set_output_delay -clock fmc_read_sample -min -0.500 [get_ports {MCU_FMC_D[*]}]
create_clock -name ui_clk -period 10.000 [get_ports ui_clk]
set_property PACKAGE_PIN R4 [get_ports ui_clk]
set_property IOSTANDARD LVCMOS15 [get_ports ui_clk]
set_property PACKAGE_PIN U7 [get_ports reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports reset_n]
set_false_path -from [get_ports reset_n]
opt_design
place_design
phys_opt_design
route_design
report_timing_summary -file $fix_root/reports/interface_routed_timing.rpt
report_timing -to [get_ports {MCU_FMC_D[*]}] -max_paths 5 -file $fix_root/reports/interface_output_paths.rpt
report_timing -to [get_ports {MCU_FMC_D[*]}] -delay_type min -max_paths 5 -file $fix_root/reports/interface_output_hold.rpt
report_drc -file $fix_root/reports/interface_drc.rpt
write_checkpoint -force $fix_root/reports/interface_routed.dcp
puts {FMC_RETURN_INTERFACE_ROUTED}
close_project
exit
