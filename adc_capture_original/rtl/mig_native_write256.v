`timescale 1ns/1ps
`default_nettype none
// OPTIONAL adapter: ONLY x32 DDR3 + BL8 + 4:1 UI => one 256-bit UI beat/burst.
// Write data is accepted BEFORE its command (never command-first).
// No reads/arbitration. Native addresses are not AXI byte addresses; step=8.
// done means all commands AND payloads accepted by MIG, not a DRAM write ACK.
module mig_native_write256 #(
    parameter integer APP_ADDR_WIDTH = 29,
    parameter integer CAPTURE_SAMPLES = 20000000,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR = 0
)(
    input wire ui_clk, input wire rst, input wire init_calib_complete,
    input wire [255:0] s_data, input wire s_valid, output wire s_ready,
    output wire [APP_ADDR_WIDTH-1:0] app_addr, output wire [2:0] app_cmd,
    output wire app_en, input wire app_rdy,
    output wire [255:0] app_wdf_data, output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren, output wire app_wdf_end, input wire app_wdf_rdy,
    output reg done, output reg [31:0] words_submitted
);
    localparam integer TOTAL_WORDS = (CAPTURE_SAMPLES+7)/8;
    localparam [1:0] EMPTY=0, SEND_DATA=1, SEND_CMD=2, FINISHED=3;
    reg [1:0] state;
    reg [255:0] data_q;
    reg [APP_ADDR_WIDTH-1:0] addr_q;
    wire enabled = init_calib_complete && !rst;
    assign s_ready = enabled && state==EMPTY;
    assign app_wdf_data = data_q;
    assign app_wdf_mask = 32'b0; // Tail padding is written; valid length is separate.
    assign app_wdf_wren = enabled && state==SEND_DATA;
    assign app_wdf_end = app_wdf_wren;
    assign app_addr = addr_q;
    assign app_cmd = 3'b000;
    assign app_en = enabled && state==SEND_CMD;
    always @(posedge ui_clk) begin
        if (rst) begin
            state <= EMPTY; data_q <= 0; addr_q <= BASE_APP_ADDR;
            done <= 0; words_submitted <= 0;
        end else begin
            case (state)
                EMPTY: if (s_valid && s_ready) begin data_q <= s_data; state <= SEND_DATA; end
                SEND_DATA: if (app_wdf_wren && app_wdf_rdy) state <= SEND_CMD;
                SEND_CMD: if (app_en && app_rdy) begin
                    words_submitted <= words_submitted+1;
                    if (words_submitted == TOTAL_WORDS-1) begin done <= 1; state <= FINISHED; end
                    else begin addr_q <= addr_q+8; state <= EMPTY; end
                end
                FINISHED: begin end
                default: state <= EMPTY;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if (CAPTURE_SAMPLES<1 || CAPTURE_SAMPLES>20000000 || BASE_APP_ADDR%8 != 0)
            $fatal(1,"Invalid capture size or unaligned MIG base address");
        if (({1'b0,BASE_APP_ADDR} + (TOTAL_WORDS-1)*64'd8) >> APP_ADDR_WIDTH)
            $fatal(1,"MIG address would wrap");
    end
    // synthesis translate_on
endmodule
`default_nettype wire
