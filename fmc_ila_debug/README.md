# FMC ID 读回在线 ILA 调试包

适用：Vivado 2023.2，已接入 `fmc_sdram_sync` / `fmc_record_link` 的 J20 SRCC / 56 MHz 版本，顶层 `adc_ddr_fbg484_top`，`FMC_CONTROL=1`。

## 使用步骤

1. 把压缩包内的 `.tcl` 文件放在同一个目录，例如 `./local_inputs/`。其中四个用于生成，第五个 `arm_fmc_read.tcl` 用于上板后可选的一键设置READ触发。无需加入 Design Sources，也不用创建新的 ILA IP。
2. 打开你当前的 FMC 工程，确保最新代码的 `synth_1` 已完成且没有过期。
3. 在 Vivado Tcl Console 输入：

```tcl
source {./local_inputs/start_fmc_ila.tcl}
```

4. 脚本新建 `impl_fmc_ila_日期_时间` 实现运行，并自动执行实现与 bit 生成。ADC/DDR/FMC 功能 RTL、原 XDC、`impl_1` 不被替换。新实现沿用原约束集和策略，保留原运行前后钩子；自定义的其他运行参数如有修改，需检查新运行设置。不要移动脚本文件夹，PRE/POST 钩子需要它。
5. 在 Design Runs 等待新运行 `write_bitstream Complete`。失败时查看该运行的 `runme.log`；脚本不会给缺失探针填零或连接到猜测的信号。
6. 输出位于新运行的 DIRECTORY（Tcl Console 会打印）。Hardware Manager → Program Device：Bitstream file 选择新运行的 `.bit`；Debug probes file 选择同目录 `fmc_id_debug.ltx`。这两个文件必须来自同一次实现。
7. 直接 JTAG 下载即可抓取，不必先生成 MCS。原 ADC ILA/VIO 继续保留，两组新增 core 为 `u_ila_fmc_bus` 和 `u_ila_fmc_watch`；界面可能显示 `hw_ila_N`，在 Cell/实例名中辨认。

新增 ILA 必须编译和下载；无法动态插入正在运行的旧 bit。这里提供的是工程调试脚本，未提供可下载的整机 bit。

## 第一组：稳定时钟监视

`u_ila_fmc_watch` 使用生产顶层的 `clk_100m`，深度 2048。Debug Hub 也使用这个稳定时钟，而不是依赖来自 STM32 的 SDCLK。独立验证载体没有 Clocking Wizard，只在验证中回退到 `ui_clk`。

先点 **Run Trigger Immediate** 无条件抓取：

| probe | 含义 |
|---|---|
| 0 | FMC 缓冲时钟作为异步数据信号观察 |
| 1 | FMC 逻辑复位，高有效 |
| 2 | SDCKE1，时钟使能，高有效 |
| 3 | SDNE1，片选，低有效 |
| 4 | SDNRAS，低有效 |
| 5 | SDNCAS，低有效 |
| 6 | SDNWE，低有效 |
| 7 | A[12:0] |
| 8 | BA[1:0] |
| 9 | NBL/DQM[1:0] |
| 后续可选 | locked、ui_rst、calib（实际存在才加入） |

本组异步采样只用于观察活动趋势，可能漏掉短脉冲、发生混叠或得到不一致的总线组合。它不能测出准确的 56 MHz 频率、不能用于协议解码、不能证明引脚电平或建立/保持满足要求。POST-OPT钩子只对本组异步输入的第一级采样寄存器D脚设置false path；FMC同步ILA、功能逻辑、原CDC和观察核内部后续流水线不切断。实际例外端点数量会打印到运行日志。完整工程的功能路径和原约束仍需检查。

本组时钟来自内部 Clocking Wizard，如果该时钟本身停了，Debug Hub 与此 ILA 也不能工作。ILA 采样时钟不能同时作为自身的被测波形，因此监视 FMC 使用另一组稳定时钟。

## 第二组：同步 FMC 读事务

`u_ila_fmc_bus` 使用 `fmc_clk`，即 J20 → BUFG，深度 4096。只有 J20 确实有持续时钟，本组才能正常抓取。每个探针低位对应实际寄存器低位，连接到寄存器 Q，避免综合网表组合信号被优化后名字消失。

| probe | 信号 | 宽度 |
|---|---|---|
| 0 | command_q = {RAS_n,CAS_n,WE_n} | 3 |
| 1 | cke_q | 1 |
| 2 | cs_q（片选低有效） | 1 |
| 3 | addr_q | 13 |
| 4 | bank_q | 2 |
| 5 | mask_q | 2 |
| 6 | mode_valid_o | 1 |
| 7 | protocol_error_o | 1 |
| 8 | row_open | 4 |
| 9/10/11/12 | row_first / row_second / row_third / row_fourth | 各13 |
| 13 | register_first（实际读响应进入流水线） | 16 |
| 14 | register_second | 16 |
| 15 | drive_data 的 fabric 镜像 | 16 |
| 16 | drive_tristate 的 fabric 镜像：1=释放该DQ位，0=驱动该DQ位 | 16 |
| 17 | data_q：DQ输入采样 | 16 |
| 18 | read_pipe | 2 |
| 19 | memory_pipe | 2 |
| 20 | fmc_rst | 1 |

