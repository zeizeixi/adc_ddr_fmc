# POST-OPT hook: only the asynchronous WATCH probe input pipeline is exempt.
# The native FMC ILA, functional CDC, and all downstream ILA logic remain timed.
set fmc_watch_probe_file [file join [pwd] fmc_ila_probe_map.tsv]
set fmc_watch_file [open $fmc_watch_probe_file r]
set fmc_watch_rows [split [read $fmc_watch_file] "\n"]
close $fmc_watch_file
set fmc_watch_count 0
foreach row [lrange $fmc_watch_rows 1 end] {
    if {$row eq ""} { continue }
    lassign [split $row "\t"] core probe label width names
    if {$core ne "u_ila_fmc_watch"} { continue }
    foreach name $names {
        set net [get_nets -segments -quiet $name]
        set candidates [get_pins -leaf -quiet -of_objects $net -filter \
            {DIRECTION == IN && REF_PIN_NAME == D && NAME =~ u_ila_fmc_watch/*}]
        if {[llength $candidates] == 0} {
            error "FMC_ILA: cannot isolate WATCH first-stage D pin for $label / $name"
        }
        set_false_path -to $candidates
        incr fmc_watch_count [llength $candidates]
    }
}
puts "FMC_ILA: exempted $fmc_watch_count asynchronous WATCH input D pins only."
