# 可配置点数 ADC→DDR，第一阶段交付

目标：xc7a200tfbg484-2；ADS62P24 双通道 12 bit、每通道标称 100 MSPS。
日期：2026-09-11。本版先实现 FPGA 采集与 DDR 写入，不含 STM32 程序、FMC 从接口或 DDR 读回控制。

## 1. 文件与使用边界

这是独立源码包，放在 `./local_inputs/runtime_capture_v1`。
不需要读取或解密原工程的 `.v`，不要把两套同名模块同时加入一个工程。
原 `./local_inputs/ad_ddr.xpr` 和原加密文件保持原样；原工程仍是 FBG676，不能把它当成本版 FBG484 工程。
厂家工程只读：`./local_inputs/36_top_ddr3_rw`。
创建脚本从厂家目录复制有效 MIG 和基础 XDC 到新工程，新生成时钟 IP，不修改厂家 IP。

主要模块：

| 文件 | 功能 |
|---|---|
| `rtl/adc_capture_runtime.v` | ADC 初始化、FIFO、配置/结果握手、采集管理和 DDR 写通路 |
| `rtl/ads62p24_pack_runtime.v` | 在 ADC 时钟域锁存点数，精确计数，8 对拼 256 bit，尾补零 |
| `rtl/cdc_mailbox.v` | 带请求/应答的稳定多位数据跨时钟传递 |
| `rtl/mig_write_runtime.v` | DQ32/BL8/4:1 Native 写接口，先数据后命令，地址每块加 8 |
| `rtl/adc_ddr_fbg484_top.v` | 厂家 MIG、50→200/100 MHz 时钟、采样时钟转发、VIO 与采集核心 |
| `rtl/ads62p24_init.v` | 沿用交接包的 ADC 初始化序列 |
| `constraints/runtime_cdc.xdc` | 握手数据总线最大延迟及单比特同步入口约束 |
| `constraints/adc_board_pending.xdc.example` | 待补 ADC 封装管脚、I/O 标准及输入延迟的说明，不自动加载 |
| `tb/tb_runtime.sv` | 实际 FIFO 行为模型下的运行时配置、多次采集与异常测试 |

## 2. 操作接口

命令和状态均属于 **MIG ui_clk 域**。本 MIG 的 ui_clk 按配置为 100 MHz，ADC 初始化使用该时钟。
`cfg_samples` 单位是“每通道采样点数”，也就是双通道采样对数。
合法范围：1～20,000,000。两通道同时采集，不能分别设置长度。

| 端口 | 含义 |
|---|---|
| `cfg_samples[31:0]` | 待采样点数，在接受 START 的时钟沿锁存 |
| `cmd_start` | 上升沿启动；保持高电平不会连续启动，下一次须先回到低电平 |
| `start_accepted` | 接受 START 的一个 ui_clk 周期脉冲 |
| `command_rejected` | 非法点数、忙时启动/释放、同时 START+RELEASE 等的一个周期拒绝脉冲 |
| `ready` | 可接受新采集；含初始化、校准、FIFO 稳定和跨时钟端点就绪检查 |
| `busy` | 从 START 被接受直到写入收尾完成 |
| `latched_samples` | 本次实际锁存的目标点数 |
| `capture_finished` | 已收到 ADC 端结束结果；此时 DDR 写入仍可能没有提交完 |
| `record_done` | 本次已入 FIFO 的全部块及命令均由 MIG 接受；不是物理 DDR 写 ACK |
| `record_valid` | 完整记录有效；只有此信号和 record_done 同时为高才可按正常记录读取 |
| `record_samples` | 成功时为准确点数；溢出时是停止前尝试采样的点数，不代表可用点数 |
| `record_bytes` | 成功时为点数×4；无效记录为 0 |
| `submitted_blocks` | MIG 已接受的数据和命令对应的 32 字节块数 |
| `overflow` | 本次发生 FIFO/打包缓冲溢出，记录无效 |
| `cmd_release` | record_done 后的上升沿释放记录，允许后续新采集覆盖；不是开始采集 |

运行顺序：设置点数 → 等待 ready → START → 等待 record_done → 检查 record_valid → 后续读出 → RELEASE → 等待 ready。
cfg_samples 在采集中任意改变，都不会修改本次目标；START 只在 ready 时有效，不排队。
未来 FMC 桥应将配置/命令可靠握手到 ui_clk，并锁存 accepted/rejected 脉冲，不能把 FMC 时钟域的脉冲和总线直接接入。

