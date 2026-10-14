# tb_fmc_srcc 验证范围

UI100 MHz与SDCLK约56 MHz相互独立。参数PHASE_PS改变相位，DUTY_SKEW_PS改变高/低脉宽；测试包含50%、约33%、约67%占空比。SDRAM主机在下降沿后0.5 ns驱动，在上升沿后1 ns撤销命令，C3+两个HCLK周期检查DQ。

检查ID、版本、模式、16位和字节掩码scratch、相邻SET200/START传输顺序、STATUS轮询、全8KiB块连续4096字读取、行边界、块号、ACK、40字节末块及其越界、STREAM_DONE/RELEASE、非法ACK/SET和事件清除、无所有权窗口读取、DQ有效期间系统复位。

测试使用真实XPM异步FIFO、真实不对称XPM RAM及现有ddr_block_reader/cdc_mailbox。采集完成和MIG读回复由fmc_test_system模拟，不能代表真实ADC/MIG上板验证。

```json
{"signal":[{"name":"READ","wave":"1000...."},{"name":"SDCLK","wave":"p......."},{"name":"DQ","wave":"z..3z...","data":["expected"]},{"name":"scoreboard sample","wave":"0..10..."}],"head":{"text":"C3 plus RPIPE2 sampling"}}
```
