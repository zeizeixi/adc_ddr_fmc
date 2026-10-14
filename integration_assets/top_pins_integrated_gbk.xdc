# 合并引脚约束：XC7A200T-FBG484-2，自研底板，无 LED，ADC 未飞线。
# 状态：原接线核对版；未解决 Bank34 电平、P/N 对应及普通 IO 时钟路由，不可据此直接上板。
# DDR PACKAGE_PIN/IOSTANDARD 逐项复制厂家 MIG；内部时序、终端、SLEW、IO_BUFFER_TYPE 等仍由 MIG 自带 XDC 管理。
# 只加载本文件一份；禁用工作工程中重复的旧 top.xdc/ADC 引脚文件，不禁用 MIG 或 runtime_cdc.xdc。
# FMC 端口尚未加入 RTL，所以最后一节全部注释；不要直接取消注释。

# ===== 系统时钟与复位：沿用厂家原配置 =====
set_property PACKAGE_PIN R4 [get_ports {sys_clk}]; # 系统输入时钟，核心板 SYS_CLK，50 MHz
set_property IOSTANDARD LVCMOS15 [get_ports {sys_clk}]; # 沿用厂家时钟电平配置
create_clock -period 20.000 -name sys_clk [get_ports {sys_clk}]; # 50 MHz，周期 20 ns；不要与旧 top.xdc 重复创建
set_property PACKAGE_PIN U7 [get_ports {sys_rst_n}]; # 核心板复位 RESETN，低有效
set_property IOSTANDARD LVCMOS15 [get_ports {sys_rst_n}]; # 沿用厂家复位电平配置
set_property CLOCK_DEDICATED_ROUTE BACKBONE [get_nets sys_clk]; # 原厂家系统时钟路由设置，仅针对 sys_clk

