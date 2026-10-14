# fmc_record_link 跨时钟与所有权契约

ui_clk/ui_rst负责采集控制，fmc_clk/fmc_rst负责FMC总线及RAM消费者。两个复位来自相同系统复位条件，各自同步释放。两域在链路工作期间持续运行。

FMC域输入bus_read/write、24位字节地址、16位数据和2位字节掩码来自同步SDRAM端口；组合输出register_data和memory_selected在SDCLK边沿供端口锁存。输出rd_en/12位rd_addr/cmd_ack属于FMC域；cfg_samples/cmd_start/cmd_release/cmd_read_next属于UI域。

块描述block_ready/block_last、block_index/block_offset/block_bytes、ack_accepted/ack_rejected/rd_rejected全部属于FMC读端。其余采集/记录/读出状态、accepted/rejected/read_accepted、record_samples/record_bytes/blocks属于UI域。UI状态由128位四相邮箱发布，数据在请求/确认期间保持，接收器增加settling周期。记录32位字段在DONE后稳定，块字段在ACK前稳定。

SET/START/READ_NEXT/RELEASE/CLEAR写入16深度、42位XPM异步FIFO，UI每隔至少一个周期消费一笔，保证状态机看到独立命令脉冲。XPM FIFO复位在写时钟FMC域同步释放。FIFO满/复位忙时拒绝写入并置错；接口没有等待引脚，MCU正常协议应串行执行并轮询确认。

ACK在FMC域执行：仅当block_ready且READ流水线为空才发脉冲；ACK锁会立即屏蔽BLOCK_READY，直到原读块模块收走块。读完末地址不会自动ACK。CLEAR事件使用跨域epoch匹配，避免旧UI快照重新显露被清掉的事件。

寄存器协议见STM32_HANDOFF.md。ACQ_TIME 1..200 ms，乘100000变为ADC样本对数；DATA_WINDOW为0x2000..0x3FFF，单位字节，窗口只读，尾部和无所有权读取返回DEAD并置错。

```json
{"signal":[{"name":"fmc_clk","wave":"p........."},{"name":"SET / START writes","wave":"33........","data":["SET 200","START"]},{"name":"FIFO","wave":".3.3......","data":["SET","START"]},{"name":"ui_clk","wave":"p........."},{"name":"duration_ui","wave":"2..3......","data":["1","200"]},{"name":"cmd_start","wave":"0....10..."},{"name":"sample_limit","wave":"2.....3...","data":["100000","20000000"]}],"head":{"text":"FIFO preserves configuration-before-START ordering"}}
```
