set root {./local_inputs/fmc_10mhz}
create_project -in_memory -part xc7a200tfbg484-2
read_verilog [file join $root rtl fmc_sdram_port.v]
synth_design -top fmc_sdram_port -part xc7a200tfbg484-2
create_clock -name ui_clk -period 10 [get_ports clk]
set_max_delay -datapath_only 10.000 -to [get_ports {dq[*]}]
report_utilization -file [file join $root reports fmc_sdram_port_utilization.rpt]
report_timing_summary -file [file join $root reports fmc_sdram_port_synth_timing.rpt]
write_checkpoint -force [file join $root reports fmc_sdram_port_synth.dcp]
puts {FMC_PORT_SYNTH_PASS}
close_project
