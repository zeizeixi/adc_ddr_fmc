# Build a separate project/run; never program hardware or replace original RTL.
set fmc_fix_root [file dirname [file normalize [info script]]]
set fmc_original_project {./local_inputs/ad_collect.xpr}
if {[llength $argv] > 0} { set fmc_original_project [lindex $argv 0] }
if {[llength [get_projects -quiet]] == 0} { open_project $fmc_original_project }
if {[llength [get_projects -quiet]] != 1} { error "Expected one FMC project" }
if {[get_property TOP [get_filesets sources_1]] ne "adc_ddr_fbg484_top"} {
    error "Expected the user's adc_ddr_fbg484_top project"
}
if {[get_property PART [current_project]] ne "xc7a200tfbg484-2"} {
    error "Expected XC7A200T-FBG484-2"
}
set fmc_clone_dir [file join $fmc_fix_root project]
if {[llength $argv] > 1} { set fmc_clone_dir [file normalize [lindex $argv 1]] }
if {[file exists [file join $fmc_clone_dir fmc_return_project.xpr]]} {
    error "Separate project already exists. Open it instead of rebuilding a copy."
}
save_project_as -force fmc_return_project $fmc_clone_dir
set fmc_old_rtl [get_files -quiet -filter {NAME =~ *fmc_sdram_sync.v}]
set fmc_old_xdc [get_files -quiet -filter {NAME =~ *fmc_interface.xdc}]
if {[llength $fmc_old_rtl] != 1 || [llength $fmc_old_xdc] != 1} {
    error "Expected one fmc_sdram_sync.v and one fmc_interface.xdc; no replacements made"
}
set fmc_manifest [open [file join $fmc_fix_root reports source_replacement.txt] w]
puts $fmc_manifest "original_project=$fmc_original_project"
puts $fmc_manifest "old_rtl=$fmc_old_rtl"
puts $fmc_manifest "old_xdc=$fmc_old_xdc"
close $fmc_manifest
remove_files $fmc_old_rtl
remove_files $fmc_old_xdc
add_files -norecurse -fileset sources_1 [file join $fmc_fix_root rtl fmc_sdram_sync.v]
add_files -norecurse -fileset constrs_1 [file join $fmc_fix_root fmc_interface.xdc]
update_compile_order -fileset sources_1
set fmc_synth_reference [get_runs synth_1]
set fmc_impl_reference [get_runs impl_1]
set fmc_synth_name synth_fmc_return
set fmc_impl_name impl_fmc_return
create_run $fmc_synth_name -flow [get_property FLOW $fmc_synth_reference] \
    -strategy [get_property STRATEGY $fmc_synth_reference] -srcset sources_1 -constrset constrs_1
create_run $fmc_impl_name -parent_run $fmc_synth_name \
    -flow [get_property FLOW $fmc_impl_reference] \
    -strategy [get_property STRATEGY $fmc_impl_reference] -constrset constrs_1
set fmc_impl_run [get_runs $fmc_impl_name]
foreach step {OPT_DESIGN PLACE_DESIGN PHYS_OPT_DESIGN ROUTE_DESIGN WRITE_BITSTREAM} {
    foreach kind {PRE POST} {
        set fmc_hook_property "STEPS.${step}.TCL.${kind}"
        set fmc_old_hook [get_property $fmc_hook_property $fmc_impl_reference]
        if {$fmc_old_hook ne ""} { set_property $fmc_hook_property $fmc_old_hook $fmc_impl_run }
    }
}
foreach item {{OPT_DESIGN PRE insert_fmc_ila.tcl} {OPT_DESIGN POST constrain_watch_inputs.tcl} {WRITE_BITSTREAM POST finish_fmc_ila.tcl}} {
    lassign $item step kind script
    set fmc_hook_property "STEPS.${step}.TCL.${kind}"
    set fmc_previous_hook [get_property $fmc_hook_property $fmc_impl_run]
    set fmc_new_hook [file join $fmc_fix_root $script]
    if {$fmc_previous_hook ne ""} {
        if {[string match {*insert_fmc_ila.tcl*} $fmc_previous_hook] ||
            [string match {*constrain_watch_inputs.tcl*} $fmc_previous_hook] ||
            [string match {*finish_fmc_ila.tcl*} $fmc_previous_hook]} {
            error "Original impl_1 has an FMC hook already; inspect before chaining it"
        }
        set fmc_wrapper [file join $fmc_fix_root "hook_${step}_${kind}.tcl"]
        set fmc_hook_channel [open $fmc_wrapper w]
        puts $fmc_hook_channel [list source $fmc_previous_hook]
        puts $fmc_hook_channel [list source $fmc_new_hook]
        close $fmc_hook_channel
        set fmc_new_hook $fmc_wrapper
    }
    set_property $fmc_hook_property $fmc_new_hook $fmc_impl_run
}
puts "FMC_RETURN_SYNTH_START: separate project $fmc_clone_dir"
launch_runs $fmc_synth_name -jobs 4
wait_on_run $fmc_synth_name
if {![string match {*Complete*} [get_property STATUS [get_runs $fmc_synth_name]]]} {
    error "FMC return synthesis did not complete"
}
puts "FMC_RETURN_IMPL_START"
launch_runs $fmc_impl_name -to_step write_bitstream -jobs 4
wait_on_run $fmc_impl_name
if {![string match {*write_bitstream Complete*} [get_property STATUS $fmc_impl_run]]} {
    error "FMC return implementation did not complete"
}
set fmc_built_dir [get_property DIRECTORY $fmc_impl_run]
set fmc_hardware_dir [file join $fmc_fix_root hardware]
file mkdir $fmc_hardware_dir
foreach filename {adc_ddr_fbg484_top.bit fmc_id_debug.ltx} {
    set source_file [file join $fmc_built_dir $filename]
    if {![file exists $source_file]} { error "Missing matching output: $source_file" }
    file copy -force $source_file [file join $fmc_hardware_dir $filename]
}
puts "FMC_RETURN_BUILD_COMPLETE=$fmc_hardware_dir"
close_project
exit
