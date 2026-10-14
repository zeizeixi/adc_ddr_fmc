`timescale 1ns/1ps
`default_nettype none

// 独立 ADC 测试：复用 ads62p24_init 的 SPI 配置，ILA 观察未修正原始码。
// 依赖 capture_clocks、ads62p24_init、adc_simple_ila。
// capture_clocks 必须配置为输入 50 MHz，clk_out2 输出 100 MHz。
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
    wire clocks_locked;
    wire forwarded;
    wire adc_clk;
    wire init_async_rst;
    wire init_rst;
    wire cfg_done;

    capture_clocks u_clocks (
        .clk_in1  (sys_clk),
        .reset    (!sys_rst_n),
        .locked   (clocks_locked),
        .clk_out1 (),
        .clk_out2 (clk_100m)
    );

    // 初始化在稳定的内部时钟域运行，不能依赖 ADC 返回时钟启动。
    // 复位异步置位、同步释放；时钟失锁后会重新执行初始化。
    assign init_async_rst = !sys_rst_n || !clocks_locked;
    (* ASYNC_REG = "TRUE" *) reg [2:0] init_reset_pipe = 3'b111;
    always @(posedge clk_100m or posedge init_async_rst) begin
        if (init_async_rst)
            init_reset_pipe <= 3'b111;
        else
            init_reset_pipe <= {init_reset_pipe[1:0], 1'b0};
    end
    assign init_rst = init_reset_pipe[2];

    // 正常模式：0x14=0x80，0x16=0x10，输出直二进制原始码。
    // cfg_done 仅表示发送完成，不表示 ADC 回读确认成功。
    ads62p24_init #(
        .CLK_HZ            (100000000),
        .SPI_HZ            (1000000),
        .POWER_WAIT_CYCLES (500000),
        .RESET_HIGH_CYCLES (100),
        .RESET_WAIT_CYCLES (100),
        .SETTLE_CYCLES     (300000),
        .TEST_RAMP         (0)
    ) u_adc_init (
        .clk       (clk_100m),
        .rst       (init_rst),
        .adc_reset (ADC_RESET),
        .adc_cs_n  (ADC_CS),
        .adc_sck   (ADC_SCK),
        .adc_sdi   (ADC_SDI),
        .adc_ctrl  (ADC_CTRL),
        .done      (cfg_done)
    );

    ODDR #(
        .DDR_CLK_EDGE ("SAME_EDGE"),
        .INIT         (1'b0),
        .SRTYPE       ("SYNC")
    ) u_oddr (
        .Q(forwarded), .C(clk_100m), .CE(1'b1),
        .D1(1'b1), .D2(1'b0), .R(1'b0), .S(1'b0)
    );

    // 保留现有板级接线：逻辑 N 接物理 P(V9)，逻辑 P 接物理 N(V8)。
    OBUFDS u_obufds (
        .I(forwarded), .O(ADC_CLK_IN_N), .OB(ADC_CLK_IN_P)
    );

    BUFG u_adc_bufg (.I(ADC_CLK_OUT_P), .O(adc_clk));

    (* IOB = "TRUE" *) reg [11:0] adc_a_raw;
    (* IOB = "TRUE" *) reg [11:0] adc_b_raw;
    always @(posedge adc_clk) begin
        adc_a_raw <= ADC_DA;
        adc_b_raw <= ADC_DB;
    end

    // 保留原有两个 12 位探针；正常模式用 Unsigned Decimal 查看。
    // 上电初始化约 8 ms 后才解释采样值；不对 ADC 返回时钟加门控。
    adc_simple_ila u_ila (
        .clk    (adc_clk),
        .probe0 (adc_a_raw),
        .probe1 (adc_b_raw)
    );
endmodule
`default_nettype wire
