# ADC A/B data pin replacement only; NOT a complete board XDC.
# Replace old ADC_DA[2:13] and ADC_DB[2:13] PACKAGE_PIN assignments.
# Do not append while keeping conflicting old assignments.
# Checked against supplied baseboard, core connector and FPGA bank schematics.
# ADC_DA_0/1 and ADC_DB_0/1 are NC for ADS62P24 and are not ports.

set_property PACKAGE_PIN L16 [get_ports {ADC_DA[2]}] ; # J1-46 -> B15_L23_P -> L16
set_property PACKAGE_PIN K16 [get_ports {ADC_DA[3]}] ; # J1-44 -> B15_L23_N -> K16
set_property PACKAGE_PIN K19 [get_ports {ADC_DA[4]}] ; # J1-40 -> B15_L13_N -> K19
set_property PACKAGE_PIN L13 [get_ports {ADC_DA[5]}] ; # J1-36 -> B15_L20_N -> L13
set_property PACKAGE_PIN L15 [get_ports {ADC_DA[6]}] ; # J1-32 -> B15_L22_N -> L15
set_property PACKAGE_PIN K14 [get_ports {ADC_DA[7]}] ; # J1-28 -> B15_L19_N -> K14
set_property PACKAGE_PIN J15 [get_ports {ADC_DA[8]}] ; # J1-24 -> B15_L5_P -> J15
set_property PACKAGE_PIN J14 [get_ports {ADC_DA[9]}] ; # J1-20 -> B15_L3_P -> J14
set_property PACKAGE_PIN H13 [get_ports {ADC_DA[10]}] ; # J1-16 -> B15_L1_P -> H13
set_property PACKAGE_PIN J19 [get_ports {ADC_DA[11]}] ; # J1-12 -> B15_L12_P -> J19
set_property PACKAGE_PIN G16 [get_ports {ADC_DA[12]}] ; # J1-8 -> B15_L2_N -> G16
set_property PACKAGE_PIN G15 [get_ports {ADC_DA[13]}] ; # J1-6 -> B15_L2_P -> G15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[*]}]

set_property PACKAGE_PIN G21 [get_ports {ADC_DB[2]}] ; # J2-74 -> B16_L24_P -> G21
set_property PACKAGE_PIN F19 [get_ports {ADC_DB[3]}] ; # J2-70 -> B16_L18_P -> F19
set_property PACKAGE_PIN E14 [get_ports {ADC_DB[4]}] ; # J2-62 -> B16_L4_N -> E14
set_property PACKAGE_PIN E13 [get_ports {ADC_DB[5]}] ; # J2-60 -> B16_L4_P -> E13
set_property PACKAGE_PIN F13 [get_ports {ADC_DB[6]}] ; # J2-56 -> B16_L1_P -> F13
set_property PACKAGE_PIN B22 [get_ports {ADC_DB[7]}] ; # J2-52 -> B16_L20_N -> B22
set_property PACKAGE_PIN D20 [get_ports {ADC_DB[8]}] ; # J2-48 -> B16_L19_P -> D20
set_property PACKAGE_PIN C19 [get_ports {ADC_DB[9]}] ; # J2-44 -> B16_L13_N -> C19
set_property PACKAGE_PIN C18 [get_ports {ADC_DB[10]}] ; # J2-42 -> B16_L13_P -> C18
set_property PACKAGE_PIN B16 [get_ports {ADC_DB[11]}] ; # J2-40 -> B16_L7_N -> B16
set_property PACKAGE_PIN B15 [get_ports {ADC_DB[12]}] ; # J2-38 -> B16_L7_P -> B15
set_property PACKAGE_PIN C15 [get_ports {ADC_DB[13]}] ; # J2-36 -> B16_L3_N -> C15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[*]}]

# Verified ADC return clock: J1-4 -> B15_L4_N -> G18.
# Existing G18 PACKAGE_PIN and clock/timing constraints remain in the main XDC.
# This review does not sign off control pins, output clocks, DDR or timing.

