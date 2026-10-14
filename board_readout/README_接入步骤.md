# 板级顶层接入 DDR 读出

这是 runtime_capture_v2 的顶层补丁，不是另一套完整采集工程。以此前交付、你确认没有修改的 adc_ddr_fbg484_top.v 为基线；不会解密或覆盖公司加密文件。

## 在现有工程中操作

1. 备份 ./local_inputs/ad_collect_484 工程。保持 xc7a200tfbg484-2，顶层名称仍为 adc_ddr_fbg484_top。
2. 用本包 rtl/adc_ddr_fbg484_top.v 的内容替换工程里原同名文件；只保留一个同名模块。公司环境中可在允许的编辑器内复制粘贴源代码。
3. 新增 rtl/readout_debug.v，选择 Copy sources into project。前面已添加的 adc_record_store.v、ddr_block_reader.v、ram256x16_8k.v 保留；原 adc_capture_runtime.v 及它的支持模块也保留。
4. Vivado 打开你的工程，在 Tcl Console 执行下列命令。路径若移动，改为本机实际解压路径。

```tcl
source ./local_inputs/create_readout_vio.tcl
```

脚本只新增 readout_vio，并启用 XPM_MEMORY；在当前工程目录中生成 IP，不依赖 ./local_inputs/xc7a200t 或本次验证目录。若已存在 readout_vio，脚本会停止防止覆盖，不需要重复执行。原 capture_vio 不用修改。

5. 确认已用 runtime_capture_v2/constraints/runtime_cdc.xdc 替换旧版同名约束；原文件的 foreach/if 写法有问题。该约束只保留一份，USED_IN_SYNTHESIS 设为 false，PROCESSING_ORDER 设为 LATE。原 MIG 自带约束保持。
6. Update Compile Order 后，先 Open Elaborated Design，再 Run Synthesis。

应看到如下层级：

```text
adc_ddr_fbg484_top
  u_clocks       : capture_clocks
  u_forward      : adc_clock_forward_7series
  u_store        : adc_record_store
    u_capture    : adc_capture_runtime
    u_reader     : ddr_block_reader
  u_debug_reset  : reset_sync
  u_read_debug   : readout_debug
  u_vio          : capture_vio
  u_read_vio     : readout_vio
  u_mig          : mig_7series_0
```

这一步不改外部引脚、不接 FMC。ADC 飞线后的电气、时钟和引脚约束尚待硬件方案确定，不能据此认定已经适合下载上板。原 LED 和 ADC 时钟的引脚冲突也不能忽略。

## 新 VIO 的操作

原 capture_vio 继续负责采样点数、START、RELEASE。新增 readout_vio 的输入输出均在 ui_clk 域；读出 RAM 的消费者时钟本次也接 ui_clk。后续 FMC 桥再替换此调试消费者。

| 输出探针 | 宽度 | 用途 |
| --- | --- | --- |
| probe_out0 | 1 | READ_NEXT：请求下一块 |
| probe_out1 | 12 | RAM 字地址，0～4095，每地址 16 位 |
| probe_out2 | 1 | READ_WORD：读取所设地址一次 |
| probe_out3 | 1 | ACK：交还当前块 |
| probe_out4 | 1 | CLEAR_DEBUG：清除调试历史，不清除读协议错误 |

上述命令均以 0→1 触发，保持 1 不重复触发；再次使用前先置回 0。先单独设置地址，再切换 READ_WORD，避免同一次 VIO 更新的地址与命令混用。每次读后，观察 word_count 增加，再查看 last_data。

| 输入探针 | 宽度 | 用途 |
| --- | --- | --- |
| probe_in0 | 16 | status，位定义见下表 |
| probe_in1 | 32 | block_index，从 0 开始 |
| probe_in2 | 32 | block_offset，记录内字节偏移 |
| probe_in3 | 14 | block_bytes，当前块有效字节数 |
| probe_in4 | 16 | last_data，最近一次有效读出的 A 或 B 字 |
| probe_in5 | 32 | word_count，成功返回的读字次数 |
| probe_in6 | 32 | ack_count，成功确认的块次数 |
| probe_in7 | 32 | request_count，成功接受的块请求次数 |

| status 位 | 含义 |
| --- | --- |
| 0 | read_ready，可发 READ_NEXT |
| 1 | read_idle，读引擎及握手均空闲 |
| 2 | block_ready，可读当前 RAM 块 |
| 3 | block_last，当前块是尾块；仅 block_ready 时解释当前块元数据 |
| 4 | stream_done，最后一块 ACK 已返回 UI 域 |
| 5 | read_error，协议错误，需全局复位恢复 |
| 6 | 曾有有效读字返回 |
| 7 | 曾接受 READ_NEXT |
| 8 | 曾接受 ACK |
| 9 | 曾拒绝 START/RELEASE/READ_NEXT 命令 |
| 10 | 曾拒绝 ACK |
| 11 | 曾拒绝 RAM 读字 |
| 12 | 曾接受 START |
| 15:13 | 保留为 0 |

位 6～12 是历史标记，只由复位或 CLEAR_DEBUG 清除；计数器也由此清除，32 位溢出回绕。CLEAR_DEBUG 与事件同周期时保留该事件。last_data 会保持旧值，新的 word_count 增量才证明本次读取有效。

采集完成且 record_valid 后：READ_NEXT → 等 block_ready → 读地址 0..block_bytes/2-1 → 等最后一次 word_count 更新 → ACK → 等 read_ready 再请求下一块。数据顺序 A0、B0、A1、B1……，每字低 12 位有效。读完末地址不会自动释放块。最后一块 ACK 后等 stream_done，再通过原 VIO RELEASE。不要同时发送多个控制命令。

VIO 用于少量抽查，不用于把整段 80 MB 数据上传电脑；批量传输仍由后续 FMC/STM32 软件实现。

## 验证范围

- 新顶层和 readout_debug 通过 xvlog 语法编译。
- readout_debug 通过 XSim 自检：读命令沿、保持高电平、返回数据保持、全部状态位、计数器、清除与事件同拍、复位。
- Vivado 2023.2 实际创建 readout_vio，生成输出文件并逐项检查 8 个输入和 5 个输出宽度，结果通过。
历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
- 本轮未完成包含真实 MIG/时钟等 IP 的整个新顶层展开、综合或布局布线。用户当前工程的顶层与部分 IP 源被公司软件加密，不能用本轮局部验证替代你工程中的 Open Elaborated Design / Run Synthesis。

logs 中保留实际测试日志。未启用此前讨论的 readable-verilog-generator 强制门禁，按用户授权使用本机 Vivado 流程。
