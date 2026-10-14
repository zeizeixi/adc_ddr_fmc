# ADC 触发采集协议 V2（0x0200）

## 1. 已确认的行为

- A 路是电压：外部电路从 JP1、JP3 二选一接入；B 路是电流：JP2、JP4 二选一接入。
- 两路分别配置阈值、比较方式、使能；任意一个已使能通道满足条件就触发一次。
- 只比较当前采样值，**没有上升沿、下降沿检测**。
- 手动模式：ARM 后先建立历史，HISTORY_READY 后写 FORCE。FORCE 经跨时钟握手到达 ADC 域后触发，不对应电脑发送命令的精确时刻。
- 自动模式：ARM 后先建立历史，再持续比较。一直等待，不设超时；允许 ABORT 取消。
- 触发后收完剩余点数，冻结记录；GET 读取这一条记录，不采集 GET 时刻的新数据。
- 采样率固定为每通道 100 MSPS。一个“点”指同时采到的一对 A/B；每对 4 字节。
- 配置在 ARM/START 接受时锁存。等待期间改配置只影响下一次记录。

## 2. 总长度与前后比例

总点数 N 可以通过两种方式设置，最后写入的长度设置生效：

1. 写 TIME_MS，范围 1～200 ms，N = TIME_MS × 100000。
2. 写 N 的低、高 16 位，范围 1～20000000 对；两半都写完后才能 ARM。

前触发点数 P = floor(N × PRE_PERCENT / 100)，后触发点数 Q = N − P。
P% 是**总记录内部**的前触发比例，采样时间也是整条记录长度，不是额外的后触发时长。

- PCT=0：全部为触发后数据，触发样本是第 0 对。
- 0<PCT<100：触发样本是第 P 对，属于后触发部分。
- PCT=100：返回触发前的 N 对，不含触发样本；触发位置为 N，即记录末尾之后。
- 历史填满前的触发条件不锁存。历史填满后，若当前值仍满足条件，则立即触发。

## 3. FMC 基本约定

基地址 `0xD0000000`；16 位半字访问；下表全是**字节偏移**。
所有控制写入使用完整 16 位写。32 位值按低半字、高半字组合。
FMC 底层继续使用已联调成功的参数：HCLK=168 MHz、SDCLK=56 MHz、CAS=3、RPIPE=2、RBURST=0、BL=1。
保留原初始化流程和已修正的 FPGA `fmc_sdram_sync.v`，版本检查改为 `0x0200`。

## 4. 寄存器表

| 偏移 | 名称 | 属性 | 含义 |
|---|---|---|---|
| 0x0000 | ID | R | 0xADFC |
| 0x0002 | VERSION | R | **0x0200** |
| 0x0004 | STATUS | R | 原状态位定义，见下文 |
| 0x0006 | EVENTS | R | 命令接受/拒绝事件，保持到 CLEAR_EVENTS |
| 0x0008 | TIME_MS | RW | 1～200；写入更新 N；点数模式下读为 0 |
| 0x000A | COMMAND | W | 命令码 1～8，读为 0 |
| 0x000C | COMMAND_COUNT | R | 命令寄存器写次数，16 位回绕 |
| 0x000E | LAST_COMMAND | R | 最近写入的命令 |
| 0x0010/12 | RECORD_SAMPLES L/H | R | DONE 且 VALID 后的实际 A/B 对数 |
| 0x0014/16 | TOTAL_LEN L/H | R | 有效字节总数，N×4 |
| 0x0018/1A | DDR_WRITE_BURSTS L/H | R | 累计提交的 32 字节 DDR 写突发数，含等待期间环形覆盖；**不是 GET 分块数**，32 位回绕 |
| 0x001C/1E | BLOCK_NO L/H | R | 当前 8 KiB 读块序号，从 0 开始 |
| 0x0020/22 | BLOCK_OFFSET L/H | R | 当前块在逻辑记录中的字节偏移 |
| 0x0024 | BLOCK_LEN | R | 当前块有效字节数，最大 8192 |
| 0x0026 | SCRATCH | RW | 16 位读写联调寄存器，支持字节掩码 |
| 0x0028/2A | CFG_SAMPLES L/H | RW | 设置下一条记录的总 A/B 对数 |
| 0x002C | PRE_PERCENT | RW | 前触发百分比，0～100，默认 0 |
| 0x002E | TRIGGER_MODE | RW | 0 手动；1 自动；默认 0 |
| 0x0030 | VOLTAGE_THRESHOLD | RW | A 路校正后的 12 位 ADC 阈值码，0～4095，默认 4095 |
| 0x0032 | CURRENT_THRESHOLD | RW | B 路阈值码，0～4095，默认 4095 |
| 0x0034 | TRIGGER_ENABLE | RW | bit0 电压、bit1 电流；默认 3；自动模式不能为 0 |
| 0x0036 | TRIGGER_STATUS | R | 触发状态，见下文 |
| 0x0038/3A | ACTIVE_PRE_SAMPLES L/H | R | 本次锁存配置计算出的 P；DONE 时也就是触发位置 |
| 0x003C/3E | SAMPLE_RATE_HZ L/H | R | 100000000 Hz |
| 0x0040 | LENGTH_MODE | R | 0 时间设置；1 点数设置 |
| 0x0042 | VOLTAGE_COMPARE | RW | A 路比较方式，0～4，默认 0 |
| 0x0044 | CURRENT_COMPARE | RW | B 路比较方式，0～4，默认 0 |
| 0x2000～0x3FFF | DATA_WINDOW | R | 当前块窗口，所有块重复使用同一个窗口 |

