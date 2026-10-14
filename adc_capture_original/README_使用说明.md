# ADS62P24 双通道采样代码（第一版）

这套代码面向 ADS62P24、双通道并行 CMOS、每通道 100 MSPS，完成 ADC 初始化、输入寄存、数据打包、异步 FIFO，并提供可选的 MIG 原生写接口适配器。第一版每次复位后允许一次定长采集，不含预触发环形缓存、FMC 读回、STM32 或网络代码。

默认 `CAPTURE_SAMPLES=20000000`，表示**每通道** 2000 万点，即 100 MHz 采样时钟下 200 ms。两路总计 80,000,000 个有效字节。代码支持 1～20,000,000 点，最后不足 8 个采样对时补零至 256 bit。DDR 空间至少分配 `ceil(CAPTURE_SAMPLES/8)*32` 字节。

## 1. 文件与连接

```
ADC CLKOUT + DA/DB
        │
ads62p24_capture_top
  ├─ ads62p24_init       100 MHz 配置域；上电复位、1 MHz 串行配置
  ├─ BUFG               ADC 输出时钟的全局缓冲
  ├─ ads62p24_pack256    ADC 输出时钟域；双通道寄存、32→256 bit 打包
  ├─ adc_fifo_256x512    FIFO Generator IP；由附带 Tcl 创建
  └─ reset_sync / level_sync
        │ 256 bit valid/ready，MIG ui_clk 域
        ├─ 接你自己的 DDR 写控制器
        └─ 或 mig_native_write256 → 独立生成的 MIG
```

`ads62p24_to_mig256.v` 已把采样顶层和可选写控制器实例化连接起来。它的 `app_*` 端口连接到 MIG；它不是包含 DDR 引脚、板级复位和时钟的完整工程顶层。

`adc_clock_forward_7series.v` 为可选的 100 MHz 差分时钟转发模块，采用 ODDR/OBUFDS。它**不会生成或倍频时钟**。实际核心板的晶振/Clocking Wizard 需另行提供合适的连续 100 MHz 时钟；PLL 锁定且电源稳定后再释放系统复位。ADC 时钟在初始化和 FIFO 复位期间也应运行。

## 2. 需要的时钟

| 时钟 | 要求 |
|---|---|
| `i_sys_clk_100m` | 100 MHz，驱动 ADC 初始化、启动和状态接口 |
| ADC `ADC_CLK_IN_P/N` | 连续 100 MHz 差分时钟，对应每通道 100 MSPS |
| `i_adc_clk_out` | ADC 返回的 CMOS CLKOUT，100 MHz，代码内部经过 BUFG |
| `i_ui_clk` | 新板 MIG 输出的 ui_clk；不要用普通系统时钟替代 |
| `o_adc_sck` | 代码从系统时钟产生的 1 MHz 串行配置时钟 |

MIG 的 sys_clk、clk_ref、DDR 时钟按新板 MIG 配置确定。本代码不假设新板 DDR 与旧 Kintex-7 板一致。

## 3. ADC 端口映射：这一点必须按图接对

原理图沿用了 ADS62P44 的 14 根网络名，但 ADS62P24 的低两根对应 NC：

| 原理图网络 | ADS62P24 实际含义 | 本代码端口 |
|---|---|---|
| `ADC_DA_2`～`ADC_DA_13` | A 通道 D0～D11 | `i_adc_da[2]`～`i_adc_da[13]` |
| `ADC_DB_2`～`ADC_DB_13` | B 通道 D0～D11 | `i_adc_db[2]`～`i_adc_db[13]` |
| `ADC_DA_0/1`、`ADC_DB_0/1` | NC，不作为有效数据 | 不接入采样逻辑 |
| `ADC_CLK_OUT_P` | CMOS 输出时钟，ADC 第 57 脚 | `i_adc_clk_out` |
| `ADC_CS` | ADC SEN，低有效串行片选 | `o_adc_cs_n` |
| `ADC_SCK`、`ADC_SDI`、`ADC_RESET` | 配置与复位 | 对应同名输出 |
| `ADC_CTRL1/2/3` | 并行控制脚 | `o_adc_ctrl[0/1/2]` |

如果上层声明 `[13:0] ADC_DA/DB`，实例化时连接 `.i_adc_da(ADC_DA[13:2])`、`.i_adc_db(ADC_DB[13:2])`。不要截取 `[11:0]`，否则会接入 NC 并丢掉真实高两位。

图中 DRVDD 是 3.3 V，使用并行 CMOS 输出。必须核实接收 Bank 的 VCCO 和 I/O 标准兼容；ADC CLKOUT 必须接适当的时钟能力管脚。不能凭连接器编号推断 FPGA 封装管脚。

