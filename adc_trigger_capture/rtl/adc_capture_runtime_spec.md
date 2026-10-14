# adc_capture_runtime 模块说明

锁存配置，建立前触发历史，接收触发/取消，排空 FIFO 和 MIG 写命令后发布记录。

## 合同

- 本包版本：0x0200；时间单位 ns，Verilog-2001。
- 采样率固定 100 MSPS；N=1～20000000 对，时间设置 1～200 ms；两者最后一次设置生效。
- 前触发 P=floor(N×percent/100)，触发样本属于后触发；P=N 时触发样本不在返回记录内。
- 电压 A、电流 B 使用校正后的无符号 12 位码，比较码 0 >=、1 >、2 ==、3 <=、4 <；仅当前值比较。
- 两个有效通道条件按 OR 组合。手动模式忽略比较结果；自动模式无限等待，允许 ABORT。
- 每次 ARM/START 锁存配置；触发后冻结一条记录，读完 ACK/RELEASE 后再开始下一条。
- 地址范围、寄存器和命令完整定义见 ../docs/STM32对接协议.md。

## 时钟与复位

- ADC 接收/触发使用 ADC 返回时钟；采集控制与 MIG 使用 ui_clk；FMC/块消费使用 fmc_clk/rd_clk。
- 端口所属域以本模块连接为准：pack 全在 ADC 域，geometry/writer 全在 UI 域，reader/link 是跨域边界。
- 同一 mailbox 的两端一起复位，复位释放在各域同步；在记录有效期间不得单独复位一端。
- 沿用现有 CDC 约束，并添加 ../constraints/trigger_cdc_additions.xdc；禁止用整片时钟异步 false path 掩盖 mailbox 总线约束。

## 验证与限制

- 仿真入口：../sim/tb_trigger_capture.sv、tb_fmc_trigger_protocol.sv、tb_trigger_geometry.sv。
- 使用真实 XPM FIFO/RAM 模型；MIG 外部存储器由有背压、有读延迟的行为模型代替。
历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
