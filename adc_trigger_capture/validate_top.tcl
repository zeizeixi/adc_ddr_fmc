set root $::env(TASK_TRIGGER_ROOT)
cd $root
file mkdir reports
create_project -in_memory -part xc7a200tfbg484-2
set_property XPM_LIBRARIES {XPM_CDC XPM_MEMORY XPM_FIFO} [current_project]
foreach n {reset_sync level_sync cdc_mailbox ads62p24_init ram256x16_8k readout_debug adc_clock_forward_7series} {
    read_verilog $root/reference/$n.v
}
foreach n {trigger_geometry ads62p24_pack_runtime mig_write_runtime adc_capture_runtime ddr_block_reader adc_record_store fmc_record_link adc_ddr_fbg484_top} {
    read_verilog $root/rtl/$n.v
}
set previous {./local_inputs/sources_1}
read_verilog $previous/imports/rtl/fmc_sdram_sync.v
foreach n {adc_fifo_256x512 adc_raw_ila capture_clocks capture_vio readout_vio mig_7series_0} {
    read_ip $previous/ip/$n/$n.xci
}
synth_design -rtl -top adc_ddr_fbg484_top -part xc7a200tfbg484-2
puts "TRIGGER_BOARD_TOP_ELABORATION_PASS"
close_project
exit
