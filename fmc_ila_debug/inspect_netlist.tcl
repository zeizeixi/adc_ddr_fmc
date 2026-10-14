open_checkpoint {./local_inputs/interface_routed.dcp}
foreach path {u_fmc_port/clk u_fmc_port/register_data u_fmc_port/register_data[0] u_fmc_port/bus_read u_fmc_port/bus_addr[0] u_fmc_port/mode_valid u_fmc_port/drive_data_reg[0]/Q u_fmc_port/command_q_reg[0]/Q u_fmc_port/drive_tristate_reg[0]/Q} {
    set matches [get_pins -quiet $path]
    puts "PIN $path = $matches NET = [get_nets -quiet -of_objects $matches]"
}
puts "CLOCKS [get_nets -quiet {fmc_clk ui_clk clk_100m}]"
foreach pattern {*bus_read* *bus_write* *bus_addr* *register_data* *mode_valid* *protocol_error* *drive_data* *row_open* *data_q* *fmc_rst*} {
    puts "NETS $pattern = [get_nets -hierarchical -quiet $pattern]"
}
puts "DEBUG [get_debug_cores -quiet]"
puts [help write_xdc]
puts [help create_debug_core]
close_design
