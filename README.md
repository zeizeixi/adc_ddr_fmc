# adc_ddr_fmc

ADS62P24 双通道 ADC 采集 → XC7A200T FPGA DDR3 存储 → STM32 FMC 分块回读。

本仓库包含此前由 Codex 生成的未加密 RTL 源码、约束、IP 配置、辅助脚本、测试平台和接入说明。文件按版本保留。整理日期：2026-10-14。

| 目录 | 内容 |
| --- | --- |
| adc_trigger_capture/ | 最新触发采集候选版，前后触发、ARM/FORCE/ABORT、协议 v2 |
| runtime_capture_v2/ | 运行时点数配置、DDR 保存和分块回读 |
| fmc_return_fix/ | FMC 数据返回时刻修正版 |
| fmc_srcc/ | SRCC 与同步 FMC 接口 |
| adc_capture_original/ | 最初 ADC/FIFO/DDR 写入版 |
| adc_simple_test/、adc_spi_test/、adc_ila_debug/ | ADC 测试及观察脚本 |
| ip_config/ | MIG 配置与配套 prj |
| 其他目录 | 历史整合、引脚、时序修正及测试源码 |

最新候选版先读 [接入说明](adc_trigger_capture/README.md) 和 [STM32 对接协议](adc_trigger_capture/docs/STM32对接协议.md)。

使用时选择一套版本。同名 module 不能全部添加到 Vivado Design Sources；sim/、tb/ 和 reference/ 的用途以各目录说明为准。

本仓库是源码归档，不是可直接打开且已完成板级验证的完整 Vivado 工程。MIG、Clocking Wizard、FIFO、VIO、ILA 等 IP 仍需配置并生成。未收录 bit/ltx、实现缓存、加密工程、硬件采集数据或现场诊断资料。最新触发版仍需重新综合、实现和上板验收。

RTL 源码保持原内容及编码。辅助脚本和说明中的电脑绝对路径改为 ./local_inputs/ 下的输入路径占位，使用前须配置实际的工程、工具和文件位置。历史辅助脚本可能依赖未公开的原始输入，不能直接作为可复现构建入口。脚本引用的 project/ 或 hardware/ 文件未收录，下载硬件前须自行生成配套 bit/ltx。

SOURCE_INVENTORY.json 记录本次公开上传文件的路径、大小、SHA-256 和 Git blob SHA，用于核对完整性。

未新加许可证，也不推定第三方 IP 的再分发许可。