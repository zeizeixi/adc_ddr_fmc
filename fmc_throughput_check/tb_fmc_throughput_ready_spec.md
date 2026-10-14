# tb_fmc_throughput_ready 契约

无外部端口。实例化 tb_fmc_throughput，DDR_READY_PERIOD=1，PHASE_PS=0，DUTY_SKEW_PS=2976。其他复位、周期、边界和自检规则见 tb_fmc_throughput_spec.md。仅用于仿真。

时序 WaveJSON：`{"signal":[{"name":"ui_clk","wave":"p....."},{"name":"app_rdy","wave":"1....."},{"name":"RAM_READ","wave":"010..."}]}`。未渲染 SVG。
