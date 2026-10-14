# fmc_sdram_port：SDRAM引脚协议

## 接口
```verilog
module fmc_sdram_port (
    input wire clk, rst, enabled, clear_error,
    input wire sdclk, cke, cs_n, ras_n, cas_n, we_n,
    input wire [12:0] addr,
    input wire [1:0] bank, dqm,
    inout wire [15:0] dq,
    output reg bus_read, bus_write,
    output reg [23:0] bus_addr,
    output reg [15:0] bus_wdata,
    output reg [1:0] bus_mask,
    input wire reply_valid,
    input wire [15:0] reply_data,
    output reg mode_valid, protocol_error
);
```

## 行为与复位
ui_clk100MHz；三拍时钟同步、五拍总线历史，使用SDCLK上升沿前的总线样本。四个bank各保存13位row；BL1、CAS3、读DQM延迟2拍。总线回复必须下一SDCLK之前就绪。停钟2.55us释放DQ并丢弃在途读。
复位：新模块同步高有效rst，与现有debug_rst相连；DQ另外受rst组合控制立即高阻。顶层保留原reset_sync和MIG复位连接。

## 时序与边界
外部SDCLK=1..5MHz，高低各至少100ns，MCU命令/地址/写数据上升沿前稳定至少30ns。FPGA输出延迟需结合RPIPE=2及实现报告验证。
禁止未完成读的情况下进入CKE低电平；不支持普通SDRAM全地址存储或任意burst模式。读不会产生隐式ACK。
地址、寄存器、错误和软件交互见../README.md。新模块下游时序统一100MHz，现有ADC/MIG CDC不变。

## 时序图
```json
{
  "signal": [
    {
      "name": "SDCLK",
      "wave": "p......"
    },
    {
      "name": "command",
      "wave": "=......",
      "data": [
        "READ"
      ]
    },
    {
      "name": "read_pipeline",
      "wave": ".===...",
      "data": [
        "1",
        "2",
        "3"
      ]
    },
    {
      "name": "DQ",
      "wave": "zzz=z..",
      "data": [
        "DATA"
      ]
    }
  ],
  "head": {
    "text": "CAS3：C0读命令，C3之后数据有效"
  }
}
```

## 验证
sim/tb_fmc_link.v检查CAS、连续BL1、地址映射、mask、非法命令、错误返回、复位和接口禁用。
reports保存实际工具输出；本说明不代表板级通过。完整顶层仅语法检查，ADC/MIG/IP沿用现有工程。
