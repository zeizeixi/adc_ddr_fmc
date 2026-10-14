# Read the user's completed routed checkpoint and LTX; do not change either.
set fmc_inspect_run {./local_inputs/impl_fmc_ila_20261009_085328}
open_checkpoint [file join $fmc_inspect_run adc_ddr_fbg484_top_routed.dcp]
puts "FMC_DEBUG_INSPECT_BEGIN"
foreach fmc_inspect_core [get_debug_cores -quiet] {
    puts "BUILT_CORE=$fmc_inspect_core"
}
set fmc_inspect_file [open [file join $fmc_inspect_run fmc_id_debug.ltx] r]
set fmc_inspect_text [read $fmc_inspect_file]
close $fmc_inspect_file
foreach fmc_inspect_name {u_ila_fmc_bus u_ila_fmc_watch u_adc_raw_ila} {
    puts "LTX_NAME=$fmc_inspect_name POSITION=[string first $fmc_inspect_name $fmc_inspect_text]"
}
puts "FMC_DEBUG_INSPECT_END"
close_design
exit
