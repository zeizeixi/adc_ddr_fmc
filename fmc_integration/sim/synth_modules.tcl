set root {./local_inputs/fmc_integration}
foreach name {fmc_sdram_port fmc_record_regs} {
    create_project -in_memory -part xc7a200tfbg484-2
    read_verilog [file join $root rtl ${name}.v]
    synth_design -top $name -part xc7a200tfbg484-2
    create_clock -name ui_clk -period 10 [get_ports clk]
    report_utilization -file [file join $root reports ${name}_utilization.rpt]
    report_timing_summary -file [file join $root reports ${name}_synth_timing.rpt]
    write_checkpoint -force [file join $root reports ${name}_synth.dcp]
    close_project
}
