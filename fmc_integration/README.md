# ADC + DDR + FMC 接入包

本包基于你粘贴的 `adc_ddr_fbg484_top` 修改，不覆盖当前 Vivado 工程。先在已备份的工程副本中使用。

## 加入工程

1. 用 `rtl/adc_ddr_fbg484_top.v` 替换原来的同名顶层，避免同时存在两个同名模块。
2. Add Sources 添加 `rtl/fmc_sdram_port.v`、`rtl/fmc_record_regs.v`，不需要创建新 IP。
3. Add Constraints 添加 `fmc_interface.xdc`。保留原 ADC/DDR XDC、MIG 约束和已有 runtime_cdc.xdc。
4. 如果以前启用了旧 FMC 约束，将旧 FMC 部分禁用，避免同一端口多次赋球位。不要同时添加前一次独立的 fmc_pins_reviewed.xdc。
5. 保持顶层名 `adc_ddr_fbg484_top`，重新综合、实现、生成 bitstream，加载本次配套的 `.bit` 与 `.ltx`。
6. `sim/` 内文件和接口模型仅供仿真，不要添加为 Design Sources。

所有 RTL 同时提供 `text/` 中的纯文本副本，方便复制粘贴。原始顶层保存在 `original_top.txt`。

## 保留哪些功能

ADC 时钟、数据修正、原有采集/DDR存储/8KiB读块模块均不改动；ADC 是否使用固定并行配置由你现有采集子模块决定，本包不会重新加入 SPI 初始化。

顶层参数 `FMC_CONTROL=1`：MCU 控制，两个 VIO 保留状态监视；VIO 的 start、release、read_next、read_word、ack、cfg_samples 不控制存储模块。VIO clear_debug 仍只清自己的显示计数。

将参数改成 `FMC_CONTROL=0` 后重新生成 bit，即恢复原 VIO 控制，FMC 数据脚保持高阻。参数是编译时选择，不是运行时切换。原 ILA 不变。

## 必须匹配的 STM32 设置

这是 SDRAM 协议接口，不是异步 SRAM/FSMC 接法。MCU 为 STM32F429IGB6，SDNE1/SDCKE1 对应 FMC SDRAM Bank2。

| 项目 | 本版要求 |
|---|---|
| 地址基址 | `0xD0000000`，未做 FMC 内存重映射 |
| 总线宽度 | 16 bit |
| Row / Column | 13 bit / 8 bit |
| 内部 bank | 4 |
| CAS | 3 |
| ReadBurst | DISABLE |
| ReadPipeDelay | 2 HCLK |
| SDRAM mode register | `0x0230`：BL1、顺序、CL3、单位置写入 |
| SDCLK | **1～5 MHz**，高低电平各至少 100 ns |
| FPGA ui_clk | 100 MHz，不改 ADC 的 100 MHz |
| 访问宽度 | 联调先用 `volatile uint16_t` |

F429 的 SDCLK 只能是 HCLK/2 或 HCLK/3。**不能保持 HCLK=180 MHz 仅设置 /3，那仍是60 MHz，超出本版范围。**例如 HCLK=12 MHz、SDCLK=HCLK/3=4 MHz。MCU 改系统时钟后应同步调整 SysTick 等外设；本包不修改 MCU 工程。

首次保守设置 LoadToActive=2、ExitSelfRefresh=7、SelfRefreshTime=4、RowCycle=7、WriteRecovery=3、RP=2、RCD=2（单位SDCLK）。按标准流程发送 clock-enable、等待、all-bank precharge、auto-refresh、load-mode。具体 HAL 初始化需与你的 MCU 工程集成。

L21 是普通 I/O，本版不用它驱动 BUFG，也不对它添加 create_clock/CLOCK_DEDICATED_ROUTE FALSE；在 ui_clk 域过采样。输入命令/地址/写DQ需在 SDCLK 上升沿之前稳定至少30 ns，板上需核对。读数据在命令后第3个SDCLK上升沿之后推出，RPIPE=2给过采样和输出延迟留余量。不能直接提速到几十MHz。

## 寄存器表

地址均为基址 `0xD0000000` 的**字节偏移**，每个寄存器16位。32位字段低半字在前。