200 ms：设置十进制 **20000000**，或十六进制 **0x01312D00**。
100 MSPS 下，点数 = 时长(ms) × 100000；实际时间精度仍取决于实际采样时钟频率。
核心保证计数，不对板上尚未确认的晶振频率误差作保证。

## 3. DDR 格式及重复采集

每对样本 `{4'b0,B[11:0],4'b0,A[11:0]}`，每 8 对组成一个 256 bit 数据块，最早样本在最低 32 bit。
尾块不足 8 对补零。DDR 占用 `ceil(N/8)*32` 字节，有效数据 `N*4` 字节。
Native 地址默认从 0 开始，每块增加 8，**不是字节地址**。
2000 万对共 2,500,000 块、80,000,000 字节。
旧记录释放后，下一次采集从相同起点覆盖；较短新记录后面的旧内容不会自动擦除，读出必须遵守新有效长度。

正常重复采集不复位 MIG、不重新初始化 ADC，也不在事务中途清空 FIFO。
溢出时 ADC 停止，已排队块继续提交；待写事务全部排空后报告 done 且 valid=0，RELEASE 后可重试。
若 MIG 永久不再接受事务，busy 可能持续为高；此时不能强行 RELEASE 清除半笔事务。
本版无主动 ABORT/超时恢复；强制中断需协调复位采集核心和 MIG，记录作废。
外部全局复位和 MIG ui_rst 会同时复位采集两域及握手状态；单独复位某个握手端不受支持。

## 4. 创建新的 FBG484 工程

PowerShell 示例（目标目录必须尚不存在；传给 Tcl 的路径统一使用正斜杠）：

```powershell
& './local_inputs/vivado.bat' -mode batch -source './local_inputs/create_project.tcl' -tclargs './local_inputs/adc_runtime_fbg484'
```

然后打开 `./local_inputs/adc_runtime.xpr`。
顶层为 `adc_ddr_fbg484_top`，器件固定 FBG484。
脚本创建 FIFO、独立 Clocking Wizard（50 MHz 输入，200/100 MHz 输出）和 VIO，导入有效 MIG。
请保留厂家的 `mig_b.prj` 选择，不要混用另一个 `mig_7series_0` 目录或 `mig_a.prj` 配置。

本次建工程和 4 个 IP 状态检查成功，但板级 RTL 展开未通过：公司加密软件处理了 Vivado 新生成的 `capture_clocks.v`，展开进程报告找不到 capture_clocks 模块。未尝试解密或绕过。需要在公司认可、可正常处理这些受保护文件的 Vivado 环境中重新生成 IP 并执行 `scripts/check_elaboration.tcl`；本包不能视为已经综合通过的工程。

VIO 输出：probe_out0 为 cfg_samples（默认 20000000），probe_out1 为 START，probe_out2 为 RELEASE。
START/RELEASE 均采用 0→1→0 操作。VIO 输入按顶层映射展示 ready、busy、done、valid、overflow、点数、字节数、块数和初始化状态。
VIO 是首阶段调试入口，不是最终客户使用界面。

## 5. 仍需补齐才能上板

- ADC 核心板连接器到 FBG484 封装脚号映射、Bank VCCO 和时钟引脚能力。
- ADC 数据输入延迟、返回时钟约束、差分输出电气标准。
- 实现后的 CDC 检查、时序收敛、MIG 校准和实际 DDR 读回。
- DDR 读控制、读写接口切换、8 KiB 分块 RAM 和 FMC SDRAM 从接口。

当前没有完整 ADC XDC，**不要直接生成/下载 bitstream**；不能用默认 I/O 标准或 false path 掩盖缺失约束。
runtime_cdc.xdc 中的多位传递使用源端锁存、保持到 ACK、目的端等待后一次采样的结构；实现时必须检查最大延迟约束实际命中两个 mailbox，且 report_cdc 的相关路径得到人工核查。
仿真不能验证亚稳态或板级模拟性能。

## 6. 运行仿真

```powershell
& './local_inputs/run_tests.ps1' -WorkDir './local_inputs/runtime_sim_01'
# 如需检查完整 2000 万对（更耗时）：
& './local_inputs/run_tests.ps1' -WorkDir './local_inputs/runtime_sim_full' -FullLength
```

Vivado/XSim 默认本机 `./local_inputs/bin`；其他安装位置通过 `-VivadoBin` 指定。
实际 FIFO 模型库使用 `fifo_generator_v13_2_9`；工具升级后需核对库版本。
MIG 在功能测试中使用握手/数据顺序检查模型，不是 DDR PHY 或颗粒模型。
历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
