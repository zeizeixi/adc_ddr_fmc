set root {./local_inputs/fmc_srcc}
create_project -in_memory -part xc7a200tfbg484-2
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
read_verilog [glob $root/rtl/fmc_*.v]
read_verilog [list $root/sim/fmc_test_system.v $root/sim/ddr_block_reader.v $root/sim/ram256x16_8k.v $root/sim/cdc_mailbox.v $root/sim/level_sync.v $root/sim/reset_sync.v]
read_xdc $root/fmc_interface.xdc
read_xdc {./local_inputs/runtime_cdc.xdc}
synth_design -top fmc_test_system -part xc7a200tfbg484-2
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
report_timing_summary -file $root/reports/interface_routed_timing.rpt
report_timing -delay_type max -max_paths 20 -file $root/reports/interface_setup_paths.rpt
report_timing -delay_type min -max_paths 10 -file $root/reports/interface_hold_paths.rpt
report_clock_utilization -file $root/reports/interface_clocks.rpt
report_cdc -details -file $root/reports/interface_cdc.rpt
report_drc -file $root/reports/interface_drc.rpt
report_utilization -file $root/reports/interface_utilization.rpt
write_checkpoint -force $root/reports/interface_routed.dcp
puts {FMC_INTERFACE_IMPLEMENTED}
close_project