| 偏移 | 名称 | 说明 |
|---|---|---|
| 0x00 | ID | 只读，应为 `0xADFC` |
| 0x02 | 接口版本 | 只读，`0x0100` |
| 0x04 | STATUS | 状态位，见下 |
| 0x06 | EVENTS | 粘滞事件，写CLEAR_EVENTS命令清除 |
| 0x08 | DURATION_MS | 读写，1～200，复位默认1ms |
| 0x0A | COMMAND | 只写命令；读回0 |
| 0x0C | COMMAND_COUNT | 收到的非全屏蔽命令写入计数，包括被拒绝的命令，16位回绕 |
| 0x0E | LAST_COMMAND | 最近收到的命令值，不表示已成功执行 |
| 0x10 / 0x12 | RECORD_SAMPLES | 实际样本对数低/高16位 |
| 0x14 / 0x16 | RECORD_BYTES | 记录有效字节数低/高16位 |
| 0x18 / 0x1A | BLOCKS | 已提交256位写块数低/高16位 |
| 0x1C / 0x1E | BLOCK_INDEX | 当前8KiB读块序号低/高16位 |
| 0x20 / 0x22 | BLOCK_OFFSET | 当前读块在记录内的字节偏移低/高16位 |
| 0x24 | BLOCK_BYTES | 当前块有效字节数，最大8192 |
| 0x26 | SCRATCH | 读写测试寄存器，支持高/低字节屏蔽 |
| 0x2000～0x3FFF | DATA | 当前读块，只读，半字顺序 A0、B0、A1、B1… |

STATUS：bit0 ready、1 busy、2 done、3 valid、4 overflow、5 cfg_done、6 DDR calib、7 read_ready、8 block_ready、9 block_last、10 stream_done、11 DDR read_error、12 FMC本地错误、13 SDRAM模式有效；14～15保留。

EVENTS：bit0 start_accepted、1 command_rejected、2 read_accepted、3 ack_accepted、4 ack_rejected、5 rd_rejected、6 FMC本地拒绝/错误。CLEAR_EVENTS不清除底层DDR故障。

COMMAND写入整16位：`1=START`，`2=READ_NEXT`，`3=ACK`，`4=RELEASE`，`5=CLEAR_EVENTS`。不是位掩码，不用写0收尾。半字节屏蔽的命令写入会被拒绝。命令是否成功需看事件及状态，不能只看COMMAND_COUNT。

写DURATION_MS不会改变已开始采集的长度；START时锁存 `duration_ms*100000` 对，保持100MSPS前提。非法时长不改变原配置。
块数据越界、未准备好、读缓存超时返回0xDEAD并置本地错误。未知寄存器读回0xFFFF。不能把整个映射区当可写RAM运行内存测试。

## 联调顺序

1. 先只初始化FMC，读ID必须是0xADFC。向SCRATCH写0x55AA、0xAA55、0x0000、0xFFFF并读回；再测试字节写，确认数据线和NBL。
2. STATUS确认mode_valid、calib、cfg_done、ready；写CLEAR_EVENTS。
3. 写DURATION_MS=1，写START=1；确认EVENTS.start_accepted，然后等待1秒。
4. STATUS必须done=1、valid=1、overflow=0、read_error=0、本地错误=0。等待1秒不能替代状态检查。
5. 等read_ready=1，写READ_NEXT=2，轮询block_ready=1。读取BLOCK_INDEX、BLOCK_OFFSET、BLOCK_BYTES。
6. 从 `0xD0002000` 起读取 `BLOCK_BYTES/2` 个16位值。不要自动越过0xD0003FFF；下一块仍使用同一窗口。
7. 所有CPU/DMA读已完成后写ACK=3，等待block_ready清除及read_ready或stream_done更新。清EVENTS后观察新的ack_accepted，避免旧事件误判。
8. stream_done=0时继续下一块；全部结束且读出空闲后写RELEASE=4，等待ready恢复。

先验证1ms=100000样本对=400000字节：48个8192字节块加最后6784字节，共49块。
200ms是80000000字节：9765个整块加最后5120字节，共9766块。1秒是采集完成前的等待，不代表80MB能在1秒内传完。
使用接收回调/分块处理，不要在STM32内部RAM一次分配80MB数组。第一阶段不用DMA，先通过CPU半字读取验证。

## 验证范围与限制

顶层已做xvlog语法检查；两个新模块做过独立综合及XSim联合协议仿真，覆盖连续BL1读、CAS3返回、读写字节屏蔽、跨行、bank隔离、非法命令、超时及复位高阻。仿真下游为匹配现有两拍接口的缓存模型，不能当作MIG/真实DDR全链路验证。
工程既有IP源文件受本机文件保护软件处理，本次没有完整重新综合/布线整个ADC+DDR工程，也没有生成可烧录bit文件。现有时序警告保持待核查。
技能严格格式门禁未通过：已有顶层格式和新模块的分组端口声明触发规范/解析器检查；不能宣称通过该门禁。详情在reports中，Vivado实际编译/仿真/综合证据独立列出。

协议依据：ST RM0090 FMC SDRAM章节（地址映射、CAS、RPIPE、单次访问和读FIFO）：
https://www.st.com/resource/en/reference_manual/rm0090-stm32f407-advanced-armbased-32bit-mcus-stmicroelectronics.pdf
