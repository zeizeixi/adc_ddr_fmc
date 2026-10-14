# Local verification only; never opens or changes the user's .xpr.
if {[info exists ::env(TASK_TRIGGER_ROOT)]} {
    set root $::env(TASK_TRIGGER_ROOT)
} else {
    set root [file dirname [file normalize [info script]]]
}
cd $root
file mkdir reports
create_project -in_memory -part xc7a200tfbg484-2
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach n {reset_sync level_sync cdc_mailbox ads62p24_init ram256x16_8k readout_debug adc_clock_forward_7series} {
    read_verilog $root/reference/$n.v
}
read_verilog $root/sim/simulation_support.v
foreach n {trigger_geometry ads62p24_pack_runtime mig_write_runtime adc_capture_runtime ddr_block_reader adc_record_store fmc_record_link} {
    read_verilog $root/rtl/$n.v
}
synth_design -top adc_record_store -part xc7a200tfbg484-2 -mode out_of_context
create_clock -name ui_clk -period 10.000 [get_ports ui_clk]
create_clock -name adc_clk -period 10.000 [get_ports adc_clk_out]
create_clock -name rd_clk -period 17.857 [get_ports rd_clk]
set_max_delay -datapath_only 10.000 -from [get_cells -hier -filter {NAME =~ */payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */dst_data_reg*}]
set first_stages [get_cells -quiet -hier -regexp {.*(req_sync_reg\[0\]|ack_sync_reg\[0\]|sync_ff_reg\[0\])$}]
set_false_path -to [get_pins -of_objects $first_stages -filter {REF_PIN_NAME == D}]
report_utilization -file reports/capture_synthesis_utilization.rpt
report_timing_summary -max_paths 10 -file reports/capture_synthesis_timing.rpt
report_drc -file reports/capture_synthesis_drc.rpt
write_checkpoint -force reports/capture_synthesis.dcp
puts "TRIGGER_CAPTURE_SYNTHESIS_PASS"
close_project
exit
