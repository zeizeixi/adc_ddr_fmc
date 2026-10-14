# WRITE_BITSTREAM POST hook: .ltx must come from the same implemented design.
write_debug_probes -force [file join [pwd] fmc_id_debug.ltx]
report_timing_summary -file [file join [pwd] fmc_ila_timing.rpt]
report_bus_skew -file [file join [pwd] fmc_ila_bus_skew.rpt]
report_cdc -details -file [file join [pwd] fmc_ila_cdc.rpt]
puts "FMC_ILA_BUILD_OK: use this run's .bit and fmc_id_debug.ltx together."