探针真实网名和序号写入新运行的 `fmc_ila_probe_map.tsv`。综合网表可能给部分网线起别名，可按这个表及 probe 序号对应。

Vivado禁止ILA直接探测放在IOB的输出寄存器Q。脚本为每个输出数据/T位建立fabric镜像寄存器，使用实际原寄存器的D、C、CE、复位/置位网络及初始化/极性属性，并加DONT_TOUCH，原IOB寄存器仍驱动DQ、不移动。probe15/16表示这一镜像的数值，并非独立测量物理IOB的Q；probe17是已有DQ输入采样，可用于检查输出期间的焊盘回读。

### 抓 ID 读取

设置三个 AND 触发条件：

```text
probe0 command_q == 3'b101
probe1 cke_q     == 1
probe2 cs_q      == 0
```

深度 4096、触发位置 1024 左右，Capture Condition 保持 Always。不要额外要求 MODE_VALID=1，也不要只触发 bus_read：模式配置失败时合法 bus_read 不会产生，反而无法抓取问题。

新下载后的默认触发设置下，也可以在Hardware Manager的Tcl Console执行：

```tcl
source {./local_inputs/arm_fmc_read.tcl}
```

它只在对应硬件core和三个probe能唯一匹配时设置触发；未在真实板卡上执行验证。若你已添加过其他触发条件，先在GUI清除它们，避免残留条件影响捕获。若信号名字不匹配，按probe序号在GUI设置即可。

先在 FPGA 中下载新 bit，再 Arm ILA，最后让 STM32 重新执行 FMC 初始化并读取 ID。重新下载 FPGA 会清掉 mode_valid，因此只重复读 ID 而不重发 MRS 不够。STM32 若 ID 不对就停止初始化，需要同事从调试器重新运行初始化，或临时每100 ms重新读 ID；模式无效时先重新发完整初始化序列。不要在需要抓取的 READ 发生之后才 Arm。

0xD0000000 的 ID 读取应满足：

- 触发样本 command_q=101、cke_q=1、cs_q=0。
- bank_q=0，row_first=0，addr_q[7:0]=0，即协议字节地址0。A10可能用于自动预充电，不能简单要求整个addr_q为0。
- mode_valid_o=1，命令到达时 row_open[0]=1；自动预充电之后 row_open 可能清零。
- 随后 register_first、register_second、drive_data镜像依次出现 `16'hADFC`。
- 当 drive_data镜像=ADFC 且 drive_tristate镜像=0000 时，原输出寄存器应要求驱动全部16位；FFFF表示释放全部DQ，00FF/FF00表示只驱动一个字节。再看下一拍的data_q焊盘输入采样是否有ADFC。
- ILA仅证明内部输出逻辑，不能证明封装外 STM32 已收到该电压；还要核对 DQ 引脚映射、物理连接和相对时序。

统一增加了1级ILA输入流水线，这只使整组观察延后，不改变原FMC响应延迟。不要拿ILA屏幕触发位置当物理引脚相位的精密测量。

### 抓模式寄存器写入

把 probe0 触发值改为 `000`（MRS），probe1=1、probe2=0。检查 bank_q=0、addr_q=0x0230，然后 mode_valid_o 置1。MRS 未到达或发生在 fmc_rst=1 时，后续 READ 不会正常返回ID。

## 波形判断

| 观察结果 | 优先排查 |
|---|---|
| watch有内部时钟，FMC ILA不能抓 | J20时钟是否持续、幅度/波形、约束与飞线；先示波器实测 |
| fmc_rst一直1 | ui_rst、Clocking Wizard locked、系统复位；不是START协议问题 |
| FMC正常抓到，但没有101/片选 | SDNE1/RAS/CAS/WE引脚映射、MCU Bank2访问、固件是否真的再次读ID |
| READ收到，mode_valid=0 | MRS=0230及BA=0、FPGA/MCU初始化先后顺序 |
| mode_valid=1但当前bank行没打开 | ACTIVE行地址、BA和A引脚映射 |
| register_first=DEAD | 此读命令未满足合法地址/模式/行条件 |
| register_first与drive_data=ADFC，T=0000，MCU仍错误 | DQ位序/连接、NBL掩码、CAS3/RPIPE2和时序 |
| T=FFFF或只有半字驱动 | DQM/NBL、CKE以及是否在正确响应周期观察 |

## 验证范围

验证日志另附。独立接口网表不是整机原工程，不能下载到板上。脚本在用户整机上实际执行时仍需成功实现、生成bit/ltx并检查时序。新增debug核会增加资源和布线负载，原56MHz无ILA的时序余量不能直接作为加ILA后的余量。

AMD 官方接口：create_debug_core / create_debug_port / connect_debug_port；write_debug_probes生成与当前设计匹配的ltx。

- https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/create_debug_core
- https://docs.amd.com/r/2021.2-English/ug835-vivado-tcl-commands/write_debug_probes
