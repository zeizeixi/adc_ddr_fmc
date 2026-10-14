# 给STM32工程师：J20同步FMC联调要求

FPGA更换为SRCC同步接口，目标SDCLK为56 MHz。FMC SDRAM Bank2、16位总线和现有分块协议保持不变，不需要增加VALID/中断飞线。ADC采样时钟仍为100 MHz，56 MHz只用于FMC通信。

## 修改位置

### fpga.h

将 `FPGA_FMC_LOW_SPEED_TEST_MODE` 改为 `0U`。

将 `FPGA_FMC_SDCLK_MAX_HZ` 改为 `56000000UL`，最小值可保留 `1000000UL`。正式联调必须检查实际SDCLK为56 MHz；不要因为放宽上限就自动切到84 MHz。ID保持0xADFC，VERSION保持0x0100，寄存器地址和命令值不用改。

### main.c

保留正常168 MHz系统/以太网分支。不要执行 `RCC_HCLKConfig(RCC_SYSCLK_Div16)`。正常调用PHY复位、ETH/LwIP/TCP初始化及 `FPGA_Service()`；每轮继续执行网络维护和TCP命令解析。

如果原main.c只靠该宏选择分支，把宏改0即可进入正常分支；检查正常分支的注释/安全检查不要仍然把新版FPGA当作1..5 MHz接口。

### FPGA_Init() / FMC配置

| 参数 | 值 |
|---|---|
| 实际HCLK | 168 MHz |
| SDCLK分频 | HCLK/3，56 MHz |
| SDRAM Bank | Bank2，基地址0xD0000000 |
| 数据宽度 | 16位 |
| 行地址 | 13位 |
| 列地址 | 8位 |
| 内部Bank | 4 |
| CAS | 3 |
| RPIPE | 2个HCLK周期 |
| ReadBurst / RBURST | 禁用 |
| WriteProtection | 禁用 |
| GPIO | FMC AF12，输出速度按高频接口配置 |

SDCLK和RPIPE是SDCR1中的公共字段，即使访问Bank2也要确认SDCR1有效配置。Bank2的SDNE1/SDCKE1接线沿用现有代码；SDCLK仍是MCU PG8，只是FPGA接收端飞到了J20。

SDRAM时序初始化参数继续使用下表，表中为HAL/SPL传入的周期数，不是手工编码后的寄存器值：

| 参数 | 周期数 |
|---|---:|
| LoadToActiveDelay / tMRD | 2 |
| ExitSelfRefreshDelay / tXSR | 7 |
| SelfRefreshTime / tRAS | 4 |
| RowCycleDelay / tRC | 7 |
| WriteRecoveryTime / tWR | 3 |
| RPDelay / tRP | 2 |
| RCDDelay / tRCD | 2 |

初始化顺序保持：Clock Enable -> 等待至少100 us -> Precharge All -> Auto Refresh（8次）-> Load Mode Register。Bank2命令目标CTB2是SDCMR bit3。模式字为0x0230（BL1、顺序、CAS3、单次写）。AUTO REFRESH为FPGA接受的无操作命令，常规刷新计数可沿用原配置；FPGA的真实DDR刷新由MIG完成，与STM32的SDRAM刷新计数无关。

先等FPGA启动稳定，再发SDRAM初始化序列。如果ID/版本正常但STATUS bit13 MODE_VALID=0，说明模式命令没有被正确接收或发送时FPGA仍在复位，应重试初始化，不能继续取数。ID=0xADFC、VERSION=0x0100、MODE_VALID=1是接口联调第一关；CALIB和READY还需在START前检查。

## 协议与握手不变

全部偏移为字节偏移，所有FMC访问使用 `volatile uint16_t` 读写，不能改成32位总线访问。命令和值写入0xD000000A：START=1，READ_NEXT=2，ACK=3，RELEASE=4，CLEAR_EVENTS=5。

| 名称 | 地址/判断 |
|---|---|
| STATUS | 0xD0000004 |
| EVENTS | 0xD0000006 |
| ACQ_TIME，1..200 ms | 0xD0000008 |
| TOTAL_LEN低/高16位 | 0xD0000014 / 0xD0000016，单位字节 |
| BLOCK_NO低/高16位 | 0xD000001C / 0xD000001E，从0开始 |
| BLOCK_LEN | 0xD0000024，单位字节，最大8192 |
| DATA_WINDOW | 0xD0002000..0xD0003FFF，每块复用 |
| READ_READY | STATUS bit7 |
| BLOCK_READY | STATUS bit8 |
| LAST_BLOCK | STATUS bit9 |
| STREAM_DONE | STATUS bit10 |
| FMC/DDR/溢出错误 | STATUS bits12/11/4 |

SET 200,0只写采集时间；SET 200,1先写时间再START。GET先等DONE+VALID及READ_READY，发READ_NEXT，等BLOCK_READY，读取BLOCK_NO、BLOCK_LEN和LAST_BLOCK，读出恰好BLOCK_LEN/2个16位字。数据窗口读取不会自动推进块。

读完且数据已复制到MCU缓冲区后，清除旧ACK事件再发ACK；轮询ACK_ACCEPTED（EVENTS bit3）并确认BLOCK_READY清零。非末块等READ_READY再READ_NEXT。末块ACK后等STREAM_DONE，再RELEASE，最后等READY。任何错误或拒绝事件必须停止当前取数并报告，不要把旧窗口内容继续当作新块发送。

UI状态通过一致性邮箱更新，命令跨域执行也有延迟：不要用“写命令后立即读一次”代替轮询。保留初始化、采集和取块超时，不能用空循环无限等待。FMC事务结束后再ACK；确认网络发送代码已持有MCU缓冲，不依赖即将释放的FPGA窗口。

先测试SCRATCH地址0xD0000026写0x1234再读回、低字节和高字节掩码写，再执行SET 1,1和GET。正式ADC 100 MSPS时，1 ms应收到400000原始字节：49块，前48块各8192字节，末块6784字节。若TCP仍用ASCII十六进制发送，字符数量是原始字节数的两倍。

参考来源：

- https://www.st.com/resource/en/reference_manual/rm0090-stm32f407-advanced-armbased-32bit-mcus-stmicroelectronics.pdf
- https://www.st.com/resource/en/datasheet/stm32f429ig.pdf

本清单只提出修改要求，没有改动STM32源代码。
