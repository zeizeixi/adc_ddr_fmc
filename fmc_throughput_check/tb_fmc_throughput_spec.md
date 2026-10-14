# tb_fmc_throughput 契约

无外部端口，仅为独立吞吐验证顶层。参数 PHASE_PS、HALF_PERIOD_PS、DUTY_SKEW_PS 指定 FMC 时钟，相位测试包装选择 0 ps、半周期 8929 ps、偏移 +2976 ps；DDR_READY_PERIOD 指定模型每多少 UI 周期可接受命令。UI 周期 10 ns，reset_n 为测试系统低有效复位。

测试记录固定为 8232 字节，包含一个 8192 字节整块和一个 40 字节尾块。真实 ADC 采集与物理 MIG 不在测试范围。使用实际分块 reader、CDC、真实 XPM RAM/FIFO 和交付的 FMC 接口，数据模式为 0xA500 XOR 全局半字序号。

每个 16 位 READ 间隔六个 SDCLK 周期，读返回在 C3 前 2 ns 自检。测量 UI READ_NEXT 到 BLOCK_READY、完整块读取、尾块读取、ACK 到 UI 进展，以及最终 RELEASE 流程。还保留寄存器、字节掩码、非法访问和异步复位释放 DQ 检查。

块就绪轮询上限 2000 次，覆盖注入模型的约 41 µs 装块时间；全局上限 3 ms。失败使用 $fatal，成功以 FMC_SRCC_PASS 与检查计数结束。

逻辑时序 WaveJSON：

```json
{"signal":[{"name":"SDCLK","wave":"p........."},{"name":"READ_NEXT","wave":"010......."},{"name":"BLOCK_READY","wave":"0..1....0."},{"name":"RAM_READ","wave":"0...10...."},{"name":"DQ_VALID","wave":"0.....10.."},{"name":"ACK","wave":"0......10."}],"head":{"text":"装块 → RAM 读取 → 明确 ACK；示意不按比例"}}
```

WaveJSON 未渲染成 SVG，不作为已渲染图形验收。
