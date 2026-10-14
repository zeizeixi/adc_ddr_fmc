set root {./local_inputs/fmc_srcc}
set debug {./local_inputs/fmc_ila_debug}
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
source $debug/insert_fmc_ila.tcl
opt_design
write_checkpoint -force $debug/validation_ila_opt.dcp
source $debug/constrain_watch_inputs.tcl
place_design
phys_opt_design
route_design
report_timing_summary -file $debug/validation_ila_timing.rpt
report_drc -file $debug/validation_ila_drc.rpt
report_utilization -file $debug/validation_ila_utilization.rpt
write_debug_probes -force $debug/validation_only.ltx
puts "FMC_ILA_ROUTE_VALIDATION_PASS"
close_design
