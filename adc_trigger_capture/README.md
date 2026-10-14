# ADC 触发采集：联调候选源码包

本包在之前已经连通的 ADC→DDR→FMC 路径上增加触发采集。原工程没有被覆盖。

**最终需求采用当前值比较：电压、电流各自可选 >、≥、=、≤、<；没有上升/下降沿触发。**
采样点数/时间、前后触发比例、手动/自动、取消等待均已实现。

## 文件与接入

先复制整个现有 Vivado 工程，保留目前能采集、能网口读回的版本。
在副本中处理以下文件：

| 文件 | 操作 | 功能 |
|---|---|---|
| rtl/trigger_geometry.v | 新增 Design Source | 总点数和前触发比例计算 |
| rtl/ads62p24_pack_runtime.v | 替换同名模块 | 连续采样、比较触发、打包和定位 |
| rtl/adc_capture_runtime.v | 替换同名模块 | 配置锁存、跨域控制、ARM/FORCE/ABORT、记录管理 |
| rtl/mig_write_runtime.v | 替换同名模块 | DDR 环形写入 |
| rtl/ddr_block_reader.v | 替换同名模块 | 环形起点重排和任意点数分块读回 |
| rtl/adc_record_store.v | 替换同名模块 | 采集/读回集成接口 |
| rtl/fmc_record_link.v | 替换同名模块 | 新寄存器、命令和状态 |
| rtl/adc_ddr_fbg484_top.v | 顶层集成参考 | 接入新增配置、命令和状态连线 |
| constraints/trigger_cdc_additions.xdc | 添加到 Constraints | 新控制 mailbox 和扩宽状态快照的 CDC 约束 |

顶层是基于之前可读源码快照整理的参考。如果你已在顶层做了新的引脚、复位或时序相关改动，请合并本包新增的触发信号连线，保留这些已验证改动；不要直接覆盖未知差异。
`FMC_CONTROL` 保持 1。每个 module 只能保留一份有效定义，旧文件从当前 sources_1 移除或禁用即可，不要和新文件一起综合。

以下部分沿用你当前已调好的工程：

- `fmc_sdram_sync.v`、`fmc_interface.xdc` 和 J20 SRCC 的 SDCLK 连接。
- MIG、Clocking Wizard、`adc_fifo_256x512`、`adc_raw_ila`、两个 VIO 的 IP 配置。
- `ads62p24_init.v` 当前有效版本（包括你已采用的无 SPI 初始化方案）。
- `reset_sync.v`、`level_sync.v`、`cdc_mailbox.v`、`ram256x16_8k.v`、读回调试模块。
- 原有板级引脚、ADC 输入时序、MIG 和 CDC 约束。

**`reference/` 和 `sim/` 只用于包内仿真，不能整目录添加为板级 Design Sources。**
其中 `reference/ads62p24_init.v` 是旧快照的 SPI 初始化实现，只作仿真依赖，不是要求你恢复 SPI。
`sim/simulation_support.v` 用真实 XPM 模型替代 FIFO IP，并将 ADC ILA 设为仿真占位；上板仍使用原 IP。

## 使用要点

1. STM32 预期版本号改为 **0x0200**。将 `docs/STM32对接协议.md` 发给嵌入式同事，`docs/fpga_trigger_v2.h` 是新增定义参考。
2. 配置点数或时间、前触发百分比、模式、两路比较方式/阈值/使能。
3. 写 ARM=6。手动模式等 HISTORY_READY 后写 FORCE=7；自动模式持续等待条件，可用 ABORT=8 取消。
4. DONE && VALID 后用原 GET 分块流程取数：READ_NEXT=2 → 读窗口 → ACK=3；末块 ACK 后等 STREAM_DONE 再 RELEASE=4。
5. 旧立即采集 START=1 仍可用，但仅支持手动模式、前触发 0%。

比较是 12 位无符号 ADC 码。实际 V/A 转码必须依据模拟前端标定；当前不改 ADC 采样率。
总点数是 A/B 对数，每对 4 字节。100 MSPS 下，1 ms=100000 对=400000 字节。
环形区额外保留一个 256 位突发，最大配置占用 80000032 字节。不得与其他 DDR 使用者共享这段地址。

## 编译与验收

重新综合、实现并生成 bit；新增逻辑不能通过只加载旧 bit 生效。含 ILA 时 bit/ltx 必须来自同一次实现。
重点检查：三个时钟、ADC 输入延迟、FMC 双向总线返回路径、mailbox 的 max-delay/bus-skew，不能靠扩大 false path 消除真实违例。
本包没有生成新板级 bit/ltx，也没有完成你的最新工程的布线时序和上板验收。

历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
复跑功能仿真：在 PowerShell 执行 `./run_tests.ps1 -VivadoRoot ./local_inputs/2023.2`。
脚本要求三套测试的成功标记全部存在，不能仅用 Xsim 进程退出码判断通过。