比较方式编码（两路相同）：

| 值 | 条件 |
|---|---|
| 0 | 当前码值 ≥ 阈值 |
| 1 | 当前码值 > 阈值 |
| 2 | 当前码值 = 阈值 |
| 3 | 当前码值 ≤ 阈值 |
| 4 | 当前码值 < 阈值 |

这是无符号 ADC 码值比较，不是绝对值比较，也不是带迟滞/容差的比较。`=` 表示严格相等。
FPGA 比较值与存储值一致：沿用原工程输入取反校正后，A/B 各 12 位。
STM32 负责把用户输入的 V/A 通过实际标定换成 ADC 码；若模拟通道为负斜率，换算时还需反转比较方向。
未标定前请直接用 ADC 码调试，不要假定 1 V 或 1 A 对应固定码值。

## 5. 状态与事件

STATUS：bit0 READY，bit1 BUSY，bit2 DONE，bit3 VALID，bit4 OVERFLOW，bit5 CFG_DONE，bit6 CALIB，bit7 READ_READY，bit8 BLOCK_READY，bit9 LAST_BLOCK，bit10 STREAM_DONE，bit11 DDR_READ_ERROR，bit12 FMC/COMMAND_ERROR，bit13 MODE_VALID。

TRIGGER_STATUS：

| 位 | 含义 |
|---|---|
| 0 | ARMED：ADC 已开始本次采样，尚未触发；配置准备阶段可能仍为 0 |
| 1 | HISTORY_READY：前触发历史足够；手动 FORCE 必须等待它为 1 |
| 2 | TRIGGERED：本次已触发 |
| 3 | BUSY 且 TRIGGERED：触发后正在收尾，包括采样、FIFO/DDR 排空 |
| 4 | ABORTED：本次被取消；下次接受 ARM/START 时清除 |
| 5 | 电压触发原因，DONE 后有效 |
| 6 | 电流触发原因，DONE 后有效；两路同拍满足可同时置位 |
| 7 | 手动触发原因，DONE 后有效 |

EVENTS：bit0 START/ARM_ACCEPTED；bit1 COMMAND_REJECTED；bit2 READ_ACCEPTED；bit3 ACK_ACCEPTED；bit4 ACK_REJECTED；bit6 本地命令/访问错误。
FORCE 没有独立的成功事件：清事件后写 FORCE，观察 TRIGGERED 或 COMMAND_REJECTED。
不要把 READY=0 当成出错：等待自动触发时 READY=0、BUSY=1 是正常状态。
STATUS、TRIGGER_STATUS 来自跨域快照，允许短暂滞后；重复轮询，不要求相邻两次读严格属于同一时刻。
DONE/VALID 后元数据保持到 RELEASE，可安全分两次读取 32 位长度。活动期间的 DDR_WRITE_BURSTS 仅供诊断，读它需采用高-低-高复读。

## 6. 命令表：全部写 0xD000000A

| 值 | 命令 | 使用条件 |
|---|---|---|
| 1 | START | 兼容旧立即采集；仅手动模式且 PRE_PERCENT=0 |
| 2 | READ_NEXT | READ_READY=1 后请求下一块 |
| 3 | ACK | 当前块数据已复制完成、FMC 读事务已结束 |
| 4 | RELEASE | 正常最后一块 ACK 完成后释放记录；也允许在无块占用时主动丢弃剩余记录 |
| 5 | CLEAR_EVENTS | 清命令事件/本地错误；不清记录，不等于 ABORT |
| 6 | ARM | READY=1 时锁存配置，开始建立前触发历史 |
| 7 | FORCE | 本次为手动模式，且 ARMED/HISTORY_READY=1 |
| 8 | ABORT | BUSY=1 时取消准备/等待/采集；排空后 READY=1、VALID=0 |

