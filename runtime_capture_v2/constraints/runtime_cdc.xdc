# Bundled-data mailbox contract: data held through request/ack transaction.
# Receiver waits >= 3 synchronizer + 2 settling cycles before capturing bus.
# Bound every payload bit to 10 ns, one nominal 100 MHz clock period.
# Do NOT replace these bounds with a blanket asynchronous clock-group exception.
# XDC uses supported constraint commands only (no Tcl foreach/if).
# Only physically connected paths between these mailbox register sets are timed.
set_max_delay -datapath_only 10.000 -from [get_cells -hier -filter {NAME =~ */payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */dst_data_reg*}]
set_bus_skew 10.000 -from [get_cells -hier -filter {NAME =~ */payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */dst_data_reg*}]
# Cut only asynchronous inputs of explicit single-bit synchronization chains.
set first_stages [get_cells -quiet -hier -regexp {.*(req_sync_reg\[0\]|ack_sync_reg\[0\]|sync_ff_reg\[0\])$}]
set_false_path -to [get_pins -of_objects $first_stages -filter {REF_PIN_NAME == D}]
# level_sync uses its own sync_ff shift chain; FIFO carries its generated XDC.
