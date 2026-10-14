# Vivado 2023.2. Creates a NEW FBG484 project; refuses to overwrite a directory.
# Usage: vivado -mode batch -source create_project.tcl -tclargs <new_dir> [vendor_dir]
if {[llength $argv]<1 || [llength $argv]>2} {error "Pass new project directory and optional vendor directory"}
set root [file dirname [file dirname [info script]]]
set dest [string map {\\ /} [lindex $argv 0]]
set vendor {./local_inputs/36_top_ddr3_rw}
if {[llength $argv]==2} {set vendor [string map {\\ /} [lindex $argv 1]]}
if {[file exists $dest]} {error "Destination already exists; choose a new directory"}
set mig_src [file join $vendor prj top_ddr3_rw.srcs sources_1 ip mig_7series_0_1]
foreach name {mig_7series_0.xci mig_b.prj mig_a.prj} {
    if {![file exists [file join $mig_src $name]]} {error "Missing vendor MIG file: $name"}
}
create_project adc_runtime $dest -part xc7a200tfbg484-2
set_property target_language Verilog [current_project]
# import_files copies sources into new project. Existing encrypted project is unused.
import_files -norecurse [glob [file join $root rtl *.v]]
set_property top adc_ddr_fbg484_top [get_filesets sources_1]
source [file join $root scripts create_fifo_ip.tcl]
# Read only a PRIVATE COPY of the valid MIG and its project files.
set mig_copy [file join $dest private_ip mig_7series_0_1]
file mkdir $mig_copy
foreach name {mig_7series_0.xci mig_b.prj mig_a.prj} {file copy [file join $mig_src $name] [file join $mig_copy $name]}
import_ip -files [list [file join $mig_copy mig_7series_0.xci]]
# Keep the selected XML project next to the imported XCI even across tool versions.
set imported_mig_dir [file dirname [get_property IP_FILE [get_ips mig_7series_0]]]
foreach name {mig_b.prj mig_a.prj} {
    if {![file exists [file join $imported_mig_dir $name]]} {
        file copy [file join $mig_copy $name] [file join $imported_mig_dir $name]
    }
}
generate_target all [get_ips mig_7series_0]
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name capture_clocks
set_property -dict [list CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200.000} \
    CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {100.000} CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.USE_RESET {true} CONFIG.USE_LOCKED {true}] [get_ips capture_clocks]
generate_target all [get_ips capture_clocks]
create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name capture_vio
set_property -dict [list CONFIG.C_NUM_PROBE_IN {9} CONFIG.C_NUM_PROBE_OUT {3} \
    CONFIG.C_PROBE_IN5_WIDTH {32} CONFIG.C_PROBE_IN6_WIDTH {32} CONFIG.C_PROBE_IN7_WIDTH {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {32} CONFIG.C_PROBE_OUT0_INIT_VAL {0x01312D00} \
    CONFIG.C_PROBE_OUT1_WIDTH {1} CONFIG.C_PROBE_OUT2_WIDTH {1}] [get_ips capture_vio]
generate_target all [get_ips capture_vio]
import_files -fileset constrs_1 [file join $vendor prj top_ddr3_rw.srcs constrs_1 new top.xdc]
import_files -fileset constrs_1 [file join $root constraints runtime_cdc.xdc]
set_property USED_IN_SYNTHESIS false [get_files runtime_cdc.xdc]
set_property PROCESSING_ORDER LATE [get_files runtime_cdc.xdc]
update_compile_order -fileset sources_1
report_ip_status -file [file join $dest ip_status.rpt]
puts "Created FBG484 project. ADC pin/timing constraints are still required. No bitstream was built."
close_project
exit
