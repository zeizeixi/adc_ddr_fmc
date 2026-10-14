`timescale 1ns/1ps
`default_nettype none

// ADS62P24 最小并行配置测试：时钟输出、输入寄存器、ILA。
// 无 SPI 序列、DDR、FIFO、VIO 或定长采集状态机。
// RESET=高，SEN=AVDD，SCLK=低，CTRL=000：CMOS、二进制补码、内部参考、0 dB。
// 控制输出所在 Bank 须为 3.3 V，且实物连接与 XDC 一致。
module adc_simple_top (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        ADC_CLK_OUT_P,
    input  wire [13:2] ADC_DA,
    input  wire [13:2] ADC_DB,
    output wire        ADC_CLK_IN_P,
    output wire        ADC_CLK_IN_N,
    output wire        ADC_RESET,
    output wire        ADC_CS,
    output wire        ADC_SCK,
    output wire        ADC_SDI,
    output wire [2:0]  ADC_CTRL
);
    wire clk_100m;
    wire forwarded;
    wire adc_clk;

    // 复用已确认配置的 capture_clocks：50 MHz 输入，out1=200 MHz，out2=100 MHz。
    // 本测试仅使用 out2。sys_rst_n 只复位时钟 IP，不切换 ADC 配置模式。
    capture_clocks u_clocks (
        .clk_in1  (sys_clk),
        .reset    (!sys_rst_n),
        .locked   (),
        .clk_out1 (),
        .clk_out2 (clk_100m)
    );

    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_oddr (
        .Q(forwarded), .C(clk_100m), .CE(1'b1),
        .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0)
    );

    // 按现有实物布线：板上 N 接 FPGA 物理 P(V9)，板上 P 接物理 N(V8)。
    OBUFDS u_obufds (
        .I(forwarded), .O(ADC_CLK_IN_N), .OB(ADC_CLK_IN_P)
    );

    // 并行配置电平必须持续保持；不是 SPI 事务。
    assign ADC_RESET = 1'b1;
    assign ADC_CS    = 1'b1;   // SEN=AVDD：CMOS 输出 + 二进制补码
    assign ADC_SCK   = 1'b0;   // 内部参考，0 dB 增益
    assign ADC_SDI   = 1'b0;   // 本模式不进行串行写入
    assign ADC_CTRL  = 3'b000; // 两路正常工作，不复用总线

    BUFG u_adc_bufg (.I(ADC_CLK_OUT_P), .O(adc_clk));

    // 不做取反、零点校准或电压换算。ILA 用 Signed Decimal 查看补码。
    (* IOB = "TRUE" *) reg [11:0] adc_a_raw;
    (* IOB = "TRUE" *) reg [11:0] adc_b_raw;
    always @(posedge adc_clk) begin
        adc_a_raw <= ADC_DA;
        adc_b_raw <= ADC_DB;
    end

    adc_simple_ila u_ila (
        .clk    (adc_clk),
        .probe0 (adc_a_raw),
        .probe1 (adc_b_raw)
    );
endmodule
`default_nettype wire
