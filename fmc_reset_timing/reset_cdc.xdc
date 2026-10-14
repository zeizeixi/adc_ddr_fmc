# Async assertion, three-stage synchronous release; reviewed reset_sync instances.
# Exempt only synchronizer PRE inputs. Keep chain D and reset release paths timed.
# Existing mailbox max-delay and bus-skew constraints are preserved.
set_false_path -to [get_pins -hierarchical -filter {NAME =~ u_fmc_reset/sync_ff_reg*/PRE}]
set_false_path -to [get_pins -hierarchical -filter {NAME =~ u_store/u_rd_reset/sync_ff_reg*/PRE}]
