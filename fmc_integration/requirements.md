# FMC 接入约定

输入基线为用户 2026-09-17 粘贴的 adc_ddr_fbg484_top，保留 ADC、MIG、record_store 和 VIO IP。
新增 fmc_sdram_port（引脚协议）及 fmc_record_regs（寄存器/读块适配），不修改 ADC 数据或原 DDR 模块。
顶层 FMC_CONTROL=1 使用 MCU 命令；设为 0 使用原 VIO 控制，两者不会同时驱动。

所有新寄存器在 MIG ui_clk=100 MHz 工作，同步高有效 debug_rst。SDCLK 为被过采样的数据输入，不创建 FPGA 时钟。
首版限定外部 SDCLK=1..5 MHz，高/低电平分别>=100 ns；命令/地址/写DQ 在上升沿前需稳定至少30 ns。边沿检测与总线历史延迟配合选择上升沿前的样本，不依赖长保持时间。
STM32 SDRAM Bank2，16位、13行、8列、4内部bank、CAS3、模式寄存器0x230（BL1、顺序、单写）、RBURST关闭、RPIPE2。
外设窗口0xD0000000；数据窗口偏移0x2000..0x3FFF。完整offset={BA[1:0],row[12:0],column[7:0],0}。
无 SDRAM 存储阵列：ACT/PRECHARGE/MRS/REFRESH 只管理协议状态；存储由已有DDR模块负责。
不支持自刷新/休眠下的在途事务；CKE只允许在总线空闲时改变。支持连续BL1读写、DQM读延迟2拍及写字节屏蔽。

读请求C0经本地总线返回，必须在C1之前完成；数据C3后的ui_clk边沿推出，MCU使用RPIPE2采样。
命令访问用16位volatile，1..200ms，START=1 READ_NEXT=2 ACK=3 RELEASE=4 CLEAR_EVENTS=5。
数据读只读，不产生隐式ACK；读取0..block_bytes/2-1后显式ACK。等待1秒后仍须检查done/valid/overflow。
所有板级时序/三态周转最终需要实现报告和示波器确认，本次不声称硬件通过。

验证：独立行为模型先定义地址和命令规则；仿真覆盖MRS、所有读写路径、byte mask、连续读、跨行、bank隔离、半块边界、拒绝命令、复位释放DQ、VIO仲裁；编译检查真实顶层接口；新模块独立综合。严格技能门禁状态如实另报，不以仿真替代格式门禁。
