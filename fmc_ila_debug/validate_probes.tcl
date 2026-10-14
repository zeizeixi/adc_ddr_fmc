# Validation only; this independent checkpoint must never be programmed to the board.
open_checkpoint {./local_inputs/interface_routed.dcp}
source {./local_inputs/insert_fmc_ila.tcl}
report_debug_core
implement_debug_core
puts "FMC_ILA_EXTERNAL_CORE_VALIDATION_PASS"
close_design
