# 原理图引脚核对版（无 LED、未飞线）
这份资料按用户提供的自研底板 A7J1～A7J4、核心板 J1～J4、Bank14/15/16/34 图逐级对应，假设同编号直接对插。pin_map.csv 保留完整对应链，供原理图/PCB核查。不是可直接下载的最终 XDC。

## 文件使用
- adc_original_pins.xdc.example：ADC 原接线球脚映射。Bank14/15/16 按此前电源图 3.3V 标注 LVCMOS33；Bank34 没有填写不兼容的电平标准。暂勿批量启用做 bitstream。
- fmc_future_pins.xdc.example：未来 FMC 端口映射，全部注释；现有顶层还没有这些端口。
- adc_ddr_fbg484_top.v：以已交付 board_readout 顶层为基线，仅删除 led 输出及其 assign。其余 RTL/IP 保留；本次未重跑整工程综合。
- DDR继续使用 MIG 自带约束。系统时钟/复位沿用确认的厂家配置。厂家 top.xdc 中所有 led 约束需从用户工作副本中移除，厂家原文件不改。
- 本文件不包含 ADC input_delay：它需要 ADC 输出时序及板级偏差，不能凭球脚表编造。

## 必须保留的问题
历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
2. ADC_CLK_OUT_P：A7J1-4 → B15_L4_N → G18，为普通 IO，不是 MRCC/SRCC。原ADC采样时钟全局路由需要解决，不添加 CLOCK_DEDICATED_ROUTE FALSE 掩盖。
3. FMC_SDCLK：A7J1-39 → B15_L10_N → L21，也不是 MRCC/SRCC；未来FMC时钟路由需单独设计检查。
4. ADC_CLK_IN_P 在 V8（物理N侧），ADC_CLK_IN_N 在 V9（物理P侧）。现有 OBUFDS 的逻辑 P/N 对应与该原接线反向；不能把球脚名称按逻辑猜换，也不能称现有时钟输出已可用。
5. ADC_CS/SDI/SCK/RESET 和输入采样时钟输出端位于 Bank34，该 Bank 在先前电源图中为1.35V。ADC数字电平与差分时钟标准问题仍待解决。未因“先沿用原接线”而改变Bank电源假设。
6. ADC_DA0/1、DB0/1 为前述 ADS62P24 模式下的 NC，不属于当前 [13:2] 数据端口；本次不重新利用这些线。ADC_SDO 当前顶层未使用，也未分配。
7. ADC_CTRL[0/1/2] 分别对应原理图 CTRL1/2/3。

本次检查确认映射中没有重复分配球脚；之前的 Vivado 器件库核对及无 LED 顶层语法检查日志随包保留；该历史球脚日志不是更正后整张映射的验证报告，球脚存在也不能证明连接器转录正确。G18、L21 的 IS_CLK_CAPABLE 均为 0。Bank15 原图 B15_L23_P/K16、B15_L23_N/L16 的网络命名与器件库物理 P/N 相反，表格按原图网络到球脚的连线保留，不按网络名称猜换球脚。尚未完成完整布局布线、板级电气或实物连通性验证。请保留这些限制，不把 example 文件当作已验证的完整约束。



