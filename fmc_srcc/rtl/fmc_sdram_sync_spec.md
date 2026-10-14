# fmc_sdram_sync 时序契约

时钟clk来自J20上的SDCLK，经BUFG。rst高有效，状态同步复位，DQ三态寄存器异步置为关闭；enabled为静态所有权参数。

输入：cke/cs_n/ras_n/cas_n/we_n、13位地址、2位bank/dqm和双向16位DQ。C0锁存输入，C1解码。四个13位行寄存器按ACTIVE更新，PRECHARGE关闭指定行，MRS仅接受bank0、0x230。READ/WRITE的24位字节地址为 `{bank,row,column[7:0],1'b0}`。

输出bus_read/bus_write、bus_addr/bus_wdata/bus_mask在C0锁存输入后稳定，在C1被寄存器/FIFO/RAM采样。register_data是FMC域组合返回值，memory_selected是当前窗口地址合法且块归属有效的选择信号。memory_data/memory_valid来自相同clk域的两周期RAM读端。

C0 READ锁存，C1启动RAM，C2后RAM数据有效，C3上升沿锁存并推出DQ。寄存器读取也在C3推出。连续READ的每个C3响应与自己的C0命令对应，DQM读掩码采用两SDCLK周期延迟。单次READ输出保持一个SDCLK周期，NOP时不驱动DQ。

reads_idle只表示READ流水线为空，用于ACK限制。非法行/模式或缺失RAM响应置protocol_error并返回0xDEAD。clear_error清除sticky protocol_error；模式只能通过MRS或复位改变。CKE低会停止读流水线并关闭DQ，存在在途读时置错。SDCLK必须持续运行；复位期间即使停止时钟也关闭DQ。

实体寄存器输入使用fabric FF，避免HR-bank IOB自动ZHOLD延迟；数据和独立三态输出FF保留IOB属性，三态FF保留DONT_TOUCH以防16个等价输出使能被合并。

目标：56 MHz，CAS3、RPIPE2；XDC预算不代替实测飞线延迟。验证包括完整4096字连续读取、相位及占空比变化、末块越界、非法命令和输出期间复位。

```json
{"signal":[{"name":"SDCLK","wave":"p......"},{"name":"pin command","wave":"3......","data":["READ C0"]},{"name":"bus_read / RAM enable","wave":"01....."},{"name":"RAM valid","wave":"0.1...."},{"name":"DQ response","wave":"z..3z..","data":["data C3"]}],"head":{"text":"READ C0 -> RAM request C1 -> DQ C3"}}
```