启动前确认 READY/CFG_DONE/CALIB/MODE_VALID=1，错误位 4/11/12=0。
先清事件、轮询确认旧事件已清，再发 ARM/START。等 EVENTS bit0 或 bit1，不要只凭写成功判断 FPGA 接受。
非法点数、类型或自动模式禁用所有通道会被拒绝。不要用循环连续写 CLEAR_EVENTS 的方式等待命令完成。
若采集溢出，DONE=1、VALID=0、OVERFLOW=1，不能 GET；在读端空闲时 RELEASE 后重试。
ABORT 取消未完成记录；若记录已 DONE，请用 RELEASE，不要继续 ABORT。

## 7. 对接流程

自动采集示例：100000 对（1 ms）、前触发 30%、A ≥ 2500 或 B < 1500。

```c
// FPGA_Read16/Write16 的 offset 均是字节偏移；省略通信层超时和错误返回处理。
FPGA_Write16(0x0028, 0x86A0);  // 100000 的低 16 位
FPGA_Write16(0x002A, 0x0001);  // 高 16 位
FPGA_Write16(0x002C, 30);
FPGA_Write16(0x002E, 1);       // 自动等待
FPGA_Write16(0x0030, 2500);
FPGA_Write16(0x0042, 0);       // A >=
FPGA_Write16(0x0032, 1500);
FPGA_Write16(0x0044, 4);       // B <
FPGA_Write16(0x0034, 3);       // 两路使能，OR
// 确认初始 READY，清 EVENTS 并等待清除后：
FPGA_Write16(0x000A, 6);       // ARM
// 轮询 EVENTS 接受/拒绝；接受后等 DONE && VALID。
```

手动采集：MODE 写 0，配置 N/PRE；ARM；等 HISTORY_READY；清事件并等待清除；写 COMMAND=7；等 DONE && VALID。
手动模式忽略两路阈值和比较结果。若希望保留旧 `SET 1,1` 的立即采集行为，需配置 MODE=0、PRE=0，然后写 TIME_MS=1、COMMAND=1。
其他触发配置使用 ARM=6，不要直接复用旧 START=1。

正常 GET：

1. DONE && VALID && READ_READY 后锁存 TOTAL_LEN。
2. 清旧命令事件，写 READ_NEXT=2；等待 BLOCK_READY，检查错误位。
3. 在 ACK 前读取 BLOCK_NO、BLOCK_LEN、LAST_BLOCK；校验块号顺序及长度。
4. 从 `0xD0002000` 开始，连续读 BLOCK_LEN/2 个半字，先复制到 STM32 缓冲。
5. 确认 FMC 读操作结束，清 ACK 事件，写 ACK=3；等待 ACK_ACCEPTED；被拒绝则停止发送并报错。
6. 非末块等 READ_READY 再请求下一块。末块 ACK 后等 STREAM_DONE=1，再写 RELEASE=4，等 READY=1。

ACK 只释放 FPGA 当前块缓存，不表示 TCP 接收端已收到。若先 ACK 再发 TCP，STM32 必须持有独立副本，发送完成前不能复用它。
只有实际发送/接收有效数据长度累计达到 TOTAL_LEN，才输出传输结束标志。TCP 分包边界不是 FPGA 块边界。
不要把 `*` 当二进制 ADC 数据中绝不会出现的字节；上位机先按 TOTAL_LEN 收满数据，再解析结束标志。
自动等待期间仍需调度网口服务，并允许用户取消；不能把 CPU 卡在无限阻塞轮询中。

数据顺序保持：每对先 A 半字，再 B 半字，各高 4 位为 0。TCP 的二进制/ASCII 和字节序继续由 STM32 发送协议规定，FMC 不自动转换。

## 8. STM32 需要修改的部分

1. 预期 VERSION 改为 0x0200，新增上表配置寄存器和 ARM/FORCE/ABORT。
2. 参数设置阶段只写配置；ARM 是开始采集准备，FORCE 是手动触发，GET 是读取完成记录。
3. 增加等待触发状态，不使用旧“开始后固定毫秒数必须 DONE”的超时判断。
4. 原 READ_NEXT/ACK/RELEASE 取数流程保留；总块数按 ceil(TOTAL_LEN/8192) 计算，不读取 0x18 当总块数。
5. TCP 文本命令名称由 STM32 工程统一定义；上述 FMC 地址/数值是本版 RTL 的正式约定。
