# 向用户最新顶层合并时的改动

本包完整顶层可直接用于先前FMC集成版本；如果你在此后另改过顶层，按下面的差异合并。

1. 保留原FMC顶层引脚及 `FMC_CONTROL` 参数。
2. 增加 `BUFG u_fmc_bufg`，输入 `MCU_FMC_SDCLK`，输出 `fmc_clk`。增加 `reset_sync u_fmc_reset`，时钟 `fmc_clk`，异步复位 `!sys_rst_n || !locked || ui_rst`，输出 `fmc_rst`。
3. 定义 `wire read_clock = FMC_CONTROL ? fmc_clk : ui_clk;`，将 `u_store.rd_clk` 从UI时钟改接read_clock。存储模块内部已有独立读端复位同步器。
4. 旧 `u_fmc_port` 改为 `fmc_sdram_sync`，不再有sdclk数据端口。它的clk接fmc_clk，rst接fmc_rst，clear_error来自新link。新增 `register_data`、`memory_selected`、`reads_idle`，RAM的 `rd_data/rd_valid` 直接接它的 `memory_data/memory_valid`。
5. 旧 `u_fmc_regs` 改为 `fmc_record_link`，UI时钟/复位接ui_clk/debug_rst，FMC时钟/复位接fmc_clk/fmc_rst。新link的rd_en/rd_addr/cmd_ack属于FMC域；cfg_samples/cmd_start/cmd_read_next/cmd_release属于UI域。原顶层静态选择命令的assign不变。
6. 新link不再用reply_valid/reply_data，改为组合register_data和memory_selected。mode_valid/protocol_error/clear_error连接到同步port；增加reads_idle用于拒绝还未读完就ACK。
7. `readout_debug` 仍在UI域。在FMC模式下，将其RAM读数据、读有效、块描述和ACK事件等FMC域输入置零，避免直接跨时钟采样；FMC_CONTROL=0则保留原连接。采集VIO在UI域的状态连接不变。
8. ADC配置、采样时钟、MIG引脚及原store/capture实例不改。此包没有重新引入SPI初始化。

完整连线以 `rtl/adc_ddr_fbg484_top.v` 为准。
