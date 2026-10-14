open_checkpoint {./local_inputs/adc_ddr_fbg484_top.dcp}
puts "CURRENT_PART [get_property PART [current_design]]"
puts "CURRENT_SDCLK_PIN [get_property PACKAGE_PIN [get_ports MCU_FMC_SDCLK]]"
puts "CURRENT_CLOCK_NETS [get_nets -quiet {clk_100m fmc_clk ui_clk}]"
puts "CURRENT_BLACKBOXES [get_cells -hier -filter {IS_BLACKBOX == 1}]"
source {./local_inputs/insert_fmc_ila.tcl}
puts "CURRENT_PROJECT_PROBE_INSERT_PASS"
close_design
