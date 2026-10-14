# Run with the existing FBG484 project open. Creates only the additional VIO.
if {[get_property PART [current_project]] ne "xc7a200tfbg484-2"} {error "Expected xc7a200tfbg484-2"}
if {[llength [get_ips -quiet readout_vio]]} {error "readout_vio exists; inspect it instead of overwriting"}
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name readout_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {8} CONFIG.C_NUM_PROBE_OUT {5} \
    CONFIG.C_PROBE_IN0_WIDTH {16} CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_IN2_WIDTH {32} CONFIG.C_PROBE_IN3_WIDTH {14} \
    CONFIG.C_PROBE_IN4_WIDTH {16} CONFIG.C_PROBE_IN5_WIDTH {32} \
    CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {1} CONFIG.C_PROBE_OUT1_WIDTH {12} \
    CONFIG.C_PROBE_OUT2_WIDTH {1} CONFIG.C_PROBE_OUT3_WIDTH {1} CONFIG.C_PROBE_OUT4_WIDTH {1} \
    CONFIG.C_PROBE_OUT0_INIT_VAL {0x0} CONFIG.C_PROBE_OUT1_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT2_INIT_VAL {0x0} CONFIG.C_PROBE_OUT3_INIT_VAL {0x0} \
    CONFIG.C_PROBE_OUT4_INIT_VAL {0x0}] [get_ips readout_vio]
set libs [get_property XPM_LIBRARIES [current_project]]
if {[lsearch -exact $libs XPM_MEMORY]<0} {lappend libs XPM_MEMORY}
set_property XPM_LIBRARIES $libs [current_project]
generate_target all [get_ips readout_vio]
puts "PASS readout_vio generated in the current project; original IPs unchanged"
