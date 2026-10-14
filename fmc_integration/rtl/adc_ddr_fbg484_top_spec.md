# adc_ddr_fbg484_top：顶层静态所有权选择

## 接口
```verilog
module adc_ddr_fbg484_top #(
    // 1: FMC owns commands/read port; 0: original VIO owns them.
    parameter FMC_CONTROL = 1
)(
    input wire MCU_FMC_SDCLK, MCU_FMC_SDCKE1, MCU_FMC_SDNE1,
    input wire MCU_FMC_SDNRAS, MCU_FMC_SDNCAS, MCU_FMC_SDNWE,
    input wire [12:0] MCU_FMC_A,
    input wire [1:0] MCU_FMC_BA, MCU_FMC_NBL,
    inout wire [15:0] MCU_FMC_D,

 // 板载系统时钟；沿用参考工程的 50 MHz 输入配置                                              
 input wire sys_clk, sys_rst_n,                                               
                                                                            
 // ADC 返回的数据时钟；以此时钟接收 A、B 两路数据                                             
 input wire ADC_CLK_OUT_P,                                                  
                                                                          
 // 两路 ADC 有效数据总线，保留原理图的 [13:2] 编号，每路 12 位                                  
 input wire [13:2] ADC_DA, ADC_DB,                                          
                                                                          
 // FPGA 送给 ADC 的差分采样时钟；P/N 物理对应及电气标准需单独核对                                  
 output wire ADC_CLK_IN_P, ADC_CLK_IN_N,                                    
                                                                          
    // ADC 配置引脚；电平/初始化行为保留在现有采集模块内                                  
    output wire ADC_RESET, ADC_CS, ADC_SCK, ADC_SDI,                        

    // ADC 控制引脚；数组下标 0、1、2 对应原理图 CTRL1、CTRL2、CTRL3
    output wire [2:0] ADC_CTRL, 

    // 两颗 x16 DDR 组成的 32 位双向数据总线
    inout wire [31:0] ddr3_dq, 

    // 四组差分数据选通，每组对应一个数据字节
    inout wire [3:0] ddr3_dqs_n, ddr3_dqs_p, 

    // DDR 行列复用地址，具体含义由 MIG 命令时序决定
    output wire [13:0] ddr3_addr, 

    // DDR 内部存储体地址
    output wire [2:0] ddr3_ba, 

    // DDR 命令及复位信号，后缀 _n 表示低有效
    output wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n, 

    // DDR 差分时钟、时钟使能、片选和片内终端控制
    output wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, 

    // 四个字节的数据掩码
    output wire [3:0] ddr3_dm
);
```

## 行为与复位
FMC_CONTROL=1选择FMC，=0选择VIO；选择覆盖cfg/start/release/read_next/rd_en/rd_addr/ack。ADC及MIG实例逐字去空白比较未改变。
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
