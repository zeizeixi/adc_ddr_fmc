# Run in the separate adc_simple_test Vivado project.
if {[llength [get_projects -quiet]] != 1} {error "Open the test project first."}
if {[get_property PART [current_project]] ne "xc7a200tfbg484-2"} {error "Expected xc7a200tfbg484-2."}
if {[llength [get_ips -quiet adc_simple_ila]] != 0} {
    error "adc_simple_ila exists. Inspect it; retry generate_target only after fixing any error."
}
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name adc_simple_ila
set_property -dict [list CONFIG.C_NUM_OF_PROBES {2} CONFIG.C_DATA_DEPTH {2048} CONFIG.C_INPUT_PIPE_STAGES {0} CONFIG.C_PROBE0_WIDTH {12} CONFIG.C_PROBE1_WIDTH {12}] [get_ips adc_simple_ila]
generate_target all [get_ips adc_simple_ila]
