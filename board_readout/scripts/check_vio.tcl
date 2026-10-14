if {[llength $argv]!=1} {error "Pass a new check project directory"}
set dest [lindex $argv 0]
if {[file exists $dest]} {error "Check directory already exists"}
create_project readout_check $dest -part xc7a200tfbg484-2
source [file join [file dirname [info script]] create_readout_vio.tcl]
set ip [get_ips readout_vio]
set n 0
foreach width {16 32 32 14 16 32 32 32} {
    if {[get_property CONFIG.C_PROBE_IN${n}_WIDTH $ip]!=$width} {error "Probe input width mismatch"}
    incr n
}
set n 0
foreach width {1 12 1 1 1} {
    if {[get_property CONFIG.C_PROBE_OUT${n}_WIDTH $ip]!=$width} {error "Probe output width mismatch"}
    incr n
}
puts "PASS actual readout_vio: generated with all expected widths"
close_project
exit
