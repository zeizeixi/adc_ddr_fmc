# User-invoked programming helper. Uses this package's matching BIT/LTX pair.
set fmc_program_root [file dirname [file normalize [info script]]]
set fmc_program_bit [file join $fmc_program_root hardware adc_ddr_fbg484_top.bit]
set fmc_program_ltx [file join $fmc_program_root hardware fmc_id_debug.ltx]
if {![file exists $fmc_program_bit] || ![file exists $fmc_program_ltx]} {
    error "Missing matching BIT/LTX. Do not substitute an older implementation's BIT."
}
set fmc_program_device [get_hw_devices -quiet xc7a200t_0]
if {[llength $fmc_program_device] != 1} { error "Connect the xc7a200t_0 hardware target first" }
current_hw_device $fmc_program_device
set_property PROGRAM.FILE $fmc_program_bit $fmc_program_device
set_property PROBES.FILE $fmc_program_ltx $fmc_program_device
set_property FULL_PROBES.FILE $fmc_program_ltx $fmc_program_device
program_hw_devices $fmc_program_device
refresh_hw_device $fmc_program_device
foreach core [get_hw_ilas -quiet -of_objects $fmc_program_device] {
    puts "$core : [get_property CELL_NAME $core]"
}
puts "FMC_RETURN_PROGRAMMED: reset STM32 now, then run FREG. Keep CAS3/RPIPE2/RBURST0."
