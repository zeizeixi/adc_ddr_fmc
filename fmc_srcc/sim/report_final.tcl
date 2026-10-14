set root {./local_inputs/fmc_srcc}
open_checkpoint $root/reports/interface_routed.dcp
report_bus_skew -file $root/reports/interface_bus_skew.rpt
report_timing -from [get_ports {MCU_FMC_A[*] MCU_FMC_BA[*] MCU_FMC_NBL[*] MCU_FMC_D[*] MCU_FMC_SDCKE1 MCU_FMC_SDNE1 MCU_FMC_SDNRAS MCU_FMC_SDNCAS MCU_FMC_SDNWE}] -max_paths 5 -file $root/reports/interface_input_paths.rpt
report_timing -to [get_ports {MCU_FMC_D[*]}] -max_paths 5 -file $root/reports/interface_output_paths.rpt
report_exceptions -file $root/reports/interface_exceptions.rpt
close_design
