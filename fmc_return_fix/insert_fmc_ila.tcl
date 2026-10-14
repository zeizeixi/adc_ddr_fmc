# Vivado 2023.2 implementation PRE-OPT hook. No functional RTL is changed.
# All required nets are resolved before creating cores. Never guess missing bits.
namespace eval fmc_id_debug {
    variable folder [file dirname [file normalize [info script]]]
    variable mapping {}
}

proc fmc_id_debug::one_net {names} {
    foreach name $names {
        set found [get_nets -quiet $name]
        if {[llength $found] == 1} { return [lindex $found 0] }
    }
    error "FMC_ILA: required net missing: $names. Use the J20 fmc_sdram_sync version."
}

proc fmc_id_debug::register_net {name width} {
    set result {}
    # The corrected interface uses the existing registered RAM/register output
    # directly. drive_data is now a KEEP fabric net, not an extra I/O data FF.
    if {$name eq "drive_data" && [llength [get_cells -quiet {u_fmc_port/drive_data_reg[0]}]] == 0} {
        for {set bit 0} {$bit < $width} {incr bit} {
            set wire_name [format {u_fmc_port/drive_data[%d]} $bit]
            set found [get_nets -quiet $wire_name]
            if {[llength $found] != 1} { error "FMC_ILA: response wire missing: $wire_name" }
            lappend result [lindex $found 0]
        }
        return $result
    }
    for {set bit 0} {$bit < $width} {incr bit} {
        if {$width == 1} { set cell "u_fmc_port/${name}_reg" } else {
            set cell [format {u_fmc_port/%s_reg[%d]} $name $bit]
        }
        set pin [get_pins -quiet "${cell}/Q"]
        set nets [get_nets -quiet -of_objects $pin]
        if {[llength $nets] != 1} {
            error "FMC_ILA: required register Q missing: $cell. No core was added."
        }
        if {$name eq "drive_data" || $name eq "drive_tristate"} {
            # I/O-register Q cannot route to ILA. Mirror its real C/D/CE/reset
            # nets into a protected fabric register; do not move the pin FF.
            set original [get_cells $cell]
            set shadow [format {fmc_ila_shadow_%s_reg[%d]} $name $bit]
            create_cell -reference [get_property REF_NAME $original] $shadow
            set clone [get_cells $shadow]
            set_property IOB FALSE $clone
            set_property DONT_TOUCH TRUE $clone
            foreach property {INIT IS_C_INVERTED IS_D_INVERTED IS_R_INVERTED IS_S_INVERTED IS_CLR_INVERTED IS_PRE_INVERTED} {
                if {[lsearch -exact [list_property $original] $property] >= 0} {
                    set_property $property [get_property $property $original] $clone
                }
            }
            foreach input [get_pins -of_objects $original -filter {DIRECTION == IN}] {
                set input_net [get_nets -quiet -of_objects $input]
                if {[llength $input_net] != 1} { error "FMC_ILA: unconnected shadow source $input" }
                set clone_pin [get_pins "${shadow}/[get_property REF_PIN_NAME $input]"]
                connect_net -hier -net $input_net -objects $clone_pin
                if {[llength [get_nets -quiet -of_objects $clone_pin]] != 1} {
                    error "FMC_ILA: shadow input was not connected: $clone_pin"
                }
            }
            set shadow_net [format {fmc_ila_%s_shadow[%d]} $name $bit]
            create_net $shadow_net
            connect_net -net [get_nets $shadow_net] -objects [get_pins "${shadow}/Q"]
            set nets [get_nets $shadow_net]
        }
        lappend result [lindex $nets 0]
    }
    return $result
}

proc fmc_id_debug::input_net {name width} {
    set result {}
    for {set bit 0} {$bit < $width} {incr bit} {
        if {$width == 1} { set port $name } else { set port [format {%s[%d]} $name $bit] }
        set pads [get_ports -quiet $port]
        set nets [get_nets -quiet -of_objects $pads]
        if {[llength $nets] != 1} { error "FMC_ILA: input port missing: $port" }
        # Tap the existing IBUF output rather than the physical pad-side net.
        set buffers [get_cells -quiet -of_objects $nets -filter {REF_NAME == IBUF}]
        set outputs [get_pins -quiet -of_objects $buffers -filter {REF_PIN_NAME == O}]
        set buffered [get_nets -quiet -of_objects $outputs]
        if {[llength $buffered] != 1} {
            error "FMC_ILA: could not identify the existing input buffer for $port"
        }
        lappend result [lindex $buffered 0]
    }
    return $result
}

