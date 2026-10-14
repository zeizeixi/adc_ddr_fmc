# adc_ddr_fmc

ADS62P24 双通道采集 → FPGA DDR3 存储 → STM32 FMC 分块回读。

本仓库归档此前由 Codex 生成和交付的未加密源码、约束、脚本、测试平台与接入说明。文件按原版本目录保留，避免同名模块相互覆盖。整理日期：2026-10-14。

## 从哪里开始

| 目录 | 用途 |
| --- | --- |
| adc_trigger_capture/ | 最新的触发采集联调候选版，包含前后触发、ARM/FORCE/ABORT 和协议 v2 |
| runtime_capture_v2/ | 运行时点数配置、DDR 保存与分块读回 |
| fmc_return_fix/ | FMC 数据返回时刻修正版 |
| fmc_srcc/ | J20 SRCC、同步 FMC 接口及 STM32 对接说明 |
| adc_ila_debug/、adc_simple_test/、adc_spi_test/ | ADC 观察和初始化测试 |
| adc_capture_original/ | 最初的 ADC/FIFO/DDR 写入交付版 |
| ip_config/ | 生成工程快照中的 MIG 配置及配套 prj |
| 其余目录 | 历史整合版、引脚检查、时序修正和联调脚本 |

触发版先读 [adc_trigger_capture/README.md](adc_trigger_capture/README.md)、[对接协议](adc_trigger_capture/docs/STM32对接协议.md) 和 [验证说明](adc_trigger_capture/docs/验证说明.md)。

## 工程使用边界

- 这是按版本整理的源码归档；不能把整个仓库一次性添加为 Vivado Design Sources。同名模块只选择一个版本。
- 硬件目标为 XC7A200T-FBG484、ADS62P24 双通道 12 bit ADC。具体时钟、引脚和 FMC 设置以所选版本的说明为准。
- MIG、Clocking Wizard、FIFO、VIO、ILA 等 IP 需要按原说明配置和生成；仓库没有收录完整的 IP 生成产物。
- 最新触发采集目录是联调候选源码，未附新板级 bit/ltx，也不能据此宣称最新工程已通过布线时序或上板验收。
- 本次没有收录用户电脑上的加密工程，也没有收录厂家完整 RTL、仿真缓存、实现缓存或硬件采集数据。
- 历史 README 和脚本保留原文。其中引用的本机绝对路径、project/ 和 hardware/ 文件可能不在本归档中；执行前应按实际目录调整。下载 FPGA 的脚本需要自行生成并核对配套 bit/ltx。
- 没有新加许可证；不据本归档推定第三方 IP 的再分发许可。

## 文件完整性

SOURCE_INVENTORY.json 记录原交付文件的路径、大小和 SHA-256。整理时逐文件核对，源码内容保持原样，包括原编码。
各版本已有的测试报告记录历史验证范围；本次归档核验不替代新的综合、实现和板级测试。
