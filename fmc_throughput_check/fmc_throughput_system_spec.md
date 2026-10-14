# fmc_throughput_system 契约

本模块是验证模型，不可替换生产 adc_ddr_fbg484_top。输入 ui_clk、reset_n、MCU_FMC_SDCLK、MCU_FMC_SDCKE1、MCU_FMC_SDNE1、MCU_FMC_SDNRAS、MCU_FMC_SDNCAS、MCU_FMC_SDNWE 各 1 位，MCU_FMC_A 13 位，MCU_FMC_BA 与 MCU_FMC_NBL 各 2 位；MCU_FMC_D 为 16 位双向数据总线。

UI=100 MHz，FMC 约 56 MHz，两域由 reset_sync 从共同低有效 reset_n 复位。采用 SDRAM BL1、CAS3、单次写、MRS 0x0230。固定记录元数据为 2058 组样本、8232 字节和 258 个 256 位输出块。

DDR_READY_PERIOD 必须为正整数。MIG 模型每该数量 UI 周期可接受一个命令；仅接受 app_en && app_ready 的请求，32 UI 周期后顺序返回 256 位数据和有效结束标记。不制造无请求返回，不提供物理 DDR 校准、刷新、电气与拥塞的全模型。

真实 reader 将响应写入 XPM RAM，再发布描述符。读端采用真实 READ_LATENCY_B=2。块内容在 ACK 前保持，采集 START/RELEASE 由小型行为模型维护 ready/done/valid，仅用于握手夹具。

时序 WaveJSON：`{"signal":[{"name":"ui_clk","wave":"p......."},{"name":"app_rdy","wave":"10..10.."},{"name":"app_en","wave":"1...1..."},{"name":"returned_after_32_cycles","wave":"0...1.0."}],"head":{"text":"命令背压与固定模型返回延迟，示意非比例"}}`。未渲染 SVG。
