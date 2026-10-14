# Add to existing runtime_cdc.xdc / fmc_interface.xdc. FMC_CONTROL=1.
# Keep existing clocks, ADC input timing, FMC timing and IP-generated constraints.
# The mailbox holds its payload until acknowledged; only that CDC is bounded here.
set_max_delay -datapath_only 10.000 -from [get_cells -hier -filter {NAME =~ */u_control_mail/payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */u_control_mail/dst_data_reg*}]
set_bus_skew 10.000 -from [get_cells -hier -filter {NAME =~ */u_control_mail/payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */u_control_mail/dst_data_reg*}]
set_max_delay -datapath_only 10.000 -from [get_cells -hier -filter {NAME =~ */u_status_mail/payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */u_status_mail/dst_data_reg*}]
set_bus_skew 10.000 -from [get_cells -hier -filter {NAME =~ */u_status_mail/payload_hold_reg*}] -to [get_cells -hier -filter {NAME =~ */u_status_mail/dst_data_reg*}]
