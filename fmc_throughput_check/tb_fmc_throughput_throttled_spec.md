# tb_fmc_throughput_throttled 契约

无外部端口。实例化 tb_fmc_throughput，DDR_READY_PERIOD=16，PHASE_PS=0，DUTY_SKEW_PS=2976。其他复位、周期、边界和自检规则见 tb_fmc_throughput_spec.md。仅用于仿真。

时序 WaveJSON：`{"signal":[{"name":"ui_clk","wave":"p....."},{"name":"app_rdy_one_in_sixteen","wave":"10...1"},{"name":"RAM_READ","wave":"0..10."}]}`。未渲染 SVG。
