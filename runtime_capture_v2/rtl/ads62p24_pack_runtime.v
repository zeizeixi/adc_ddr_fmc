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
    localparam IDLE=0, CAPTURE=1, FLUSH=2, REPORT=3, WAIT_BUSY=4, WAIT_ACK=5;
    reg [2:0] state, pack_index;
    reg [31:0] limit_q, sample_count, blocks;
    reg [255:0] pack_data;
    reg [255:0] next_pack;
    wire slot_available = !out_valid || out_ready;
    assign result_data = {overflow,blocks,sample_count};
    always @* begin
        next_pack=pack_data;
        next_pack[pack_index*32 +: 32]={4'b0,adc_b_q,4'b0,adc_a_q};
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
