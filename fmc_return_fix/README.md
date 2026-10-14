# FMC 读返回修复联调包

本目录提供 FMC 数据返回时刻修正版源码、约束及测试平台。

## 直接联调

1. 将本包完整解压到一个短目录，例如 `./local_inputs/fmc_return_fix`。
2. 在 Vivado Hardware Manager 已连接 FPGA 的 Tcl Console 执行：

```tcl
source {./local_inputs/program_fixed_fmc.tcl}
```

脚本使用包内 `hardware/adc_ddr_fbg484_top.bit` 与 `hardware/fmc_id_debug.ltx`，两者必须成对使用。脚本会下载 FPGA，刷新设备并列出 ILA。

3. **下载 FPGA 后复位 STM32，让 FMC 完整重新初始化。** 不可直接沿用 FPGA 下载前的 SDRAM 模式/行状态。
4. 发送 `FREG`，首先核对：

| MCU 字节地址 | 寄存器 | 预期值 |
|---|---|---|
| 0xD0000000 | ID | 0xADFC |
| 0xD0000002 | VERSION | 0x0100 |
| 0xD0000004 | STATUS | 空闲正常时通常为 0x2061 |
| 0xD0000006 | EVENTS | 未发命令、未遗留事件时为 0x0000 |

必须先确认 ID、VERSION 和状态位正确，再发 `SET 1,1`、等待采集完成、`GET`。先测 1 ms，再测 200 ms。数据内容、块长、ACK 与 RELEASE 顺序仍按现有协议。

## 源码接入

功能修改仅涉及：

- `rtl/fmc_sdram_sync.v`：替换工程内同名文件。RAM 与寄存器数据已在第二拍寄存，取消额外一拍输出数据寄存；输出使能同步提前一拍。
- `fmc_interface.xdc`：替换同名约束文件。引脚保持不变，包含 J20 的 SDCLK；读返回约束改为保守的下一采样边沿预算。

ADC、DDR、双口 RAM 的读延迟、顶层接口、地址表均未修改。STM32 保持 HCLK=168 MHz、SDCLK=56 MHz、CAS=3、RPIPE=2、RBURST=0、BL=1、单次写模式，MRS 为 0x0230。

新增 FMC ILA 使用包内 `insert_fmc_ila.tcl`、`constrain_watch_inputs.tcl`、`finish_fmc_ila.tcl`。原脚本按旧输出寄存器命名找探针，需同步更换；请勿给同一次实现重复插入相同 ILA。`arm_fmc_read.tcl` 可触发 READ 命令。

修改源码后必须重新综合和实现。旧综合检查点不会包含修复。包内硬件文件来自独立完整工程构建，原 `./local_inputs/ad_collect.xpr` 未被覆盖。

## 验证范围

历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。

完整工程已生成 BIT/LTX；FMC 输出建立/保持最差裕量为 +0.346 ns / +1.847 ns。整体仍有复位跨时钟路径违例，严格代码规范门禁也未通过，具体证据已保留。FMC 建立裕量较小，板级验证不可省略。
