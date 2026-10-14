`timescale 1ns/1ps
`default_nettype none
// VIO adapter in one clock domain. No control crosses a clock domain here.
module readout_debug(
    input wire clk,rst,read_word,clear_debug,
    output wire rd_en,
    input wire read_ready,read_idle,block_ready,block_last,stream_done,read_error,
    input wire rd_valid,input wire [15:0] rd_data,
    input wire read_accepted,ack_accepted,command_rejected,ack_rejected,rd_rejected,start_accepted,
    output wire [15:0] status,
    output reg [15:0] last_data,
    output reg [31:0] word_count,ack_count,request_count
);
    reg read_d,clear_d;
    reg [6:0] events;
    wire clear_edge=clear_debug && !clear_d;
    wire [6:0] event_now={start_accepted,rd_rejected,ack_rejected,command_rejected,
                         ack_accepted,read_accepted,rd_valid};
    assign rd_en=read_word && !read_d && !rst;
    assign status={3'b0,events,read_error,stream_done,block_last,block_ready,read_idle,read_ready};
    always @(posedge clk) begin
        if(rst) begin
            read_d<=0;clear_d<=0;events<=0;last_data<=0;
            word_count<=0;ack_count<=0;request_count<=0;
        end else begin
            read_d<=read_word;clear_d<=clear_debug;
            // An event on the clear cycle is retained; clear is edge-triggered.
            if(clear_edge) begin
                events<=event_now;
                last_data<=rd_valid?rd_data:16'b0;
                word_count<=rd_valid?32'd1:32'd0;
                ack_count<=ack_accepted?32'd1:32'd0;
                request_count<=read_accepted?32'd1:32'd0;
            end else begin
                events<=events|event_now;
                if(rd_valid) begin last_data<=rd_data;word_count<=word_count+1'b1;end
                if(ack_accepted) ack_count<=ack_count+1'b1;
                if(read_accepted) request_count<=request_count+1'b1;
            end
        end
    end
endmodule
`default_nettype wire
