# J20 SRCC 同步FMC联调包

本包以56 MHz SDCLK为目标。原5 MHz和10 MHz候选目录保留，原Vivado工程没有被覆盖。

## FPGA接入

1. 保存当前可工作的ADC+DDR工程副本。
2. 用 `rtl/adc_ddr_fbg484_top.v` 替换旧FMC顶层。顶层模块名保持 `adc_ddr_fbg484_top`，参数 `FMC_CONTROL=1`。
3. 添加 `rtl/fmc_sdram_sync.v` 和 `rtl/fmc_record_link.v` 到Design Sources。旧 `fmc_sdram_port.v`、`fmc_record_regs.v` 不再被新版顶层实例化，可以从工程移除。
4. 用本包 `fmc_interface.xdc` 替换旧FMC接口XDC，不要叠加旧L21约束。SDCLK的新引脚是J20。其他FMC引脚保持原映射。
5. 保留已经修正并实测可用的ADC/DDR引脚XDC、`runtime_cdc.xdc`、原ADC并行配置代码和全部MIG/ILA/VIO/FIFO IP。不要恢复早期错误ADC引脚表或SPI初始化模块。
6. 保留原 `adc_record_store`、`ddr_block_reader`、`ram256x16_8k`、`cdc_mailbox`、`level_sync`、`reset_sync`。本包顶层将 `u_store.rd_clk` 切换为FMC时钟，现有读块模块已经支持独立读时钟及跨域块描述/ACK。
7. XPM RAM与XPM异步命令FIFO由Vivado内置库实现，不需要在IP Catalog重新建立IP。工程若没有自动识别，Tcl中将 `XPM_LIBRARIES` 设置为 `{XPM_CDC XPM_MEMORY XPM_FIFO}`。
8. `sim` 是验证目录，里面的模拟采集/MIG模块不能加入生产Design Sources。它们只用于仿真和独立接口实现检查。

FMC模式下读字VIO被禁用并隔离跨域输入，采集VIO仍显示UI域状态。需要手动读字时将参数设为0重新生成；此时读时钟和命令均恢复原UI/VIO路径。

## 实际数据路径

ADC -> 原采集FIFO -> MIG/DDR -> 原8 KiB双口RAM。

RAM写端仍使用UI时钟，读端使用J20输入经BUFG得到的FMC时钟。SDCLK的C0上升沿先锁存引脚；C1发起RAM读取；两周期RAM输出在C3被锁存并送到DQ。连续BL1 READ可每个SDCLK读取一个16位字，STM32仍必须使用CAS3、RPIPE2。

采集时间/START/READ_NEXT/RELEASE/CLEAR通过16深度异步命令FIFO按序送到UI域。ACK在RAM读时钟域完成，复用原DDR读块模块的ACK邮箱。UI域状态和记录统计用128位邮箱作一致性快照，存在亚微秒到数微秒的更新延迟，STM32必须轮询，不要假设命令写入后下一条读取立即反映执行结果。

SDCLK在接口工作期间应连续运行。关闭FMC或改变频率后必须重新初始化接口；本包不承诺在SDCLK停止期间完成命令、ACK或状态更新。系统复位异步释放DQ并同步释放各时钟域逻辑。

## 与现有工程的边界

该顶层基于之前提供的FMC集成顶层；ADC、MIG、存储实例的接口沿用原版本，ADC引脚不在本FMC XDC内。若你后续修改过顶层中的其他连线，请按 `TOP_CHANGE_NOTES.md` 将FMC部分合并到最新顶层，避免覆盖自己的其他改动。

引脚J20来自你确认的Bank15 SRCC飞线。原SDCLK引脚L21不再作为顶层SDCLK输入；不能给同一顶层端口保留两个PACKAGE_PIN约束。修正版ADC_DA[10]在H13，早期J20的ADC表不可使用。

## 时序验证边界

`fmc_interface.xdc` 包含输入/输出时序预算。输入参照STM32的SDCLK下降沿；为兼容÷3占空比，约束用短低电平、并扩大最小时序范围。输出使用CAS3+RPIPE2采样模型及STM32 2 ns数据建立时间，另留0.5 ns板级余量。这是联调预算，飞线长度与真实相对延迟尚未测量。

独立接口载体可以检查J20的专用时钟路径及FMC逻辑，不等于完整ADC+DDR工程布局布线或上板证明。重新生成整机bit后，必须检查FMC相关建立/保持时间、邮箱payload约束与CDC报告；不要用 `CLOCK_DEDICATED_ROUTE FALSE` 或全局异步时钟组掩盖违例。

历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
