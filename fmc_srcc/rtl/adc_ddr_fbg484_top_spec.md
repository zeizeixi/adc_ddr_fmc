# adc_ddr_fbg484_top 接入契约

ADC、MIG、store和采集VIO沿用旧顶层接口。新增FMC引脚保持16位数据、13位地址、2位bank/mask和SDCLK/CKE/CS/RAS/CAS/WE。SDCLK物理引脚是J20，Bank15 SRCC，LVCMOS33。

FMC_CONTROL=1：BUFG生成fmc_clk，reset_sync生成fmc_rst，store.rd_clk接fmc_clk。SDRAM同步端口和寄存器link使用FMC时钟，命令FIFO与状态邮箱连接UI域。缓存描述和ACK使用原ddr_block_reader的邮箱。读字VIO的FMC域输入被静态置零，防止直接跨域；采集VIO仍使用UI时钟。

FMC_CONTROL=0：store.rd_clk接ui_clk，VIO控制命令和读地址，原读字VIO数据通路恢复；FMC端口disabled。

系统外部复位、时钟失锁和MIG UI复位共同复位两个域。ADC100 MHz采样/转发和MIG200 MHz参考不改。生产源只添加两个新RTL模块，不能加入模拟MIG/采集模块。

```json
{"signal":[{"name":"ADC clock","wave":"p......."},{"name":"ui_clk","wave":"p......."},{"name":"FMC SDCLK J20","wave":"p......."},{"name":"DDR -> RAM write","wave":"0.3.....","data":["8KiB fill"]},{"name":"block_ready","wave":"0...1..0"},{"name":"FMC window reads","wave":"z....33z","data":["A/B data","last word"]},{"name":"ACK","wave":"0......1"}],"head":{"text":"Ownership crosses with a descriptor; RAM read and ACK use FMC clock"}}
```
