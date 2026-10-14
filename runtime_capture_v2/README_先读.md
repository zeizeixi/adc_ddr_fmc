# 可设采样长度：采集与 DDR 分块读出 v2

本包在 v1 采集写入模块上增加 DDR 顺序读出、8 KiB 双时钟 RAM 和显式块确认。厂家 MIG、DDR 引脚和原工程保持原样；本包没有替换实际板级顶层，也没有实现 STM32 FMC 总线协议。

## 本次新增

| 文件 | 用途 |
| --- | --- |
| rtl/adc_record_store.v | 连接原采集模块与读出模块，分配 MIG 命令接口 |
| rtl/ddr_block_reader.v | 每次从 DDR 读最多 8192 字节，传递块信息并等待 ACK |
| rtl/ram256x16_8k.v | XPM 双时钟块 RAM：256 位写、16 位读 |

rtl 中另外七个文件是独立复现所需的 v1 支持模块。已有工程不要重复添加同名模块。FIFO 继续使用已经迁移到 xc7a200tfbg484-2 的 adc_fifo_256x512，256 位、512 深度、独立时钟、FWFT。

ADC 串行初始化默认等待更新为 100 MHz 下上电等待 5 ms、配置后等待 3 ms；前提是释放全局复位时 ADC 电源已稳定。集成模块显式传递这些参数。若配置时钟不是 100 MHz，必须相应调整周期数。硬件同事最终若改用并行静态配置，还需相应修改初始化接口。

## 工作顺序

1. 等待 ready，设置 cfg_samples，向 cmd_start 发一个 ui_clk 周期脉冲。采样范围默认 1～20,000,000 对；每对 A/B 共 4 字节。100 MSPS 下 200 ms 对应 20,000,000 对，时间精度仍取决于实际采样时钟。
2. 等待 record_done，并检查 record_valid、overflow。仅有效完整记录允许读出。
3. read_ready 为高时脉冲 cmd_read_next，等待 read_accepted。
4. 在 rd_clk 域等待 block_ready，读取 block_bytes/2 个 16 位字。rd_addr 是字地址，范围 0～4095；rd_en 被接受后，数据在两级读流水线末端伴随 rd_valid 有效。
5. 数据顺序为 A0、B0、A1、B1……，每个 12 位数存于 16 位字的低 12 位。block_offset 是本块在记录中的字节偏移，block_index 从 0 开始，block_bytes 是本块有效字节数。尾块不能按固定 8192 字节发送。
6. 等读流水线全部完成，再向 cmd_block_ack 发一个 rd_clk 周期脉冲。ack_accepted 表示已交还本块；同时读 RAM 或仍有待返回数据时 ACK 会被拒绝。
7. 下一块仍需新的 cmd_read_next。最后一块 ACK 返回 ui_clk 域后，stream_done 置位。显式 cmd_release 释放记录，再开始下一次采集。

读最后一个地址不会自动释放 RAM；ACK 长期保持高电平只响应一次。只有 block_ready 期间可以读本块，ACK 后不能继续读。read_ready 恢复还需等待跨时钟握手结束。

cmd_release 只在 record_done 且 read_idle 时接受；它也允许丢弃尚未请求的剩余块。若应用要求完整上传后才能释放，应由上层要求 stream_done。协议错误 read_error 为粘滞状态，需要协调全局复位恢复；没有实现超时取消或单侧时钟域复位恢复。

## 接入现有 Vivado 工程

1. 备份当前工程。在 Sources 添加上述三个新增模块，使用“Copy sources into project”，确保源文件复制到当前本机工程目录。
2. 保留已有七个支持模块及 FIFO，避免同名模块重复定义。独立新工程才添加本包全部 rtl，并生成对应 FIFO。
3. 在 Tcl Console 启用 XPM MEMORY：

```tcl
set libs [get_property XPM_LIBRARIES [current_project]]
if {[lsearch -exact $libs XPM_MEMORY] < 0} {lappend libs XPM_MEMORY}
set_property XPM_LIBRARIES $libs [current_project]
```

4. 板级顶层中用 adc_record_store 替代原 adc_capture_runtime 实例。保留原 ADC 和 MIG 写接口接线；把 MIG 的 app_rd_data、app_rd_data_valid、app_rd_data_end 接入新增读接口。MIG 的 app_addr/app_cmd/app_en 只能由 adc_record_store 驱动。
5. cfg_samples、START、RELEASE、READ_NEXT 属于 ui_clk 域；RAM 读与块 ACK 属于 rd_clk 域。后续 FMC 桥负责命令跨域，不能把 STM32 GPIO 直接接到这些同步命令端口。双方时钟必须持续运行。
6. 用本包 constraints/runtime_cdc.xdc 替换工程中的旧版 runtime_cdc.xdc；只保留一份。旧版 foreach/if 写法被 Vivado XDC 解析器报告为不支持，本版已经改为直接约束命令。这项修正也适用于原采集邮箱。不要用 blanket set_clock_groups 异步分组覆盖其中的总线 max_delay 约束。完整板级时钟、ADC 输入时序和硬件飞线后的引脚约束仍需另行落实。

本次不自动修改你的板级顶层或加密源文件。现在可先查看模块及仿真结果；接下来确定 FMC 寄存器与读窗口并编写桥接模块，再一次性接入板级顶层。

## 复现测试

在 PowerShell 中执行（测试目录用一个尚不存在的本机路径）：

```powershell
& ./scripts/run_tests.ps1 -WorkDir './local_inputs/record_v2_01'
```

默认 Vivado 路径为 ./local_inputs/bin，可用 -VivadoBin 更改。脚本生成独立 FIFO 仿真工程，不依赖 ./local_inputs/xc7a200t，也不会打开厂家工程。包内脚本按自身所在目录找 RTL，迁移后不依赖交付前的 staging 路径。

历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