# ===== DDR3：厂家 MIG 球脚与电平原值 =====
set_property PACKAGE_PIN C2 [get_ports {ddr3_dq[0]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[0]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN G1 [get_ports {ddr3_dq[1]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[1]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN A1 [get_ports {ddr3_dq[2]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[2]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN F3 [get_ports {ddr3_dq[3]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[3]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN B2 [get_ports {ddr3_dq[4]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[4]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN F1 [get_ports {ddr3_dq[5]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[5]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN B1 [get_ports {ddr3_dq[6]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[6]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN E2 [get_ports {ddr3_dq[7]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[7]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN H3 [get_ports {ddr3_dq[8]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[8]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN G3 [get_ports {ddr3_dq[9]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[9]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN H2 [get_ports {ddr3_dq[10]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[10]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN H5 [get_ports {ddr3_dq[11]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[11]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN J1 [get_ports {ddr3_dq[12]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[12]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN J5 [get_ports {ddr3_dq[13]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[13]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN K1 [get_ports {ddr3_dq[14]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[14]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN H4 [get_ports {ddr3_dq[15]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[15]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN L4 [get_ports {ddr3_dq[16]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[16]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN M3 [get_ports {ddr3_dq[17]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[17]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN L3 [get_ports {ddr3_dq[18]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[18]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN J6 [get_ports {ddr3_dq[19]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[19]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN K3 [get_ports {ddr3_dq[20]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[20]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN K6 [get_ports {ddr3_dq[21]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[21]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN J4 [get_ports {ddr3_dq[22]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[22]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN L5 [get_ports {ddr3_dq[23]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[23]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN P1 [get_ports {ddr3_dq[24]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[24]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN N4 [get_ports {ddr3_dq[25]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[25]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN R1 [get_ports {ddr3_dq[26]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[26]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN N2 [get_ports {ddr3_dq[27]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[27]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN M6 [get_ports {ddr3_dq[28]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[28]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN N5 [get_ports {ddr3_dq[29]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[29]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN P6 [get_ports {ddr3_dq[30]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[30]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN P2 [get_ports {ddr3_dq[31]}]; # DDR 双向数据；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dq[31]}]; # DDR 双向数据；电平保持厂家原值
set_property PACKAGE_PIN U1 [get_ports {ddr3_addr[13]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[13]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN Y2 [get_ports {ddr3_addr[12]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[12]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN W2 [get_ports {ddr3_addr[11]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[11]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN Y1 [get_ports {ddr3_addr[10]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[10]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN U2 [get_ports {ddr3_addr[9]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[9]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN V2 [get_ports {ddr3_addr[8]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[8]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN T1 [get_ports {ddr3_addr[7]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[7]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN W1 [get_ports {ddr3_addr[6]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[6]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN U3 [get_ports {ddr3_addr[5]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[5]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN AB1 [get_ports {ddr3_addr[4]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[4]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN AB5 [get_ports {ddr3_addr[3]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[3]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN AA5 [get_ports {ddr3_addr[2]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[2]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN AB2 [get_ports {ddr3_addr[1]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[1]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN AA4 [get_ports {ddr3_addr[0]}]; # DDR 行列地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_addr[0]}]; # DDR 行列地址；电平保持厂家原值
set_property PACKAGE_PIN Y4 [get_ports {ddr3_ba[2]}]; # DDR Bank 地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[2]}]; # DDR Bank 地址；电平保持厂家原值
set_property PACKAGE_PIN Y3 [get_ports {ddr3_ba[1]}]; # DDR Bank 地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[1]}]; # DDR Bank 地址；电平保持厂家原值
set_property PACKAGE_PIN AA3 [get_ports {ddr3_ba[0]}]; # DDR Bank 地址；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ba[0]}]; # DDR Bank 地址；电平保持厂家原值
set_property PACKAGE_PIN V4 [get_ports {ddr3_ras_n}]; # DDR 行选命令，低有效；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_ras_n}]; # DDR 行选命令，低有效；电平保持厂家原值
set_property PACKAGE_PIN W4 [get_ports {ddr3_cas_n}]; # DDR 列选命令，低有效；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cas_n}]; # DDR 列选命令，低有效；电平保持厂家原值
set_property PACKAGE_PIN AA1 [get_ports {ddr3_we_n}]; # DDR 写命令，低有效；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_we_n}]; # DDR 写命令，低有效；电平保持厂家原值
set_property PACKAGE_PIN W6 [get_ports {ddr3_reset_n}]; # DDR 芯片复位，低有效；球脚来自厂家 MIG
set_property IOSTANDARD LVCMOS15 [get_ports {ddr3_reset_n}]; # DDR 芯片复位，低有效；电平保持厂家原值
set_property PACKAGE_PIN T5 [get_ports {ddr3_cke[0]}]; # DDR 时钟使能；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cke[0]}]; # DDR 时钟使能；电平保持厂家原值
set_property PACKAGE_PIN U5 [get_ports {ddr3_odt[0]}]; # DDR 片内终端控制；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_odt[0]}]; # DDR 片内终端控制；电平保持厂家原值
set_property PACKAGE_PIN AB3 [get_ports {ddr3_cs_n[0]}]; # DDR 片选，低有效；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_cs_n[0]}]; # DDR 片选，低有效；电平保持厂家原值
set_property PACKAGE_PIN D2 [get_ports {ddr3_dm[0]}]; # DDR 字节数据屏蔽；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[0]}]; # DDR 字节数据屏蔽；电平保持厂家原值
set_property PACKAGE_PIN G2 [get_ports {ddr3_dm[1]}]; # DDR 字节数据屏蔽；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[1]}]; # DDR 字节数据屏蔽；电平保持厂家原值
set_property PACKAGE_PIN M2 [get_ports {ddr3_dm[2]}]; # DDR 字节数据屏蔽；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[2]}]; # DDR 字节数据屏蔽；电平保持厂家原值
set_property PACKAGE_PIN M5 [get_ports {ddr3_dm[3]}]; # DDR 字节数据屏蔽；球脚来自厂家 MIG
set_property IOSTANDARD SSTL15 [get_ports {ddr3_dm[3]}]; # DDR 字节数据屏蔽；电平保持厂家原值
set_property PACKAGE_PIN E1 [get_ports {ddr3_dqs_p[0]}]; # DDR 数据选通差分正端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[0]}]; # DDR 数据选通差分正端；电平保持厂家原值
set_property PACKAGE_PIN D1 [get_ports {ddr3_dqs_n[0]}]; # DDR 数据选通差分负端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[0]}]; # DDR 数据选通差分负端；电平保持厂家原值
set_property PACKAGE_PIN K2 [get_ports {ddr3_dqs_p[1]}]; # DDR 数据选通差分正端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[1]}]; # DDR 数据选通差分正端；电平保持厂家原值
set_property PACKAGE_PIN J2 [get_ports {ddr3_dqs_n[1]}]; # DDR 数据选通差分负端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[1]}]; # DDR 数据选通差分负端；电平保持厂家原值
set_property PACKAGE_PIN M1 [get_ports {ddr3_dqs_p[2]}]; # DDR 数据选通差分正端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[2]}]; # DDR 数据选通差分正端；电平保持厂家原值
set_property PACKAGE_PIN L1 [get_ports {ddr3_dqs_n[2]}]; # DDR 数据选通差分负端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[2]}]; # DDR 数据选通差分负端；电平保持厂家原值
set_property PACKAGE_PIN P5 [get_ports {ddr3_dqs_p[3]}]; # DDR 数据选通差分正端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_p[3]}]; # DDR 数据选通差分正端；电平保持厂家原值
set_property PACKAGE_PIN P4 [get_ports {ddr3_dqs_n[3]}]; # DDR 数据选通差分负端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_dqs_n[3]}]; # DDR 数据选通差分负端；电平保持厂家原值
set_property PACKAGE_PIN R3 [get_ports {ddr3_ck_p[0]}]; # DDR 时钟差分正端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_p[0]}]; # DDR 时钟差分正端；电平保持厂家原值
set_property PACKAGE_PIN R2 [get_ports {ddr3_ck_n[0]}]; # DDR 时钟差分负端；球脚来自厂家 MIG
set_property IOSTANDARD DIFF_SSTL15 [get_ports {ddr3_ck_n[0]}]; # DDR 时钟差分负端；电平保持厂家原值

# ===== ADC：底板原接线，按连接器映射；没有 LED =====
set_property PACKAGE_PIN K16 [get_ports {ADC_DA[2]}]; # A7J1/J1 第46脚 → B15_L23_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[2]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN L16 [get_ports {ADC_DA[3]}]; # A7J1/J1 第44脚 → B15_L23_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[3]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN K19 [get_ports {ADC_DA[4]}]; # A7J1/J1 第40脚 → B15_L13_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[4]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN J19 [get_ports {ADC_DA[5]}]; # A7J1/J1 第36脚 → B15_L12_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[5]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN L14 [get_ports {ADC_DA[6]}]; # A7J1/J1 第32脚 → B15_L22_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[6]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN K14 [get_ports {ADC_DA[7]}]; # A7J1/J1 第28脚 → B15_L19_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[7]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN M21 [get_ports {ADC_DA[8]}]; # A7J1/J1 第24脚 → B15_L10_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[8]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN J15 [get_ports {ADC_DA[9]}]; # A7J1/J1 第20脚 → B15_L5_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[9]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN J20 [get_ports {ADC_DA[10]}]; # A7J1/J1 第16脚 → B15_L11_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[10]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN K17 [get_ports {ADC_DA[11]}]; # A7J1/J1 第12脚 → B15_L21_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[11]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN H17 [get_ports {ADC_DA[12]}]; # A7J1/J1 第8脚 → B15_L6_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[12]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN G15 [get_ports {ADC_DA[13]}]; # A7J1/J1 第6脚 → B15_L2_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DA[13]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN G21 [get_ports {ADC_DB[2]}]; # A7J2/J2 第74脚 → B16_L24_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[2]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN F20 [get_ports {ADC_DB[3]}]; # A7J2/J2 第70脚 → B16_L18_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[3]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN E14 [get_ports {ADC_DB[4]}]; # A7J2/J2 第62脚 → B16_L4_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[4]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN E13 [get_ports {ADC_DB[5]}]; # A7J2/J2 第60脚 → B16_L4_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[5]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN F13 [get_ports {ADC_DB[6]}]; # A7J2/J2 第56脚 → B16_L1_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[6]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN F15 [get_ports {ADC_DB[7]}]; # A7J2/J2 第52脚 → B16_IO0
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[7]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN C20 [get_ports {ADC_DB[8]}]; # A7J2/J2 第48脚 → B16_L19_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[8]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN C19 [get_ports {ADC_DB[9]}]; # A7J2/J2 第44脚 → B16_L13_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[9]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN C18 [get_ports {ADC_DB[10]}]; # A7J2/J2 第42脚 → B16_L13_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[10]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN B16 [get_ports {ADC_DB[11]}]; # A7J2/J2 第40脚 → B16_L7_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[11]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN B15 [get_ports {ADC_DB[12]}]; # A7J2/J2 第38脚 → B16_L7_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[12]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN C15 [get_ports {ADC_DB[13]}]; # A7J2/J2 第36脚 → B16_L3_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_DB[13]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN G18 [get_ports {ADC_CLK_OUT_P}]; # A7J1/J1 第4脚 → B15_L4_N；ADC 返回时钟，G18 非专用时钟脚，路由待解决
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CLK_OUT_P}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN N14 [get_ports {ADC_CTRL[0]}]; # A7J4/J4 第41脚 → B14_L23_N
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[0]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN N15 [get_ports {ADC_CTRL[1]}]; # A7J4/J4 第43脚 → B14_IO25
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[1]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN P14 [get_ports {ADC_CTRL[2]}]; # A7J4/J4 第45脚 → B14_L19_P
set_property IOSTANDARD LVCMOS33 [get_ports {ADC_CTRL[2]}]; # 按原电源图 Bank14/15/16 为 3.3 V
set_property PACKAGE_PIN V8 [get_ports {ADC_CLK_IN_P}]; # A7J3/J3 第49脚 → B34_L21_N；Bank34 电平待解决，暂不设置 IOSTANDARD
set_property PACKAGE_PIN V9 [get_ports {ADC_CLK_IN_N}]; # A7J3/J3 第51脚 → B34_L21_P；Bank34 电平待解决，暂不设置 IOSTANDARD
set_property PACKAGE_PIN T6 [get_ports {ADC_CS}]; # A7J3/J3 第47脚 → B34_L17_N；Bank34 电平待解决，暂不设置 IOSTANDARD
set_property PACKAGE_PIN R6 [get_ports {ADC_SDI}]; # A7J3/J3 第45脚 → B34_L17_P；Bank34 电平待解决，暂不设置 IOSTANDARD
set_property PACKAGE_PIN T3 [get_ports {ADC_SCK}]; # A7J3/J3 第43脚 → B34_IO0；Bank34 电平待解决，暂不设置 IOSTANDARD
set_property PACKAGE_PIN T4 [get_ports {ADC_RESET}]; # A7J3/J3 第41脚 → B34_L13_N；Bank34 电平待解决，暂不设置 IOSTANDARD
# ADC_CLK_IN_P=V8 是物理 N，ADC_CLK_IN_N=V9 是物理 P；现有 OBUFDS 配对尚待修正。
# ADC 输入时钟、input_delay 尚未加入，须依据实际 ADC 输出时序和板级延迟确定。

# ===== FMC：未来接口预留，全部注释；D0 已更正为 P20 =====
# set_property PACKAGE_PIN N20 [get_ports {FMC_SDCKE1}]; # A7J1/J1 第49脚 → B15_L18_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDCKE1}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN M20 [get_ports {FMC_SDNRAS}]; # A7J1/J1 第47脚 → B15_L18_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNRAS}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN N22 [get_ports {FMC_SDNE1}]; # A7J1/J1 第45脚 → B15_L15_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNE1}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN M22 [get_ports {FMC_BA[0]}]; # A7J1/J1 第43脚 → B15_L15_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_BA[0]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN L18 [get_ports {FMC_BA[1]}]; # A7J1/J1 第41脚 → B15_L16_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_BA[1]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN L21 [get_ports {FMC_SDCLK}]; # A7J1/J1 第39脚 → B15_L10_N；待 FMC RTL 加入后启用；L21 非专用时钟脚
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDCLK}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN H22 [get_ports {FMC_NBL[0]}]; # A7J1/J1 第37脚 → B15_L7_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_NBL[0]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN J22 [get_ports {FMC_NBL[1]}]; # A7J1/J1 第35脚 → B15_L7_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_NBL[1]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN M17 [get_ports {FMC_SDNWE}]; # A7J1/J1 第33脚 → B15_IO25；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNWE}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN J16 [get_ports {FMC_SDNCAS}]; # A7J1/J1 第31脚 → B15_IO0；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_SDNCAS}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN P17 [get_ports {FMC_A[0]}]; # A7J4/J4 第51脚 → B14_L21_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[0]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN P15 [get_ports {FMC_A[1]}]; # A7J4/J4 第53脚 → B14_L22_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[1]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN R16 [get_ports {FMC_A[2]}]; # A7J4/J4 第55脚 → B14_L22_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[2]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN P16 [get_ports {FMC_A[3]}]; # A7J4/J4 第57脚 → B14_L24_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[3]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN R17 [get_ports {FMC_A[4]}]; # A7J4/J4 第59脚 → B14_L24_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[4]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN R18 [get_ports {FMC_A[5]}]; # A7J4/J4 第61脚 → B14_L20_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[5]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN Y18 [get_ports {FMC_A[6]}]; # A7J4/J4 第76脚 → B14_L13_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[6]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AB22 [get_ports {FMC_A[7]}]; # A7J4/J4 第74脚 → B14_L10_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[7]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AB21 [get_ports {FMC_A[8]}]; # A7J4/J4 第72脚 → B14_L10_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[8]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN Y22 [get_ports {FMC_A[9]}]; # A7J4/J4 第70脚 → B14_L9_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[9]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN Y21 [get_ports {FMC_A[10]}]; # A7J4/J4 第68脚 → B14_L9_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[10]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AB20 [get_ports {FMC_A[11]}]; # A7J4/J4 第64脚 → B14_L15_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[11]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN Y19 [get_ports {FMC_A[12]}]; # A7J4/J4 第78脚 → B14_L13_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_A[12]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN P20 [get_ports {FMC_D[0]}]; # A7J4/J4 第65脚 → B14_IO0；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[0]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN T18 [get_ports {FMC_D[1]}]; # A7J4/J4 第63脚 → B14_L20_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[1]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN N17 [get_ports {FMC_D[2]}]; # A7J4/J4 第49脚 → B14_L21_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[2]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN R14 [get_ports {FMC_D[3]}]; # A7J4/J4 第47脚 → B14_L19_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[3]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AA19 [get_ports {FMC_D[4]}]; # A7J4/J4 第62脚 → B14_L15_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[4]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AB18 [get_ports {FMC_D[5]}]; # A7J4/J4 第60脚 → B14_L17_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[5]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN AA18 [get_ports {FMC_D[6]}]; # A7J4/J4 第58脚 → B14_L17_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[6]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN U18 [get_ports {FMC_D[7]}]; # A7J4/J4 第56脚 → B14_L18_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[7]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN U17 [get_ports {FMC_D[8]}]; # A7J4/J4 第54脚 → B14_L18_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[8]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN W17 [get_ports {FMC_D[9]}]; # A7J4/J4 第52脚 → B14_L16_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[9]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN V17 [get_ports {FMC_D[10]}]; # A7J4/J4 第50脚 → B14_L16_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[10]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN W21 [get_ports {FMC_D[11]}]; # A7J4/J4 第69脚 → B14_L7_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[11]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN T20 [get_ports {FMC_D[12]}]; # A7J4/J4 第67脚 → B14_L6_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[12]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN W20 [get_ports {FMC_D[13]}]; # A7J4/J4 第75脚 → B14_L12_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[13]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN W19 [get_ports {FMC_D[14]}]; # A7J4/J4 第73脚 → B14_L12_P；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[14]}]; # FMC 对应 Bank 为 3.3 V
# set_property PACKAGE_PIN W22 [get_ports {FMC_D[15]}]; # A7J4/J4 第71脚 → B14_L7_N；待 FMC RTL 加入后启用
# set_property IOSTANDARD LVCMOS33 [get_ports {FMC_D[15]}]; # FMC 对应 Bank 为 3.3 V
