# tb_fmc_return_window 契约

- 文件：`tb_fmc_return_window.v`，无外部端口，验证用顶层；不加入设计综合源。
- 内部 UI 时钟与 FMC 时钟独立，FMC 周期 17.857 ns；参数控制时钟相位和占空比。
- 初始化使用 BL1、CAS3、单次写的 SDRAM 模式 0x0230。所有 CPU 偏移使用字节单位，16 位总线的列地址以半字为单位。
- 在 READ 的 C3 上升沿之前 2 ns 检查有效 DQ，覆盖输入建立时间。该模拟接收边界不等同于示波器实测板级采样相位。
- 检查寄存器读写、字节掩码、事件/START/ACK/RELEASE、4096 半字整块读取、末块、越界访问、连续读、最短受支持读写交接与复位释放 DQ。
- DDR 返回由测试系统模型提供，读出缓存使用真实 XPM 双口 RAM、READ_LATENCY_B=2；不模拟模拟 ADC 噪声、DDR 电气接口或 STM32 硅片。
- 自检失败通过 `$fatal` 结束；成功打印检查计数。三个时钟包装顶层分别为短低相、短高相及对称时钟。

时序定义：

```json
{"signal":[{"name":"SDCLK","wave":"p...."},{"name":"READ","wave":"10..."},{"name":"DQ valid","wave":"0.10."},{"name":"check","wave":"0..10"}],"head":{"text":"C0 READ → C2 数据返回 → C3 前 2 ns 检查"}}
```

此时序以文字与 WaveJSON 交付；本环境未生成渲染 SVG，不作为已渲染图形验收。