## 4. ADC 初始化

复位释放后按 100 MHz 系统时钟：等待 1 ms → RESET 拉高 1 us → 拉低并等待 1 us → 写两个寄存器 → 等待 100 us → `o_cfg_done_sys=1`。

| 串行帧（地址+数据） | 含义 |
|---|---|
| `16'h1480` | 寄存器 0x14：覆盖并行控制、双通道正常工作、并行 CMOS、内部参考、0 dB 粗增益 |
| `16'h1610` | 寄存器 0x16：直二进制输出、正常转换数据 |
| `16'h1614` | 当 `TEST_RAMP=1` 时替代上一帧，输出 ADC 内部数字斜坡测试码 |

SEN 拉低后发 16 bit，地址在前，MSB first。SDI 在 SCLK 上升沿更新，ADC 在下降沿采样，代码为数据/片选保留半个 SCLK 周期的裕量。

`cfg_done` 仅表示初始化序列已经发送并等待完成，**不代表 ADC 寄存器读回验证成功**。原理图中的 SDO 串联电阻标 NC，本版没有依赖读回。初次上板建议使用 `TEST_RAMP=1`，观察 ILA 或读回的数据每通道是否连续，再改回 0 采模拟信号。TEST_RAMP 是编译参数，改变后需重新生成 bitstream。

## 5. FIFO IP 配置

创建 **FIFO Generator 13.2**，模块名必须是 `adc_fifo_256x512`：

| 选项 | 设置 |
|---|---|
| Interface Type | Native |
| FIFO Implementation | Independent Clocks Block RAM |
| Read Mode / Performance Options | First Word Fall Through（FWFT） |
| Input Data Width / Input Depth | 256 / 512 |
| Output Data Width / Output Depth | 256 / 512（输出深度自动计算） |
| Reset Pin | 启用 |
| Reset Synchronization | 启用 |
| Full Flags Reset Value | 1 |
| Embedded Output Registers | 不启用额外寄存器 |
| Dout Reset | 启用，值为 0 |
| Full / Empty | 使用 |
| wr_rst_busy / rd_rst_busy | 使用；复位忙期间禁止读写 |
| Valid / Data Count / Almost Flags / Overflow / Underflow | 本版不需要这些可选端口 |

按配置深度计算约 16 KiB。400 MB/s 数据流完全停止读出时，约对应 40.96 us；这只是空 FIFO 开始的容量估算，不是保证可容忍的最大暂停时间。实际要给已占用空间、CDC 延迟等留余量。

打开你实际核心板的 Vivado 工程后，在 Tcl Console 执行（路径改成解压位置，推荐用正斜杠）：

```tcl
source ./local_inputs/create_fifo_ip.tcl
```

脚本会创建并生成 IP。如果已有同名 IP，脚本会停止，避免修改已有配置。把 `rtl/` 中 `.v` 文件加入 Design Sources；`tb/` 只加入 Simulation Sources。

## 6. 数据格式与 FIFO 握手

ADC 配成直二进制。每路 12 bit 仅高位补零，不做符号扩展：

```verilog
sample_pair = {4'b0000, adc_b[11:0], 4'b0000, adc_a[11:0]};
```

例如 A=0x123、B=0xABC，对应 32 bit 字 `0x0ABC0123`。每个 256 bit 块从低位到高位依次保存 8 个时间连续的采样对：

```
bits [31:0]    = B0:A0
bits [63:32]   = B1:A1
...
bits [255:224] = B7:A7
```

FIFO 输出使用标准 valid/ready 含义：仅在 `i_ui_clk` 上升沿且 `o_valid_ui && i_ready_ui` 时取走一个完整 256 bit 块。消费者不准备好就保持 ready=0；FIFO 的当前有效字会保持。不要把 FIFO 的 `rd_en` 提前一拍发出后再读取本接口。

ADC 输入在 IOB 寄存器中捕获后进入打包器，增加一拍内部延迟。首次启动通过电平同步传播到 ADC 域，因此不是精确到模拟事件那一拍的外部硬触发接口。每次成功采集的数据本身连续且每通道点数准确。

## 7. 启动、完成和错误

