# Run inside an OPEN Vivado project for your actual Artix-7 part.
# Does not create or alter the board-specific MIG/clock/pin configuration.
if {[current_project -quiet] eq ""} { error "Open your Vivado project first" }
set ip_name adc_fifo_256x512
if {[llength [get_ips -quiet $ip_name]] != 0} {
    error "$ip_name already exists. Check it manually; this script will not overwrite it."
}
create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name $ip_name
set_property -dict [list \
    CONFIG.Fifo_Implementation {Independent_Clocks_Block_RAM} \
    CONFIG.Performance_Options {First_Word_Fall_Through} \
    CONFIG.Input_Data_Width {256} \
    CONFIG.Input_Depth {512} \
    CONFIG.Output_Data_Width {256} \
    CONFIG.Reset_Pin {true} \
    CONFIG.Enable_Reset_Synchronization {true} \
    CONFIG.Full_Flags_Reset_Value {1} \
    CONFIG.Use_Embedded_Registers {false} \
    CONFIG.Use_Dout_Reset {true} \
    CONFIG.Almost_Full_Flag {false} \
    CONFIG.Almost_Empty_Flag {false} \
    CONFIG.Valid_Flag {false} \
    CONFIG.Underflow_Flag {false} \
    CONFIG.Overflow_Flag {false} \
    CONFIG.Write_Acknowledge_Flag {false} \
    CONFIG.Data_Count {false} \
    CONFIG.Write_Data_Count {false} \
    CONFIG.Read_Data_Count {false}] [get_ips $ip_name]
generate_target all [get_ips $ip_name]
puts "Generated $ip_name: 256->256, 512 words, independent clocks, FWFT."
