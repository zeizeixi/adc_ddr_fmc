create_project -in_memory -part xc7a200tfbg484-2
read_verilog [file join [file dirname [info script]] pin_probe.v]
synth_design -rtl -top pin_probe -part xc7a200tfbg484-2
set p [get_package_pins K16]
if {[llength $p]!=1} {error "Missing ball K16"}
puts "PIN ADC_DA\[2\] K16 [get_property PIN_FUNC $p]"
set p [get_package_pins L16]
if {[llength $p]!=1} {error "Missing ball L16"}
puts "PIN ADC_DA\[3\] L16 [get_property PIN_FUNC $p]"
set p [get_package_pins K19]
if {[llength $p]!=1} {error "Missing ball K19"}
puts "PIN ADC_DA\[4\] K19 [get_property PIN_FUNC $p]"
set p [get_package_pins J19]
if {[llength $p]!=1} {error "Missing ball J19"}
puts "PIN ADC_DA\[5\] J19 [get_property PIN_FUNC $p]"
set p [get_package_pins L14]
if {[llength $p]!=1} {error "Missing ball L14"}
puts "PIN ADC_DA\[6\] L14 [get_property PIN_FUNC $p]"
set p [get_package_pins K14]
if {[llength $p]!=1} {error "Missing ball K14"}
puts "PIN ADC_DA\[7\] K14 [get_property PIN_FUNC $p]"
set p [get_package_pins M21]
if {[llength $p]!=1} {error "Missing ball M21"}
puts "PIN ADC_DA\[8\] M21 [get_property PIN_FUNC $p]"
set p [get_package_pins J15]
if {[llength $p]!=1} {error "Missing ball J15"}
puts "PIN ADC_DA\[9\] J15 [get_property PIN_FUNC $p]"
set p [get_package_pins J20]
if {[llength $p]!=1} {error "Missing ball J20"}
puts "PIN ADC_DA\[10\] J20 [get_property PIN_FUNC $p]"
set p [get_package_pins K17]
if {[llength $p]!=1} {error "Missing ball K17"}
puts "PIN ADC_DA\[11\] K17 [get_property PIN_FUNC $p]"
set p [get_package_pins H17]
if {[llength $p]!=1} {error "Missing ball H17"}
puts "PIN ADC_DA\[12\] H17 [get_property PIN_FUNC $p]"
set p [get_package_pins G15]
if {[llength $p]!=1} {error "Missing ball G15"}
puts "PIN ADC_DA\[13\] G15 [get_property PIN_FUNC $p]"
set p [get_package_pins G21]
if {[llength $p]!=1} {error "Missing ball G21"}
puts "PIN ADC_DB\[2\] G21 [get_property PIN_FUNC $p]"
set p [get_package_pins F20]
if {[llength $p]!=1} {error "Missing ball F20"}
puts "PIN ADC_DB\[3\] F20 [get_property PIN_FUNC $p]"
set p [get_package_pins E14]
if {[llength $p]!=1} {error "Missing ball E14"}
puts "PIN ADC_DB\[4\] E14 [get_property PIN_FUNC $p]"
set p [get_package_pins E13]
if {[llength $p]!=1} {error "Missing ball E13"}
puts "PIN ADC_DB\[5\] E13 [get_property PIN_FUNC $p]"
set p [get_package_pins F13]
if {[llength $p]!=1} {error "Missing ball F13"}
puts "PIN ADC_DB\[6\] F13 [get_property PIN_FUNC $p]"
set p [get_package_pins F15]
if {[llength $p]!=1} {error "Missing ball F15"}
puts "PIN ADC_DB\[7\] F15 [get_property PIN_FUNC $p]"
set p [get_package_pins C20]
if {[llength $p]!=1} {error "Missing ball C20"}
puts "PIN ADC_DB\[8\] C20 [get_property PIN_FUNC $p]"
set p [get_package_pins C19]
if {[llength $p]!=1} {error "Missing ball C19"}
puts "PIN ADC_DB\[9\] C19 [get_property PIN_FUNC $p]"
set p [get_package_pins C18]
if {[llength $p]!=1} {error "Missing ball C18"}
puts "PIN ADC_DB\[10\] C18 [get_property PIN_FUNC $p]"
set p [get_package_pins B16]
if {[llength $p]!=1} {error "Missing ball B16"}
puts "PIN ADC_DB\[11\] B16 [get_property PIN_FUNC $p]"
set p [get_package_pins B15]
if {[llength $p]!=1} {error "Missing ball B15"}
puts "PIN ADC_DB\[12\] B15 [get_property PIN_FUNC $p]"
set p [get_package_pins C15]
if {[llength $p]!=1} {error "Missing ball C15"}
puts "PIN ADC_DB\[13\] C15 [get_property PIN_FUNC $p]"
set p [get_package_pins G18]
if {[llength $p]!=1} {error "Missing ball G18"}
puts "PIN ADC_CLK_OUT_P G18 [get_property PIN_FUNC $p]"
set p [get_package_pins N14]
if {[llength $p]!=1} {error "Missing ball N14"}
puts "PIN ADC_CTRL\[0\] N14 [get_property PIN_FUNC $p]"
set p [get_package_pins N15]
if {[llength $p]!=1} {error "Missing ball N15"}
puts "PIN ADC_CTRL\[1\] N15 [get_property PIN_FUNC $p]"
set p [get_package_pins P14]
if {[llength $p]!=1} {error "Missing ball P14"}
puts "PIN ADC_CTRL\[2\] P14 [get_property PIN_FUNC $p]"
set p [get_package_pins V8]
if {[llength $p]!=1} {error "Missing ball V8"}
puts "PIN ADC_CLK_IN_P V8 [get_property PIN_FUNC $p]"
set p [get_package_pins V9]
if {[llength $p]!=1} {error "Missing ball V9"}
puts "PIN ADC_CLK_IN_N V9 [get_property PIN_FUNC $p]"
set p [get_package_pins T6]
if {[llength $p]!=1} {error "Missing ball T6"}
puts "PIN ADC_CS T6 [get_property PIN_FUNC $p]"
set p [get_package_pins R6]
if {[llength $p]!=1} {error "Missing ball R6"}
puts "PIN ADC_SDI R6 [get_property PIN_FUNC $p]"
set p [get_package_pins T3]
if {[llength $p]!=1} {error "Missing ball T3"}
puts "PIN ADC_SCK T3 [get_property PIN_FUNC $p]"
set p [get_package_pins T4]
if {[llength $p]!=1} {error "Missing ball T4"}
puts "PIN ADC_RESET T4 [get_property PIN_FUNC $p]"
set p [get_package_pins N20]
if {[llength $p]!=1} {error "Missing ball N20"}
puts "PIN FMC_SDCKE1 N20 [get_property PIN_FUNC $p]"
set p [get_package_pins M20]
if {[llength $p]!=1} {error "Missing ball M20"}
puts "PIN FMC_SDNRAS M20 [get_property PIN_FUNC $p]"
set p [get_package_pins N22]
if {[llength $p]!=1} {error "Missing ball N22"}
puts "PIN FMC_SDNE1 N22 [get_property PIN_FUNC $p]"
set p [get_package_pins M22]
if {[llength $p]!=1} {error "Missing ball M22"}
puts "PIN FMC_BA\[0\] M22 [get_property PIN_FUNC $p]"
set p [get_package_pins L18]
if {[llength $p]!=1} {error "Missing ball L18"}
puts "PIN FMC_BA\[1\] L18 [get_property PIN_FUNC $p]"
set p [get_package_pins L21]
if {[llength $p]!=1} {error "Missing ball L21"}
puts "PIN FMC_SDCLK L21 [get_property PIN_FUNC $p]"
set p [get_package_pins H22]
if {[llength $p]!=1} {error "Missing ball H22"}
puts "PIN FMC_NBL\[0\] H22 [get_property PIN_FUNC $p]"
set p [get_package_pins J22]
if {[llength $p]!=1} {error "Missing ball J22"}
puts "PIN FMC_NBL\[1\] J22 [get_property PIN_FUNC $p]"
set p [get_package_pins M17]
if {[llength $p]!=1} {error "Missing ball M17"}
puts "PIN FMC_SDNWE M17 [get_property PIN_FUNC $p]"
set p [get_package_pins J16]
if {[llength $p]!=1} {error "Missing ball J16"}
puts "PIN FMC_SDNCAS J16 [get_property PIN_FUNC $p]"
set p [get_package_pins P17]
if {[llength $p]!=1} {error "Missing ball P17"}
puts "PIN FMC_A\[0\] P17 [get_property PIN_FUNC $p]"
set p [get_package_pins P15]
if {[llength $p]!=1} {error "Missing ball P15"}
puts "PIN FMC_A\[1\] P15 [get_property PIN_FUNC $p]"
set p [get_package_pins R16]
if {[llength $p]!=1} {error "Missing ball R16"}
puts "PIN FMC_A\[2\] R16 [get_property PIN_FUNC $p]"
set p [get_package_pins P16]
if {[llength $p]!=1} {error "Missing ball P16"}
puts "PIN FMC_A\[3\] P16 [get_property PIN_FUNC $p]"
set p [get_package_pins R17]
if {[llength $p]!=1} {error "Missing ball R17"}
puts "PIN FMC_A\[4\] R17 [get_property PIN_FUNC $p]"
set p [get_package_pins R18]
if {[llength $p]!=1} {error "Missing ball R18"}
puts "PIN FMC_A\[5\] R18 [get_property PIN_FUNC $p]"
set p [get_package_pins Y18]
if {[llength $p]!=1} {error "Missing ball Y18"}
puts "PIN FMC_A\[6\] Y18 [get_property PIN_FUNC $p]"
set p [get_package_pins AB22]
if {[llength $p]!=1} {error "Missing ball AB22"}
puts "PIN FMC_A\[7\] AB22 [get_property PIN_FUNC $p]"
set p [get_package_pins AB21]
if {[llength $p]!=1} {error "Missing ball AB21"}
puts "PIN FMC_A\[8\] AB21 [get_property PIN_FUNC $p]"
set p [get_package_pins Y22]
if {[llength $p]!=1} {error "Missing ball Y22"}
puts "PIN FMC_A\[9\] Y22 [get_property PIN_FUNC $p]"
set p [get_package_pins Y21]
if {[llength $p]!=1} {error "Missing ball Y21"}
puts "PIN FMC_A\[10\] Y21 [get_property PIN_FUNC $p]"
set p [get_package_pins AB20]
if {[llength $p]!=1} {error "Missing ball AB20"}
puts "PIN FMC_A\[11\] AB20 [get_property PIN_FUNC $p]"
set p [get_package_pins Y19]
if {[llength $p]!=1} {error "Missing ball Y19"}
puts "PIN FMC_A\[12\] Y19 [get_property PIN_FUNC $p]"
set p [get_package_pins T18]
if {[llength $p]!=1} {error "Missing ball T18"}
puts "PIN FMC_D\[1\] T18 [get_property PIN_FUNC $p]"
set p [get_package_pins N17]
if {[llength $p]!=1} {error "Missing ball N17"}
puts "PIN FMC_D\[2\] N17 [get_property PIN_FUNC $p]"
set p [get_package_pins R14]
if {[llength $p]!=1} {error "Missing ball R14"}
puts "PIN FMC_D\[3\] R14 [get_property PIN_FUNC $p]"
set p [get_package_pins AA19]
if {[llength $p]!=1} {error "Missing ball AA19"}
puts "PIN FMC_D\[4\] AA19 [get_property PIN_FUNC $p]"
set p [get_package_pins W22]
if {[llength $p]!=1} {error "Missing ball W22"}
puts "PIN FMC_D\[5\] W22 [get_property PIN_FUNC $p]"
set p [get_package_pins W21]
if {[llength $p]!=1} {error "Missing ball W21"}
puts "PIN FMC_D\[6\] W21 [get_property PIN_FUNC $p]"
set p [get_package_pins U18]
if {[llength $p]!=1} {error "Missing ball U18"}
puts "PIN FMC_D\[7\] U18 [get_property PIN_FUNC $p]"
set p [get_package_pins U17]
if {[llength $p]!=1} {error "Missing ball U17"}
puts "PIN FMC_D\[8\] U17 [get_property PIN_FUNC $p]"
set p [get_package_pins W17]
if {[llength $p]!=1} {error "Missing ball W17"}
puts "PIN FMC_D\[9\] W17 [get_property PIN_FUNC $p]"
set p [get_package_pins V17]
if {[llength $p]!=1} {error "Missing ball V17"}
puts "PIN FMC_D\[10\] V17 [get_property PIN_FUNC $p]"
set p [get_package_pins AA18]
if {[llength $p]!=1} {error "Missing ball AA18"}
puts "PIN FMC_D\[11\] AA18 [get_property PIN_FUNC $p]"
set p [get_package_pins T20]
if {[llength $p]!=1} {error "Missing ball T20"}
puts "PIN FMC_D\[12\] T20 [get_property PIN_FUNC $p]"
set p [get_package_pins W20]
if {[llength $p]!=1} {error "Missing ball W20"}
puts "PIN FMC_D\[13\] W20 [get_property PIN_FUNC $p]"
set p [get_package_pins W19]
if {[llength $p]!=1} {error "Missing ball W19"}
puts "PIN FMC_D\[14\] W19 [get_property PIN_FUNC $p]"
set p [get_package_pins AB18]
if {[llength $p]!=1} {error "Missing ball AB18"}
puts "PIN FMC_D\[15\] AB18 [get_property PIN_FUNC $p]"
report_property [get_package_pins G18]
report_property [get_package_pins L21]
puts "PASS all 72 assigned package balls exist on xc7a200tfbg484-2"
exit

