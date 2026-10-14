# Run from Tcl Console with the user's normal project open.
# A separate implementation run reuses completed synth_1. No RTL/XDC replacement.
set fmc_debug_folder [file dirname [file normalize [info script]]]
if {[llength [get_projects -quiet]] != 1} { error "Open your FMC project first." }
set fmc_debug_parent [get_runs -quiet synth_1]
set fmc_debug_reference [get_runs -quiet impl_1]
if {[llength $fmc_debug_parent] != 1 || [llength $fmc_debug_reference] != 1} {
    error "FMC_ILA: synth_1 and impl_1 must exist in this project."
}
if {![string match {*Complete*} [get_property STATUS $fmc_debug_parent]]} {
    error "FMC_ILA: run synthesis successfully first."
}
if {[get_property NEEDS_REFRESH $fmc_debug_parent]} {
    error "FMC_ILA: synthesis is out of date. Run synthesis again before adding probes."
}
set fmc_debug_name "impl_fmc_ila_[clock format [clock seconds] -format %Y%m%d_%H%M%S]"
if {[llength [get_runs -quiet $fmc_debug_name]]} { error "FMC_ILA: duplicate run name; try again later." }
create_run $fmc_debug_name -parent_run synth_1 \
    -flow [get_property FLOW $fmc_debug_reference] \
    -strategy [get_property STRATEGY $fmc_debug_reference] \
    -constrset [get_property CONSTRSET $fmc_debug_reference]
set fmc_debug_run [get_runs $fmc_debug_name]
# Preserve original implementation hook behavior, then append our hooks.
foreach step {OPT_DESIGN PLACE_DESIGN PHYS_OPT_DESIGN ROUTE_DESIGN WRITE_BITSTREAM} {
    foreach kind {PRE POST} {
        set property "STEPS.${step}.TCL.${kind}"
        set original [get_property $property $fmc_debug_reference]
        if {$original ne ""} { set_property $property $original $fmc_debug_run }
    }
}
foreach item {{OPT_DESIGN PRE insert_fmc_ila.tcl} {OPT_DESIGN POST constrain_watch_inputs.tcl} {WRITE_BITSTREAM POST finish_fmc_ila.tcl}} {
    lassign $item step kind script
    set property "STEPS.${step}.TCL.${kind}"
    set previous [get_property $property $fmc_debug_run]
    set hook [file join $fmc_debug_folder $script]
    if {$previous ne ""} {
        set wrapper [file join $fmc_debug_folder "${fmc_debug_name}_${step}_${kind}.tcl"]
        set channel [open $wrapper w]
        puts $channel [list source $previous]
        puts $channel [list source $hook]
        close $channel
        set hook $wrapper
    }
    set_property $property $hook $fmc_debug_run
}
puts "FMC_ILA: separate run = $fmc_debug_name"
puts "FMC_ILA: outputs = [get_property DIRECTORY $fmc_debug_run]"
puts "FMC_ILA: keep this script folder in place until the run completes."
launch_runs $fmc_debug_name -to_step write_bitstream -jobs 4