1. 启动时对 `i_sys_rst` 和 MIG 本身施加有效复位，等待电源与相关时钟稳定。MIG 的 `ui_clk_sync_rst` 接 `i_ui_rst`；`init_calib_complete` 接 `i_mig_calib_done`。
2. 等待系统域的 `o_ready_sys=1`。它包含 ADC 配置完成、MIG 校准状态、FIFO 复位释放等条件。
3. 在 `i_sys_clk_100m` 域给 `i_start_sys` 一个时钟周期高电平。代码将请求锁存并跨域，不会只靠单周期脉冲直接过同步器。
4. `o_capture_done_sys=1` 表示最后一块已经进入 FIFO，**不等于 FIFO 已排空或 DDR 已写完**。
5. 使用附带的写适配器时，`o_mig_submitted_sys=1` 表示全部写数据及相应写命令已被 MIG 接受。Native UI 没有本模块使用的逐笔 DRAM 写完成响应；这个信号不是断电持久化确认。
6. 完整记录有效需 `capture_done && mig_submitted && !overflow`。出现 `o_overflow_sys=1` 时本次记录无效；代码中止后续采样，保留错误状态，不把不完整记录伪装成成功。此前已入队数据仍可能排出；MIG 总块数完成信号不会正常到达，软件应优先处理错误，不能只无限等待 done。

第一版一个复位周期只接收一次启动，完成后再次启动不会覆盖旧记录。再次采集前，应在数据已读走且下游没有挂起事务后进行协调复位。如果采集中强行复位，MIG 与写控制器必须一起恢复，不能只清空 FIFO 后保留已接收了一半的 MIG 事务。当前没有实现连续重触发协议。

## 8. 可选 MIG 写适配器的适用范围

`mig_native_write256.v` / `ads62p24_to_mig256.v` **仅适用于**：外部 DDR 数据宽度 32 bit、BL8、4:1 用户时钟比例、Native 用户数据宽度 256 bit，即一个完整 DDR burst 对应一个用户数据拍。

新 A7 核心板若是 16 bit DDR / 128 bit 用户接口，不能直接接它，也不能只修改某个端口位宽。应保留前端，另做 256→128 适配并按该 MIG 配置重写 burst 控制，或调整打包/FIFO 宽度。实际 MIG 型号、管脚、sys/ref 时钟和容量仍需要新板资料。

写适配器先提交数据，等 `app_wdf_wren && app_wdf_rdy` 后才提交对应命令；两路暂停时保持各自数据/命令不变，避免命令先发后数据超时。每个块至少使用 3 个 ui_clk 周期，因此 100 MHz 用户时钟下无停顿理论吞吐约 1.067 GB/s。必须按实际停顿验证平均带宽高于 400 MB/s。

`BASE_APP_ADDR` 为 **MIG Native 地址单位**，默认 0，每个 256 bit BL8 块递增 8。不是 AXI 字节地址；在上述 x32 配置下，MIG 地址增 8 对应物理 32 字节。默认记录占用 80 MB，请检查地址空间和其他模块使用区域。`APP_ADDR_WIDTH` 必须等于实际生成的 MIG 端口位宽。

本适配器独占写命令接口，没有 DDR 读出逻辑和读写仲裁。后续接入 FMC 时需设计读出及所有权切换；不能把另一个控制器直接并接到 `app_*`。

## 9. 板级约束与验证边界

未填写 PACKAGE_PIN，因为核心板 FPGA 封装引脚尚未提供。本包不包含可直接下载的新板 bitstream。

- 对 ADC 输出时钟声明 10 ns 周期，并将 ADC 数据约束到该时钟。
- 按 ADS62P24 在 3.3 V CMOS 模式下的时序、PCB 数据/时钟走线偏差填写 `set_input_delay -min/-max`，检查输入建立保持裕量。不能直接把 min/max 都填 0，也不能将 ADC 数据输入全部设为 false path。
- 异步 FIFO 使用生成 IP 自带的 CDC 约束；控制同步器有 ASYNC_REG 属性。对集成后的设计运行 report_cdc、check_timing 和实现后的时序检查。
- 差分采样时钟输出必须核对 P/N 引脚、Bank VCCO、可用 I/O 标准和 ADC 输入电气要求。本包的 ODDR/OBUFDS 仅给出时钟转发结构，不代替板级电气审核。
历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。

## 10. 数据手册依据

- TI ADS62P24 数据手册 SLAS576C，串行接口、寄存器 0x14/0x16、CMOS 引脚和时序： https://www.ti.com/lit/gpn/ads62p24
- TI ADS62P24 产品页： https://www.ti.com/product/ADS62P24
- AMD FIFO Generator PG057： https://docs.amd.com/v/u/en-US/pg057-fifo-generator
- AMD MIG UG586 Native 写接口： https://docs.amd.com/r/en-US/ug586_7Series_MIS/Write-Path

