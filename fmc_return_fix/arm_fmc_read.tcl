# Optional: run in Hardware Manager AFTER programming matching .bit/.ltx.
# Intended for fresh default capture/trigger settings. GUI remains available.
set fmc_capture_ila [get_hw_ilas -quiet -filter {CELL_NAME =~ *u_ila_fmc_bus*}]
if {[llength $fmc_capture_ila] != 1} { error "Load the new bit AND its matching LTX, then refresh the device." }
foreach spec {{command_q eq3'b101} {cke_q eq1'b1} {cs_q eq1'b0}} {
    lassign $spec signal compare
    set matches [get_hw_probes -quiet -of_objects $fmc_capture_ila -filter "NAME =~ *${signal}*"]
    if {[llength $matches] != 1} { error "Cannot uniquely find $signal. Use probe_map and set trigger in GUI." }
    set_property TRIGGER_COMPARE_VALUE $compare $matches
}
set_property CONTROL.TRIGGER_CONDITION AND $fmc_capture_ila
set_property CONTROL.TRIGGER_POSITION 1024 $fmc_capture_ila
run_hw_ila $fmc_capture_ila
puts "FMC_ILA: armed for READ (101), CKE=1, CS_n=0. Now re-run STM32 FMC initialization / ID read."
