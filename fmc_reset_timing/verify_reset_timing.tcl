# Read-only checkpoint audit; original project and hardware files are not modified.
set root [file dirname [file normalize [info script]]]
open_checkpoint {./local_inputs/adc_ddr_fbg484_top_routed.dcp}
set audit [open [file join $root reset_structure.txt] w]
set presets {}
set outputs {}
set chain_inputs {}
foreach instance {u_fmc_reset u_store/u_rd_reset} {
    set shared_clock {}
    set shared_preset {}
    for {set stage 0} {$stage < 3} {incr stage} {
        set name [format {%s/sync_ff_reg[%d]} $instance $stage]
        set cell [get_cells -quiet $name]
        if {[llength $cell] != 1} { error "Missing register: $name" }
        if {[get_property REF_NAME $cell] ne "FDPE" || ![get_property ASYNC_REG $cell]} {
            error "Expected ASYNC_REG FDPE: $name"
        }
        set c [get_pins ${name}/C]
        set d [get_pins ${name}/D]
        set pre [get_pins ${name}/PRE]
        set clock_net [get_nets -of_objects $c]
        set pre_net [get_nets -of_objects $pre]
        set clocks [get_clocks -of_objects $c]
        if {[llength $clocks] != 1 || [get_property NAME $clocks] ne "fmc_sdclk"} {
            error "Unexpected reset clock: $name"
        }
        if {$stage == 0} {
            set shared_clock $clock_net
            set shared_preset $pre_net
        } elseif {$shared_clock ne $clock_net || $shared_preset ne $pre_net} {
            error "Clock/preset differs within reset chain: $name"
        }
        set drivers [get_pins -leaf -of_objects [get_nets -of_objects $d] -filter {DIRECTION == OUT}]
        if {[llength $drivers] != 1} { error "D must have one source: $name" }
        if {$stage == 0} {
            if {[get_property REF_NAME [get_cells -of_objects $drivers]] ne "GND"} {
                error "First stage must shift in zero: $name"
            }
        } else {
            set previous [format {%s/sync_ff_reg[%d]/Q} $instance [expr {$stage-1}]]
            if {[get_property NAME $drivers] ne $previous} { error "Chain topology differs: $name" }
            lappend chain_inputs $d
        }
        puts $audit "$name ASYNC_REG=TRUE clock=$clocks D=$drivers PRE=$pre_net LOC=[get_property LOC $cell]"
        lappend presets $pre
    }
    lappend outputs [get_pins [format {%s/sync_ff_reg[2]/Q} $instance]]
}
if {[llength $presets] != 6} { error "Expected six PRE inputs" }
set bad_before [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 32 -nworst 1]
puts $audit "negative_endpoints_before=[llength $bad_before]"
if {[llength $bad_before] != 6} { error "Different failure set; do not apply fix blindly" }
foreach path $bad_before {
    set endpoint [get_property ENDPOINT_PIN $path]
    puts $audit "BEFORE slack=[get_property SLACK $path] endpoint=$endpoint"
    if {[lsearch -exact $presets $endpoint] < 0} { error "Unexpected endpoint: $endpoint" }
}
report_timing -delay_type max -slack_lesser_than 0 -max_paths 32 -file [file join $root before_failures.rpt]
read_xdc [file join $root reset_cdc.xdc]
set bad_after [get_timing_paths -delay_type max -slack_lesser_than 0 -max_paths 32 -nworst 1]
set hold_after [get_timing_paths -delay_type min -slack_lesser_than 0 -max_paths 32 -nworst 1]
puts $audit "negative_endpoints_after=[llength $bad_after]"
puts $audit "negative_hold_endpoints_after=[llength $hold_after]"
puts $audit "WNS_after=[get_property SLACK [get_timing_paths -delay_type max -max_paths 1]]"
puts $audit "WHS_after=[get_property SLACK [get_timing_paths -delay_type min -max_paths 1]]"
set chain_paths [get_timing_paths -to $chain_inputs -delay_type max -max_paths 4 -nworst 1]
if {[llength $chain_paths] != 4} { error "Shift-chain timing was lost" }
puts $audit "timed_chain_endpoints=[llength $chain_paths]"
set release_paths [get_timing_paths -from $outputs -delay_type max -max_paths 16 -nworst 1]
if {[llength $release_paths] < 1} { error "Reset release timing was lost" }
puts $audit "timed_release_paths=[llength $release_paths]"
foreach path $release_paths {
    puts $audit "RELEASE slack=[get_property SLACK $path] endpoint=[get_property ENDPOINT_PIN $path]"
}
close $audit
report_timing_summary -file [file join $root after_timing_summary.rpt]
report_timing -to $chain_inputs -delay_type max -max_paths 4 -file [file join $root retained_reset_chain.rpt]
report_timing -from $outputs -delay_type max -max_paths 16 -file [file join $root retained_reset_release_setup.rpt]
report_timing -from $outputs -delay_type min -max_paths 16 -file [file join $root retained_reset_release_hold.rpt]
report_timing -to [get_ports {MCU_FMC_D[*]}] -delay_type max -max_paths 16 -file [file join $root fmc_output_setup.rpt]
report_timing -to [get_ports {MCU_FMC_D[*]}] -delay_type min -max_paths 16 -file [file join $root fmc_output_hold.rpt]
report_bus_skew -file [file join $root retained_bus_skew.rpt]
report_exceptions -coverage -file [file join $root exception_coverage.rpt]
report_cdc -details -file [file join $root cdc.rpt]
if {[llength $bad_after] || [llength $hold_after]} { error "Negative timing remains" }
puts "FMC_RESET_TIMING_PASS: six audited reset PRE inputs; chain and reset release remain timed"
close_design
exit
