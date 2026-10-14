# Run from the Tcl Console with the intended Vivado project open.
# IP is created in that project's own sources directory.
if {[llength [get_projects -quiet]] != 1} {
    error "Open the ad_collect project first."
}
if {[get_property PART [current_project]] ne "xc7a200tfbg484-2"} {
    error "Expected xc7a200tfbg484-2; no IP was changed."
}
if {[llength [get_ips -quiet adc_raw_ila]] != 0} {
    error "adc_raw_ila already exists; inspect it instead of overwriting it."
}
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name adc_raw_ila
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES {6} \
    CONFIG.C_DATA_DEPTH {2048} \
    CONFIG.C_INPUT_PIPE_STAGES {0} \
    CONFIG.C_PROBE0_WIDTH {12} \
    CONFIG.C_PROBE1_WIDTH {12} \
    CONFIG.C_PROBE2_WIDTH {12} \
    CONFIG.C_PROBE3_WIDTH {12} \
    CONFIG.C_PROBE4_WIDTH {1} \
    CONFIG.C_PROBE5_WIDTH {1}] [get_ips adc_raw_ila]
generate_target all [get_ips adc_raw_ila]
puts "adc_raw_ila generated: probes 12/12/12/12/1/1, depth 2048."
