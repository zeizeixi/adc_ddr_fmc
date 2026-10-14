# FMC pin mapping traced from supplied baseboard and core schematics.
# Proposed top ports: MCU_FMC_D[15:0], A[12:0], BA[1:0], NBL[1:0], scalar controls.
# Add only after matching RTL ports exist. Bank14/15 VCCO must be 3.3 V.
# Pin constraints plus provisional source-synchronous interface timing budgets.
# Re-run full ADC+DDR implementation; board flight-time skew remains unmeasured.
# SDCLK is flown to J20 / B15_L11_P / SRCC and drives a BUFG.
# Nominal SDCLK=56 MHz; CAS3, RPIPE2, BL1.

# J1-49 -> B15_L18_P -> N20
set_property PACKAGE_PIN N20 [get_ports {MCU_FMC_SDCKE1}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDCKE1}]
# J1-47 -> B15_L18_N -> M20
set_property PACKAGE_PIN M20 [get_ports {MCU_FMC_SDNRAS}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDNRAS}]
# J1-45 -> B15_L15_P -> N22
set_property PACKAGE_PIN N22 [get_ports {MCU_FMC_SDNE1}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDNE1}]
# J1-43 -> B15_L15_N -> M22
set_property PACKAGE_PIN M22 [get_ports {MCU_FMC_BA[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_BA[0]}]
# J1-41 -> B15_L10_P -> M21
set_property PACKAGE_PIN M21 [get_ports {MCU_FMC_BA[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_BA[1]}]
# Flying wire: STM32 SDCLK -> J20 / B15_L11_P / SRCC
set_property PACKAGE_PIN J20 [get_ports {MCU_FMC_SDCLK}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDCLK}]
# J1-37 -> B15_L17_P -> N18
set_property PACKAGE_PIN N18 [get_ports {MCU_FMC_NBL[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_NBL[0]}]
# J1-35 -> B15_L17_N -> N19
set_property PACKAGE_PIN N19 [get_ports {MCU_FMC_NBL[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_NBL[1]}]
# J1-33 -> B15_IO25 -> M17
set_property PACKAGE_PIN M17 [get_ports {MCU_FMC_SDNWE}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDNWE}]
# J1-31 -> B15_L16_P -> M18
set_property PACKAGE_PIN M18 [get_ports {MCU_FMC_SDNCAS}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_SDNCAS}]
# J4-65 -> B14_IO0 -> P20
set_property PACKAGE_PIN P20 [get_ports {MCU_FMC_D[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[0]}]
# J4-63 -> B14_L20_N -> T18
set_property PACKAGE_PIN T18 [get_ports {MCU_FMC_D[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[1]}]
# J4-49 -> B14_L21_P -> N17
set_property PACKAGE_PIN N17 [get_ports {MCU_FMC_D[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[2]}]
# J4-47 -> B14_L19_N -> R14
set_property PACKAGE_PIN R14 [get_ports {MCU_FMC_D[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[3]}]
# J4-62 -> B14_L15_P -> AA19
set_property PACKAGE_PIN AA19 [get_ports {MCU_FMC_D[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[4]}]
# J4-60 -> B14_L17_N -> AB18
set_property PACKAGE_PIN AB18 [get_ports {MCU_FMC_D[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[5]}]
# J4-58 -> B14_L17_P -> AA18
set_property PACKAGE_PIN AA18 [get_ports {MCU_FMC_D[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[6]}]
# J4-56 -> B14_L18_N -> U18
set_property PACKAGE_PIN U18 [get_ports {MCU_FMC_D[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[7]}]
# J4-54 -> B14_L18_P -> U17
set_property PACKAGE_PIN U17 [get_ports {MCU_FMC_D[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[8]}]
# J4-52 -> B14_L16_N -> W17
set_property PACKAGE_PIN W17 [get_ports {MCU_FMC_D[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[9]}]
# J4-50 -> B14_L16_P -> V17
set_property PACKAGE_PIN V17 [get_ports {MCU_FMC_D[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[10]}]
# J4-69 -> B14_L7_P -> W21
set_property PACKAGE_PIN W21 [get_ports {MCU_FMC_D[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[11]}]
# J4-67 -> B14_L6_N -> T20
set_property PACKAGE_PIN T20 [get_ports {MCU_FMC_D[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[12]}]
# J4-75 -> B14_L12_N -> W20
set_property PACKAGE_PIN W20 [get_ports {MCU_FMC_D[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[13]}]
# J4-73 -> B14_L12_P -> W19
set_property PACKAGE_PIN W19 [get_ports {MCU_FMC_D[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[14]}]
# J4-71 -> B14_L7_N -> W22
set_property PACKAGE_PIN W22 [get_ports {MCU_FMC_D[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_D[15]}]
# J4-51 -> B14_L21_N -> P17
set_property PACKAGE_PIN P17 [get_ports {MCU_FMC_A[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[0]}]
# J4-53 -> B14_L22_P -> P15
set_property PACKAGE_PIN P15 [get_ports {MCU_FMC_A[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[1]}]
# J4-55 -> B14_L22_N -> R16
set_property PACKAGE_PIN R16 [get_ports {MCU_FMC_A[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[2]}]
# J4-57 -> B14_L24_P -> P16
set_property PACKAGE_PIN P16 [get_ports {MCU_FMC_A[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[3]}]
# J4-59 -> B14_L24_N -> R17
set_property PACKAGE_PIN R17 [get_ports {MCU_FMC_A[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[4]}]
# J4-61 -> B14_L20_P -> R18
set_property PACKAGE_PIN R18 [get_ports {MCU_FMC_A[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[5]}]
# J4-76 -> B14_L13_P -> Y18
set_property PACKAGE_PIN Y18 [get_ports {MCU_FMC_A[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[6]}]
# J4-74 -> B14_L10_N -> AB22
set_property PACKAGE_PIN AB22 [get_ports {MCU_FMC_A[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[7]}]
# J4-72 -> B14_L10_P -> AB21
set_property PACKAGE_PIN AB21 [get_ports {MCU_FMC_A[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[8]}]
# J4-70 -> B14_L9_N -> Y22
set_property PACKAGE_PIN Y22 [get_ports {MCU_FMC_A[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[9]}]
# J4-68 -> B14_L9_P -> Y21
set_property PACKAGE_PIN Y21 [get_ports {MCU_FMC_A[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[10]}]
# J4-64 -> B14_L15_N -> AB20
set_property PACKAGE_PIN AB20 [get_ports {MCU_FMC_A[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[11]}]
# J4-78 -> B14_L13_N -> Y19
set_property PACKAGE_PIN Y19 [get_ports {MCU_FMC_A[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {MCU_FMC_A[12]}]
set_property SLEW FAST [get_ports {MCU_FMC_D[*]}]
set_property DRIVE 12 [get_ports {MCU_FMC_D[*]}]

# 56 MHz target; STM32 commands/data are launched relative to SDCLK falling edge.
# Delays include a provisional board-skew allowance; verify the flying-wire skew.
# Assume the shortest low phase of HCLK/3 for setup. Expand minimum input delay
# to also cover the earliest falling edge (33% high), with 0.5 ns skew allowance.
create_clock -name fmc_sdclk -period 17.857 -waveform {0.000 11.905} [get_ports MCU_FMC_SDCLK]
set_clock_uncertainty 0.250 [get_clocks fmc_sdclk]
set fmc_inputs [get_ports {MCU_FMC_A[*] MCU_FMC_BA[*] MCU_FMC_NBL[*] MCU_FMC_SDCKE1 MCU_FMC_SDNE1 MCU_FMC_SDNRAS MCU_FMC_SDNCAS MCU_FMC_SDNWE}]
set_input_delay -clock fmc_sdclk -clock_fall -max 3.000 $fmc_inputs
set_input_delay -clock fmc_sdclk -clock_fall -min -6.453 $fmc_inputs
set_input_delay -clock fmc_sdclk -clock_fall -max 4.500 [get_ports {MCU_FMC_D[*]}]
set_input_delay -clock fmc_sdclk -clock_fall -min -6.453 [get_ports {MCU_FMC_D[*]}]

# Inferred MCU sampling model: CAS3 + RPIPE2, HCLK=168 MHz, SDCLK=HCLK/3.
# MCU setup=2 ns plus 0.5 ns provisional board allowance.
create_clock -name fmc_read_sample -period 17.857 -waveform {11.905 16.000}
set_output_delay -clock fmc_read_sample -max 2.500 [get_ports {MCU_FMC_D[*]}]
set_output_delay -clock fmc_read_sample -min -0.500 [get_ports {MCU_FMC_D[*]}]

# Keep existing runtime_cdc.xdc for mailbox payload bounds and first-stage cuts.
# Do not add asynchronous clock groups: those would hide bundled-data limits.