proc fmc_id_debug::make_core {name clock depth probes} {
    variable mapping
    create_debug_core $name ila
    set core [get_debug_cores $name]
    set_property C_DATA_DEPTH $depth $core
    set_property C_INPUT_PIPE_STAGES 1 $core
    set_property C_TRIGIN_EN false $core
    set_property C_TRIGOUT_EN false $core
    set_property C_ADV_TRIGGER false $core
    set_property ALL_PROBE_SAME_MU true $core
    set_property ALL_PROBE_SAME_MU_CNT 1 $core
    set_property port_width 1 [get_debug_ports "${name}/clk"]
    connect_debug_port "${name}/clk" $clock
    set index 0
    foreach probe $probes {
        lassign $probe label nets
        if {$index != 0} { create_debug_port $name probe }
        set port "${name}/probe${index}"
        set_property port_width [llength $nets] [get_debug_ports $port]
        set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports $port]
        connect_debug_port $port $nets
        lappend mapping [list $name $index $label [llength $nets] $nets]
        puts "FMC_ILA: $port = $label ([llength $nets] bits)"
        incr index
    }
}

proc fmc_id_debug::insert {} {
    variable folder
    variable mapping
    foreach name {u_ila_fmc_bus u_ila_fmc_watch} {
        if {[llength [get_debug_cores -quiet $name]]} { error "FMC_ILA: $name already exists" }
    }
    set fmc_clock [one_net {fmc_clk}]
    # Production: Clocking Wizard out2=100 MHz, independent of incoming FMC.
    # ui_clk is a fallback for the independent validation harness only.
    set monitor_clock [one_net {clk_100m ui_clk_IBUF_BUFG}]
    set reset [one_net {fmc_rst}]
    set specs {
        {command_q 3} {cke_q 1} {cs_q 1} {addr_q 13} {bank_q 2}
        {mask_q 2} {mode_valid_o 1} {protocol_error_o 1}
        {row_open 4} {row_first 13} {row_second 13} {row_third 13} {row_fourth 13}
        {register_first 16} {register_second 16} {drive_data 16}
        {drive_tristate 16} {data_q 16} {read_pipe 2} {memory_pipe 2}
    }
    set bus_probes {}
    foreach spec $specs {
        lassign $spec label width
        lappend bus_probes [list $label [register_net $label $width]]
    }
    lappend bus_probes [list fmc_rst [list $reset]]
    set watch_probes [list [list fmc_clk_async [list $fmc_clock]] [list fmc_rst_async [list $reset]]]
    foreach spec {
        {MCU_FMC_SDCKE1 1} {MCU_FMC_SDNE1 1} {MCU_FMC_SDNRAS 1}
        {MCU_FMC_SDNCAS 1} {MCU_FMC_SDNWE 1} {MCU_FMC_A 13}
        {MCU_FMC_BA 2} {MCU_FMC_NBL 2}
    } {
        lassign $spec label width
        lappend watch_probes [list "${label}_async" [input_net $label $width]]
    }
    foreach label {locked ui_rst calib} {
        set net [get_nets -quiet $label]
        if {[llength $net] == 1} { lappend watch_probes [list "${label}_async" $net] }
    }
    # Preflight above is complete: every required probe is a real net, LSB first.
    make_core u_ila_fmc_bus $fmc_clock 4096 $bus_probes
    make_core u_ila_fmc_watch $monitor_clock 2048 $watch_probes
    set hub [get_debug_cores -quiet dbg_hub]
    if {[llength $hub] != 1} { error "FMC_ILA: debug hub was not created" }
    set_property C_CLK_INPUT_FREQ_HZ 100000000 $hub
    set_property C_ENABLE_CLK_DIVIDER false $hub
    disconnect_debug_port dbg_hub/clk
    connect_debug_port dbg_hub/clk $monitor_clock
    set output [open [file join [pwd] fmc_ila_probe_map.tsv] w]
    puts $output "core\tprobe\tlabel\twidth\tnets_lsb_first"
    foreach entry $mapping { puts $output [join $entry "\t"] }
    close $output
    puts "FMC_ILA_INSERT_OK: two cores, existing ADC/DDR/VIO preserved."
}
fmc_id_debug::insert
