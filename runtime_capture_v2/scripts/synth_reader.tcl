# Synthesize the new read engine with actual XPM block RAM, independently of MIG.
# Pass a fresh report directory. Does not open/modify the user's board project.
if {[llength $argv]!=1} {error "Pass a fresh report directory"}
set out [string map {\\ /} [lindex $argv 0]]
if {[file exists $out]} {error "Report directory exists"}
file mkdir $out
set root [file dirname [file dirname [info script]]]
create_project -in_memory -part xc7a200tfbg484-2
set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
foreach name {cdc_mailbox.v level_sync.v ram256x16_8k.v ddr_block_reader.v} {
    read_verilog [file join $root rtl $name]
}
synth_design -top ddr_block_reader -part xc7a200tfbg484-2 -mode out_of_context -flatten_hierarchy none
create_clock -name ui_clk -period 10 [get_ports ui_clk]
create_clock -name rd_clk -period 13.4 [get_ports rd_clk]
read_xdc [file join $root constraints runtime_cdc.xdc]
set mails [get_cells -hier -filter {ORIG_REF_NAME == cdc_mailbox || REF_NAME == cdc_mailbox}]
if {[llength $mails]!=2} {error "Expected two mailbox instances, got $mails"}
foreach inst $mails {
    set src [get_cells -quiet -hier -filter "NAME =~ ${inst}/payload_hold_reg*"]
    set dst [get_cells -quiet -hier -filter "NAME =~ ${inst}/dst_data_reg*"]
    if {![llength $src] || ![llength $dst]} {error "Mailbox timing endpoints missing: $inst"}
    puts "Mailbox endpoints: $inst source=[llength $src] destination=[llength $dst]"
}
set boxes [get_cells -hier -filter {IS_BLACKBOX == 1}]
if {[llength $boxes]} {error "Unresolved black boxes: $boxes"}
report_utilization -file [file join $out utilization.rpt]
report_cdc -details -file [file join $out cdc.rpt]
report_exceptions -file [file join $out exceptions.rpt]
set paths [get_timing_paths -from [get_cells -hier -filter {NAME =~ */payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */dst_data_reg*}] -max_paths 200]
if {[llength $paths]!=111} {error "Expected 111 constrained mailbox paths"}
foreach p $paths {
    if {[get_property REQUIREMENT $p]!=10.0} {error "Mailbox path missing 10 ns requirement"}
}
write_checkpoint [file join $out reader_synth.dcp]
puts "PASS reader synthesis: FBG484, real XPM RAM, no unresolved black boxes, both mailbox timing endpoints found"
close_project
exit
