`timescale 1ns/1ps
`default_nettype none
// start and sample_limit are delivered together by a mailbox in adc_clk.
// result = {overflow, accepted_FIFO_blocks, sampled_pairs}, held until next start.
// On overflow, stop acquisition but drain any previously queued output first.
module ads62p24_pack_runtime(
    input wire adc_clk, rst, start,
    input wire [31:0] sample_limit,
    input wire [11:0] adc_a, adc_b,
    output reg [255:0] out_data,
    output reg out_valid, input wire out_ready,
    output reg idle, overflow,
    output reg result_send, input wire result_busy,
    output wire [64:0] result_data
);
    (* IOB="TRUE" *) reg [11:0] adc_a_q, adc_b_q;
    always @(posedge adc_clk) begin adc_a_q<=adc_a; adc_b_q<=adc_b; end
    // 在输入寄存器之后观察数据，保留原来的 IOB 采样寄存器。
    // 这里取反一次，ILA 与 DDR 使用完全相同的修正码。
    wire [11:0] adc_a_corrected;
    wire [11:0] adc_b_corrected;
    assign adc_a_corrected = ~adc_a_q;
    assign adc_b_corrected = ~adc_b_q;

    // ILA 直接使用 ADC 返回时钟；不依赖 DDR 开始采集命令。
    // 同一个 ILA 采样点中，原始码与修正码对应同一份输入寄存器数据。
    adc_raw_ila u_adc_raw_ila (
        .clk    (adc_clk),
        .probe0 (adc_a_q),          // A 原始码，12 位无符号
        .probe1 (adc_b_q),          // B 原始码，12 位无符号
        .probe2 (adc_a_corrected),  // A 修正码 = 4095 - A 原始码
        .probe3 (adc_b_corrected),  // B 修正码 = 4095 - B 原始码
        .probe4 (rst),              // ADC 域逻辑复位，高有效
        .probe5 (start)             // ADC 域采集启动脉冲，仅用于观察或触发
    );

    localparam IDLE=0, CAPTURE=1, FLUSH=2, REPORT=3, WAIT_BUSY=4, WAIT_ACK=5;
    reg [2:0] state, pack_index;
    reg [31:0] limit_q, sample_count, blocks;
    reg [255:0] pack_data;
    reg [255:0] next_pack;
    wire slot_available = !out_valid || out_ready;
    assign result_data = {overflow,blocks,sample_count};
    always @* begin
        next_pack=pack_data;
        // 两路反相修正后的直二进制码写入 DDR；高四位保持补零。
        next_pack[pack_index*32 +: 32]={4'b0,adc_b_corrected,4'b0,adc_a_corrected};
    end
    always @(posedge adc_clk) begin
        if (rst) begin
            state<=IDLE; idle<=1; overflow<=0; result_send<=0;
            out_valid<=0; out_data<=0; pack_data<=0; pack_index<=0;
            limit_q<=0; sample_count<=0; blocks<=0;
        end else begin
            result_send<=0;
            if (out_valid && out_ready) begin out_valid<=0; blocks<=blocks+1; end
            case(state)
                IDLE: if (start) begin
                    limit_q<=sample_limit; sample_count<=0; blocks<=0;
                    overflow<=0; pack_index<=0; pack_data<=0;
                    idle<=0; state<=CAPTURE;
                end
                CAPTURE: begin
                    sample_count<=sample_count+1;
                    if (pack_index==7 || sample_count==limit_q-1) begin
                        if (slot_available) begin
                            out_data<=next_pack; out_valid<=1;
                            pack_index<=0; pack_data<=0;
                            if (sample_count==limit_q-1) state<=FLUSH;
                        end else begin overflow<=1; state<=FLUSH; end
                    end else begin pack_data<=next_pack; pack_index<=pack_index+1; end
                end
                FLUSH: if (!out_valid) state<=REPORT;
                REPORT: if (!result_busy) begin result_send<=1; state<=WAIT_BUSY; end
                WAIT_BUSY: if (result_busy) state<=WAIT_ACK;
                WAIT_ACK: if (!result_busy) begin idle<=1; state<=IDLE; end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
