# fmc_sdram_sync 读返回修复说明

本模块保持原有端口、地址、命令和模式设置。目标为 STM32F429、HCLK=168 MHz、SDCLK=56 MHz、CAS=3、RPIPE=2、RBURST=0。SDCLK 使用已飞线的 J20 SRCC，经原有 BUFG；无需改动顶层或更换双口 RAM。

## 修改依据

2026-10-09 导出的四笔硬件读取：列地址为0、1、2、3；FPGA生成ADFC、0100、2061、0000，但MCU读取FFFF、ADFC、0100、2061。mode_valid=1，各次READ的行有效，protocol_error=0。地址映射正确，需要修正数据有效窗口。

## 时钟与复位

clk上升沿锁存输入、译码、运行RAM请求及响应流水线。rst高有效；协议和响应状态同步清零，16个IOB输出使能寄存器通过异步预置立即将DQ切为高阻，即使SDCLK停止也可释放总线。enabled为静态FMC所有权参数。

输入采样寄存器继续使用fabric FF且不增加复位；复位和mode_valid对请求进行屏蔽。四个bank各有13位行地址与row_open状态。MRS仅接受bank0、0230。

## 返回时序

| 时刻 | 行为 |
|---|---|
| C0 | 锁存READ命令、bank和列地址 |
| C1 | 生成有效请求，启动原有两周期RAM，锁存register_first |
| C2 | register_second或XPM RAM输出有效，IOB三态寄存器使能当前返回 |
| C3 | MCU采到在此边沿之前已有效的数据；单笔返回的输出使能在此后的FPGA边沿关闭 |

原来的drive_data输出寄存器增加了C3这一拍，已移除。现在drive_data是选择两个已寄存数据源的组合网络，使用KEEP保留ILA可见性；没有组合反馈路径。驱动使能由read_pipe[0]和mask_first对齐。原RAM的READ_LATENCY_B=2及rd_valid合同不变。

连续READ时每拍更新自己的数据源选择，支持4096个半字的连续读取。空闲期间DQ为高阻。reads_idle仍表示READ流水线为空，用于ACK限制，读完某个地址不会自动ACK。

## 地址与接口

字节地址为 `{bank_q, selected_row, addr_q[7:0], 1'b0}`。CPU的+0/+2/+4/+6对应列0/1/2/3；A10仅用于自动预充电。

输入端口：clk、rst、enabled、clear_error、cke、cs_n、ras_n、cas_n、we_n、addr[12:0]、bank[1:0]、dqm[1:0]、register_data[15:0]、memory_selected、memory_data[15:0]、memory_valid。双向端口：dq[15:0]。

输出端口：bus_read、bus_write、bus_addr[23:0]、bus_wdata[15:0]、bus_mask[1:0]、reads_idle、mode_valid、protocol_error。bus_read/bus_write及总线载荷仍在C1被原有寄存器/FIFO/读块逻辑采样。

## 错误与交接

非法模式、未打开行或无效窗口返回DEAD并保留错误标志；RAM响应缺失在对应流水级检查。clear_error只清错误标志，不能强制模式有效。CKE低时取消流水线并关闭输出；在途读被中断时置错。合法读写交接必须先完成当前读，再由MCU驱动写数据。

16个IOB三态寄存器保留IOB和DONT_TOUCH属性。它们的Q不能直接反馈到fabric或ILA，因此ILA继续使用同C/D/CE/复位的fabric镜像；新drive_data直接作为fabric探针，不再寻找不存在的drive_data_reg。

## 逻辑时序图

以下为WaveJSON合同，不代表按比例的板级延迟或示波器实测。正式SVG渲染器在本机未找到，因此没有声称SVG生成成功。

```json
{"signal":[{"name":"SDCLK C0 C1 C2 C3 C4","wave":"p...."},{"name":"READ pins","wave":"10..."},{"name":"RAM request","wave":"010.."},{"name":"registered RAM valid","wave":"0.10."},{"name":"DQ current word","wave":"z.=z.","data":["CURRENT"]},{"name":"MCU capture edge","wave":"0..10"}]}
```

## 验证

新版测试要求C3之前2 ns数据已有效，不再以假定的C3+2HCLK采样来掩盖迟到的数据。旧版在相同边界下失败，新版覆盖ID、VERSION、STATUS、SCRATCH、字节写、SET/START顺序、全块、末块、越界、ACK/RELEASE、读写交接及异步复位释放。独立接口使用真实XPM RAM/FIFO；其MIG和采集响应由模型提供，不构成板上DDR或网口测试。

历史验证与现场诊断资料未收录到公开仓库；请自行重新执行测试、综合、实现和板级验收。
