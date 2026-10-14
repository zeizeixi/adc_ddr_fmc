`timescale 1ns/1ps
`default_nettype none
// MIG DQ32/BL8/4:1 写端：每拍 256 位、地址步进 8；提交到环形区末尾后回到基址。
// 接口协议与边界条件见同目录 mig_write_runtime_spec.md。
module mig_write_runtime #(
    parameter APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0
)(
    input wire clk,
    input wire rst,
    input wire clear,
    input wire enable,
    input wire [31:0] ring_samples,
    input wire [255:0] s_data,
    input wire s_valid,
    output wire s_ready,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire [2:0] app_cmd,
    output wire app_en,
    input wire app_rdy,
    output wire [255:0] app_wdf_data,
    output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren,
    output wire app_wdf_end,
    input wire app_wdf_rdy,
    output wire idle,
    output reg [31:0] submitted_blocks // MIG 已接受的 32 字节写突发次数，含环形覆盖，32 位回绕。
);
    localparam EMPTY=0, DATA=1, COMMAND=2;
    reg [1:0] state;
    reg [255:0] data_q;
    reg [APP_ADDR_WIDTH-1:0] addr_q;
    assign idle=state==EMPTY;
    assign s_ready=enable && !rst && !clear && idle;
    assign app_addr=addr_q;
    assign app_cmd=3'b000;
    assign app_en=enable && !rst && state==COMMAND;
    assign app_wdf_data=data_q;
    assign app_wdf_mask=32'b0;
    assign app_wdf_wren=enable && !rst && state==DATA;
    assign app_wdf_end=app_wdf_wren;
    always @(posedge clk) begin
        if (rst || clear) begin
            state<=EMPTY; data_q<=0; addr_q<=BASE_APP_ADDR; submitted_blocks<=0;
        end else case(state)
            EMPTY: if (s_valid && s_ready) begin data_q<=s_data; state<=DATA; end
            DATA: if(app_wdf_wren && app_wdf_rdy) state<=COMMAND;
            COMMAND: if(app_en && app_rdy) begin
                submitted_blocks<=submitted_blocks+1; if (addr_q == BASE_APP_ADDR + ring_samples - 8) addr_q<=BASE_APP_ADDR;
                else addr_q<=addr_q+8; state<=EMPTY;
            end
            default: state<=EMPTY;
        endcase
    end
endmodule
`default_nettype wire
