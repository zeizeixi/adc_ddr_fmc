# fmc_test_system 独立验证载体

仅用于仿真与独立FMC接口布局布线。它实例化交付的同步端口、跨域link、原ddr_block_reader及实际XPM RAM。BUFG和复位同步器与生产顶层相同。UI时钟输入为100 MHz；SDCLK来自仿真主机或实现约束中的J20。

START后模拟20个UI周期采集，固定记录8232字节。模拟MIG按读命令返回16位模式 `A500 xor global_word_index`，连续UI回复，分成8192+40字节两块。采集/MIG模型不是生产功能，不能导入生产Design Sources。

```json
{"signal":[{"name":"cmd_start","wave":"010......."},{"name":"capture busy","wave":"0.1..0...."},{"name":"record_done","wave":"0....1...."},{"name":"READ_NEXT","wave":"0.....10.."},{"name":"block_ready","wave":"0.......1."}],"head":{"text":"Modeled acquisition; real block-reader/RAM"}}
```
