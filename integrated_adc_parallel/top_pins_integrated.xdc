# 合并引脚约束：XC7A200T-FBG484-2，自研底板，无 LED；ADC 配置线使用已确认跳线。
# 数据映射按连接器及 Bank15/16 原理图逐根核对；不代表整板电气或时序已完成验证。
# DDR PACKAGE_PIN/IOSTANDARD 保留附件原值；MIG 内部时序、终端等仍由 MIG 自带 XDC 管理。
# 只加载本文件一份；禁用工作工程中重复的旧 top.xdc/ADC 引脚文件，不禁用 MIG 或 runtime_cdc.xdc。
# FMC 端口尚未加入 RTL，所以最后一节全部注释；不要直接取消注释。

# ===== 系统时钟与复位：沿用厂家原配置 =====
set_property PACKAGE_PIN R4 [get_ports sys_clk]
set_property IOSTANDARD LVCMOS15 [get_ports sys_clk]
create_clock -period 20.000 -name sys_clk [get_ports sys_clk]
set_property PACKAGE_PIN U7 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS15 [get_ports sys_rst_n]
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk]

# ===== DDR3：厂家 MIG 球脚与电平原值 =====
set_property PACKAGE_PIN C2 [get_ports {ddr3_dq[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[0]}]
set_property PACKAGE_PIN G1 [get_ports {ddr3_dq[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[1]}]
set_property PACKAGE_PIN A1 [get_ports {ddr3_dq[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[2]}]
set_property PACKAGE_PIN F3 [get_ports {ddr3_dq[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[3]}]
set_property PACKAGE_PIN B2 [get_ports {ddr3_dq[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[4]}]
set_property PACKAGE_PIN F1 [get_ports {ddr3_dq[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[5]}]
set_property PACKAGE_PIN B1 [get_ports {ddr3_dq[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[6]}]
set_property PACKAGE_PIN E2 [get_ports {ddr3_dq[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[7]}]
set_property PACKAGE_PIN H3 [get_ports {ddr3_dq[8]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[8]}]
set_property PACKAGE_PIN G3 [get_ports {ddr3_dq[9]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[9]}]
set_property PACKAGE_PIN H2 [get_ports {ddr3_dq[10]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[10]}]
set_property PACKAGE_PIN H5 [get_ports {ddr3_dq[11]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[11]}]
set_property PACKAGE_PIN J1 [get_ports {ddr3_dq[12]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[12]}]
set_property PACKAGE_PIN J5 [get_ports {ddr3_dq[13]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[13]}]
set_property PACKAGE_PIN K1 [get_ports {ddr3_dq[14]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[14]}]
set_property PACKAGE_PIN H4 [get_ports {ddr3_dq[15]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[15]}]
set_property PACKAGE_PIN L4 [get_ports {ddr3_dq[16]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[16]}]
set_property PACKAGE_PIN M3 [get_ports {ddr3_dq[17]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[17]}]
set_property PACKAGE_PIN L3 [get_ports {ddr3_dq[18]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[18]}]
set_property PACKAGE_PIN J6 [get_ports {ddr3_dq[19]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[19]}]
set_property PACKAGE_PIN K3 [get_ports {ddr3_dq[20]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[20]}]
set_property PACKAGE_PIN K6 [get_ports {ddr3_dq[21]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[21]}]
set_property PACKAGE_PIN J4 [get_ports {ddr3_dq[22]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[22]}]
set_property PACKAGE_PIN L5 [get_ports {ddr3_dq[23]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[23]}]
set_property PACKAGE_PIN P1 [get_ports {ddr3_dq[24]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[24]}]
set_property PACKAGE_PIN N4 [get_ports {ddr3_dq[25]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[25]}]
set_property PACKAGE_PIN R1 [get_ports {ddr3_dq[26]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[26]}]
set_property PACKAGE_PIN N2 [get_ports {ddr3_dq[27]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[27]}]
set_property PACKAGE_PIN M6 [get_ports {ddr3_dq[28]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[28]}]
set_property PACKAGE_PIN N5 [get_ports {ddr3_dq[29]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[29]}]
set_property PACKAGE_PIN P6 [get_ports {ddr3_dq[30]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[30]}]
set_property PACKAGE_PIN P2 [get_ports {ddr3_dq[31]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[31]}]
set_property PACKAGE_PIN U1 [get_ports {ddr3_addr[13]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[13]}]
set_property PACKAGE_PIN Y2 [get_ports {ddr3_addr[12]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[12]}]
set_property PACKAGE_PIN W2 [get_ports {ddr3_addr[11]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[11]}]
set_property PACKAGE_PIN Y1 [get_ports {ddr3_addr[10]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[10]}]
set_property PACKAGE_PIN U2 [get_ports {ddr3_addr[9]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[9]}]
set_property PACKAGE_PIN V2 [get_ports {ddr3_addr[8]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[8]}]
set_property PACKAGE_PIN T1 [get_ports {ddr3_addr[7]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[7]}]
set_property PACKAGE_PIN W1 [get_ports {ddr3_addr[6]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[6]}]
set_property PACKAGE_PIN U3 [get_ports {ddr3_addr[5]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[5]}]
set_property PACKAGE_PIN AB1 [get_ports {ddr3_addr[4]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[4]}]
set_property PACKAGE_PIN AB5 [get_ports {ddr3_addr[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[3]}]
set_property PACKAGE_PIN AA5 [get_ports {ddr3_addr[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[2]}]
set_property PACKAGE_PIN AB2 [get_ports {ddr3_addr[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[1]}]
set_property PACKAGE_PIN AA4 [get_ports {ddr3_addr[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[0]}]
set_property PACKAGE_PIN Y4 [get_ports {ddr3_ba[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[2]}]
set_property PACKAGE_PIN Y3 [get_ports {ddr3_ba[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[1]}]
set_property PACKAGE_PIN AA3 [get_ports {ddr3_ba[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[0]}]
set_property PACKAGE_PIN V4 [get_ports ddr3_ras_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_ras_n]
set_property PACKAGE_PIN W4 [get_ports ddr3_cas_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_cas_n]
set_property PACKAGE_PIN AA1 [get_ports ddr3_we_n]
set_property IOSTANDARD SSTL15 [get_ports ddr3_we_n]
set_property PACKAGE_PIN W6 [get_ports ddr3_reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports ddr3_reset_n]
set_property PACKAGE_PIN T5 [get_ports {ddr3_cke[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cke[0]}]
set_property PACKAGE_PIN U5 [get_ports {ddr3_odt[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_odt[0]}]
set_property PACKAGE_PIN AB3 [get_ports {ddr3_cs_n[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cs_n[0]}]
set_property PACKAGE_PIN D2 [get_ports {ddr3_dm[0]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[0]}]
set_property PACKAGE_PIN G2 [get_ports {ddr3_dm[1]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[1]}]
set_property PACKAGE_PIN M2 [get_ports {ddr3_dm[2]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[2]}]
set_property PACKAGE_PIN M5 [get_ports {ddr3_dm[3]}]
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[3]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[0]}]
set_property PACKAGE_PIN E1 [get_ports {ddr3_dqs_p[0]}]
set_property PACKAGE_PIN D1 [get_ports {ddr3_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[1]}]
set_property PACKAGE_PIN K2 [get_ports {ddr3_dqs_p[1]}]
set_property PACKAGE_PIN J2 [get_ports {ddr3_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[1]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[2]}]
set_property PACKAGE_PIN M1 [get_ports {ddr3_dqs_p[2]}]
set_property PACKAGE_PIN L1 [get_ports {ddr3_dqs_n[2]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[2]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[3]}]
set_property PACKAGE_PIN P5 [get_ports {ddr3_dqs_p[3]}]
set_property PACKAGE_PIN P4 [get_ports {ddr3_dqs_n[3]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[3]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_p[0]}]
set_property PACKAGE_PIN R3 [get_ports {ddr3_ck_p[0]}]
set_property PACKAGE_PIN R2 [get_ports {ddr3_ck_n[0]}]
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_n[0]}]

# ===== ADC：两路各 12 位，端口 [2] 对应 D0，[13] 对应 D11；NC 不使用 =====
set_property PACKAGE_PIN L16 [get_ports {ADC_DA[2]}] ; # J1-46 -> B15_L23_P -> L16
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[2]}]
set_property PACKAGE_PIN K16 [get_ports {ADC_DA[3]}] ; # J1-44 -> B15_L23_N -> K16
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[3]}]
set_property PACKAGE_PIN K19 [get_ports {ADC_DA[4]}] ; # J1-40 -> B15_L13_N -> K19
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[4]}]
set_property PACKAGE_PIN L13 [get_ports {ADC_DA[5]}] ; # J1-36 -> B15_L20_N -> L13
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[5]}]
set_property PACKAGE_PIN L15 [get_ports {ADC_DA[6]}] ; # J1-32 -> B15_L22_N -> L15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[6]}]
set_property PACKAGE_PIN K14 [get_ports {ADC_DA[7]}] ; # J1-28 -> B15_L19_N -> K14
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[7]}]
set_property PACKAGE_PIN J15 [get_ports {ADC_DA[8]}] ; # J1-24 -> B15_L5_P -> J15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[8]}]
set_property PACKAGE_PIN J14 [get_ports {ADC_DA[9]}] ; # J1-20 -> B15_L3_P -> J14
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[9]}]
set_property PACKAGE_PIN H13 [get_ports {ADC_DA[10]}] ; # J1-16 -> B15_L1_P -> H13
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[10]}]
set_property PACKAGE_PIN J19 [get_ports {ADC_DA[11]}] ; # J1-12 -> B15_L12_P -> J19
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[11]}]
set_property PACKAGE_PIN G16 [get_ports {ADC_DA[12]}] ; # J1-8 -> B15_L2_N -> G16
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[12]}]
set_property PACKAGE_PIN G15 [get_ports {ADC_DA[13]}] ; # J1-6 -> B15_L2_P -> G15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[13]}]
set_property PACKAGE_PIN G21 [get_ports {ADC_DB[2]}] ; # J2-74 -> B16_L24_P -> G21
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[2]}]
set_property PACKAGE_PIN F19 [get_ports {ADC_DB[3]}] ; # J2-70 -> B16_L18_P -> F19
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[3]}]
set_property PACKAGE_PIN E14 [get_ports {ADC_DB[4]}] ; # J2-62 -> B16_L4_N -> E14
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[4]}]
set_property PACKAGE_PIN E13 [get_ports {ADC_DB[5]}] ; # J2-60 -> B16_L4_P -> E13
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[5]}]
set_property PACKAGE_PIN F13 [get_ports {ADC_DB[6]}] ; # J2-56 -> B16_L1_P -> F13
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[6]}]
set_property PACKAGE_PIN B22 [get_ports {ADC_DB[7]}] ; # J2-52 -> B16_L20_N -> B22
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[7]}]
set_property PACKAGE_PIN D20 [get_ports {ADC_DB[8]}] ; # J2-48 -> B16_L19_P -> D20
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[8]}]
set_property PACKAGE_PIN C19 [get_ports {ADC_DB[9]}] ; # J2-44 -> B16_L13_N -> C19
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[9]}]
set_property PACKAGE_PIN C18 [get_ports {ADC_DB[10]}] ; # J2-42 -> B16_L13_P -> C18
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[10]}]
set_property PACKAGE_PIN B16 [get_ports {ADC_DB[11]}] ; # J2-40 -> B16_L7_N -> B16
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[11]}]
set_property PACKAGE_PIN B15 [get_ports {ADC_DB[12]}] ; # J2-38 -> B16_L7_P -> B15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[12]}]
set_property PACKAGE_PIN C15 [get_ports {ADC_DB[13]}] ; # J2-36 -> B16_L3_N -> C15
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[13]}]
set_property PACKAGE_PIN G18 [get_ports ADC_CLK_OUT_P] ; # J1-4 -> B15_L4_N；ADC 返回时钟输入
set_property IOSTANDARD LVCMOS33 [get_ports ADC_CLK_OUT_P]
set_property PACKAGE_PIN N14 [get_ports {ADC_CTRL[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[0]}]
set_property PACKAGE_PIN N15 [get_ports {ADC_CTRL[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[1]}]
set_property PACKAGE_PIN P14 [get_ports {ADC_CTRL[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[2]}]
set_property PACKAGE_PIN V8 [get_ports {ADC_CLK_IN_P}] ; # ADC 时钟输出；FPGA 物理 N

set_property PACKAGE_PIN V9 [get_ports {ADC_CLK_IN_N}] ; # ADC 时钟输出；FPGA 物理 P
# 并行配置需在 RTL 中固定 RESET=1、SEN=1、SCLK=0、SDI=0、CTRL=000。
# XDC 只定义引脚和电平标准，不产生固定逻辑电平；以下配置端口继续保留。
set_property PACKAGE_PIN T16 [get_ports ADC_CS] ; # 实物跳线，ADC SEN（并行模式为高电平）
set_property PACKAGE_PIN W14 [get_ports ADC_SDI] ; # 实物跳线，ADC SDATA
set_property PACKAGE_PIN V15 [get_ports ADC_SCK] ; # 实物跳线，ADC SCLK（并行模式为低电平）
set_property PACKAGE_PIN AA9 [get_ports ADC_RESET] ; # 实物跳线，ADC RESET（并行模式保持高电平）
# 配套 RTL 保持 OBUFDS .O(ADC_CLK_IN_N)、.OB(ADC_CLK_IN_P)；输出电平兼容性仍需板级确认。
# ADC 返回时钟在文件末尾约束为 100 MHz；数据 input_delay 尚未补齐。

# ===== FMC：未来接口预留，全部注释；D0 已更正为 P20 =====
# set_property PACKAGE_PIN N20 [get_ports {FMC_SDCKE1}]; # A7J1/J1 第49脚 → B15_L18_P；待 FMC RTL 加入后启用15_L18_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDCKE1}]; # FMC 对应 Bank 为 3.3 V为 3.3 V
# set_property PACKAGE_PIN M20 [get_ports {FMC_SDNRAS}]; # A7J1/J1 第47脚 → B15_L18_N；待 FMC RTL 加入后启用15_L18_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNRAS}]; # FMC 对应 Bank 为 3.3 V为 3.3 V
# set_property PACKAGE_PIN N22 [get_ports {FMC_SDNE1}]; # A7J1/J1 第45脚 → B15_L15_P；待 FMC RTL 加入后启用5_L15_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNE1}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN M22 [get_ports {FMC_BA[0]}]; # A7J1/J1 第43脚 → B15_L15_N；待 FMC RTL 加入后启用5_L15_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_BA[0]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN L18 [get_ports {FMC_BA[1]}]; # A7J1/J1 第41脚 → B15_L16_N；待 FMC RTL 加入后启用5_L16_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_BA[1]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN L21 [get_ports {FMC_SDCLK}]; # A7J1/J1 第39脚 → B15_L10_N；待 FMC RTL 加入后启用；L21 非专用时钟脚5_L10_N；待 FMC RTL 加入后启用；L21 非专用时钟脚
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDCLK}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN H22 [get_ports {FMC_NBL[0]}]; # A7J1/J1 第37脚 → B15_L7_N；待 FMC RTL 加入后启用15_L7_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_NBL[0]}]; # FMC 对应 Bank 为 3.3 V为 3.3 V
# set_property PACKAGE_PIN J22 [get_ports {FMC_NBL[1]}]; # A7J1/J1 第35脚 → B15_L7_P；待 FMC RTL 加入后启用15_L7_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_NBL[1]}]; # FMC 对应 Bank 为 3.3 V为 3.3 V
# set_property PACKAGE_PIN M17 [get_ports {FMC_SDNWE}]; # A7J1/J1 第33脚 → B15_IO25；待 FMC RTL 加入后启用5_IO25；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNWE}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN J16 [get_ports {FMC_SDNCAS}]; # A7J1/J1 第31脚 → B15_IO0；待 FMC RTL 加入后启用15_IO0；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNCAS}]; # FMC 对应 Bank 为 3.3 V为 3.3 V
# set_property PACKAGE_PIN P17 [get_ports {FMC_A[0]}]; # A7J4/J4 第51脚 → B14_L21_N；待 FMC RTL 加入后启用_L21_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[0]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN P15 [get_ports {FMC_A[1]}]; # A7J4/J4 第53脚 → B14_L22_P；待 FMC RTL 加入后启用_L22_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[1]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN R16 [get_ports {FMC_A[2]}]; # A7J4/J4 第55脚 → B14_L22_N；待 FMC RTL 加入后启用_L22_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[2]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN P16 [get_ports {FMC_A[3]}]; # A7J4/J4 第57脚 → B14_L24_P；待 FMC RTL 加入后启用_L24_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[3]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN R17 [get_ports {FMC_A[4]}]; # A7J4/J4 第59脚 → B14_L24_N；待 FMC RTL 加入后启用_L24_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[4]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN R18 [get_ports {FMC_A[5]}]; # A7J4/J4 第61脚 → B14_L20_P；待 FMC RTL 加入后启用_L20_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[5]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN Y18 [get_ports {FMC_A[6]}]; # A7J4/J4 第76脚 → B14_L13_P；待 FMC RTL 加入后启用_L13_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[6]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN AB22 [get_ports {FMC_A[7]}]; # A7J4/J4 第74脚 → B14_L10_N；待 FMC RTL 加入后启用4_L10_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[7]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN AB21 [get_ports {FMC_A[8]}]; # A7J4/J4 第72脚 → B14_L10_P；待 FMC RTL 加入后启用4_L10_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[8]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN Y22 [get_ports {FMC_A[9]}]; # A7J4/J4 第70脚 → B14_L9_N；待 FMC RTL 加入后启用_L9_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[9]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN Y21 [get_ports {FMC_A[10]}]; # A7J4/J4 第68脚 → B14_L9_P；待 FMC RTL 加入后启用4_L9_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[10]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN AB20 [get_ports {FMC_A[11]}]; # A7J4/J4 第64脚 → B14_L15_N；待 FMC RTL 加入后启用14_L15_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[11]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN Y19 [get_ports {FMC_A[12]}]; # A7J4/J4 第78脚 → B14_L13_N；待 FMC RTL 加入后启用4_L13_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[12]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN P20 [get_ports {FMC_D[0]}]; # A7J4/J4 第65脚 → B14_IO0；待 FMC RTL 加入后启用_IO0；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[0]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN T18 [get_ports {FMC_D[1]}]; # A7J4/J4 第63脚 → B14_L20_N；待 FMC RTL 加入后启用_L20_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[1]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN N17 [get_ports {FMC_D[2]}]; # A7J4/J4 第49脚 → B14_L21_P；待 FMC RTL 加入后启用_L21_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[2]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN R14 [get_ports {FMC_D[3]}]; # A7J4/J4 第47脚 → B14_L19_N；待 FMC RTL 加入后启用_L19_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[3]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN AA19 [get_ports {FMC_D[4]}]; # A7J4/J4 第62脚 → B14_L15_P；待 FMC RTL 加入后启用4_L15_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[4]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN AB18 [get_ports {FMC_D[5]}]; # A7J4/J4 第60脚 → B14_L17_N；待 FMC RTL 加入后启用4_L17_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[5]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN AA18 [get_ports {FMC_D[6]}]; # A7J4/J4 第58脚 → B14_L17_P；待 FMC RTL 加入后启用4_L17_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[6]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN U18 [get_ports {FMC_D[7]}]; # A7J4/J4 第56脚 → B14_L18_N；待 FMC RTL 加入后启用_L18_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[7]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN U17 [get_ports {FMC_D[8]}]; # A7J4/J4 第54脚 → B14_L18_P；待 FMC RTL 加入后启用_L18_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[8]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN W17 [get_ports {FMC_D[9]}]; # A7J4/J4 第52脚 → B14_L16_N；待 FMC RTL 加入后启用_L16_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[9]}]; # FMC 对应 Bank 为 3.3 V3.3 V
# set_property PACKAGE_PIN V17 [get_ports {FMC_D[10]}]; # A7J4/J4 第50脚 → B14_L16_P；待 FMC RTL 加入后启用4_L16_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[10]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN W21 [get_ports {FMC_D[11]}]; # A7J4/J4 第69脚 → B14_L7_P；待 FMC RTL 加入后启用4_L7_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[11]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN T20 [get_ports {FMC_D[12]}]; # A7J4/J4 第67脚 → B14_L6_N；待 FMC RTL 加入后启用4_L6_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[12]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN W20 [get_ports {FMC_D[13]}]; # A7J4/J4 第75脚 → B14_L12_N；待 FMC RTL 加入后启用4_L12_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[13]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN W19 [get_ports {FMC_D[14]}]; # A7J4/J4 第73脚 → B14_L12_P；待 FMC RTL 加入后启用4_L12_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[14]}]; # FMC 对应 Bank 为 3.3 V 3.3 V
# set_property PACKAGE_PIN W22 [get_ports {FMC_D[15]}]; # A7J4/J4 第71脚 → B14_L7_N；待 FMC RTL 加入后启用4_L7_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[15]}]; # FMC 对应 Bank 为 3.3 V 3.3 V

set_property IOSTANDARD DIFF_SSTL15 [get_ports ADC_CLK_IN_N]
set_property IOSTANDARD DIFF_SSTL15 [get_ports ADC_CLK_IN_P]

set_property IOSTANDARD LVCMOS33 [get_ports ADC_CS]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_RESET]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_SCK]
set_property IOSTANDARD LVCMOS33 [get_ports ADC_SDI]
set_property C_CLK_INPUT_FREQ_HZ 100000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ui_clk]
# 临时允许 ADC 返回时钟通过非专用布线进入 BUFG
# 用于继续实现检查，不代表已满足 100 MHz 采集时序
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets ADC_CLK_OUT_P_IBUF]
# ADC 返回时钟：100 MHz，周期 10 ns
create_clock -name adc_capture_clk -period 10.000 [get_ports ADC_CLK_OUT_P]
