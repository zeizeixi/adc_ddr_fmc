# Bundled-data mailbox contract: data held through request/ack transaction.
# Receiver waits >= 3 synchronizer + 2 settling cycles before capturing bus.
# Bound every payload bit to 10 ns, one nominal 100 MHz clock period.
# Do NOT replace these bounds with a blanket asynchronous clock-group exception.
foreach inst [get_cells -hier -filter {ORIG_REF_NAME == cdc_mailbox || REF_NAME == cdc_mailbox}] {
    set src [get_cells -quiet -hier -filter "NAME =~ ${inst}/payload_hold_reg*"]
    set dst [get_cells -quiet -hier -filter "NAME =~ ${inst}/dst_data_reg*"]
    if {[llength $src] && [llength $dst]} {
        set_max_delay -datapath_only 10.000 -from $src -to $dst
        set_bus_skew 10.000 -from $src -to $dst
    }
}
# Cut only asynchronous inputs of explicit single-bit synchronization chains.
set first_stages [get_cells -quiet -hier -regexp {.*(req_sync_reg\[0\]|ack_sync_reg\[0\]|sync_ff_reg\[0\])$}]
if {[llength $first_stages]} {
    set_false_path -to [get_pins -of_objects $first_stages -filter {REF_PIN_NAME == D}]
}
# level_sync uses its own sync_ff shift chain; FIFO carries its generated XDC.
