# fmc_record_regs：采集寄存器及块缓存窗口

## 接口
```verilog
module fmc_record_regs (
    input wire clk, rst,
    input wire bus_read, bus_write,
    input wire [23:0] bus_addr,
    input wire [15:0] bus_wdata,
    input wire [1:0] bus_mask,
    output reg reply_valid,
    output reg [15:0] reply_data,
    input wire mode_valid, protocol_error,
    output reg clear_error,
    output wire [31:0] cfg_samples,
    output reg cmd_start, cmd_release, cmd_read_next, cmd_ack,
    output reg rd_en,
    output reg [11:0] rd_addr,
    input wire [15:0] rd_data,
    input wire rd_valid,
    input wire ready, busy, done, valid, overflow, cfg_done, calib,
    input wire read_ready, read_idle, stream_done, read_error,
    input wire block_ready, block_last,
    input wire accepted, rejected, read_accepted, ack_accepted, ack_rejected, rd_rejected,
    input wire [31:0] record_samples, record_bytes, blocks, block_index, block_offset,
    input wire [13:0] block_bytes
);
```

## 行为与复位
与原记录模块同ui_clk，无新增内部CDC。命令单周期脉冲；合法duration1..200。窗口读启动两拍缓存读，在7计数超时时返回DEAD。块所有权始终由显式ACK释放。
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
