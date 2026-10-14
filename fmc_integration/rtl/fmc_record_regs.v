`timescale 1ns/1ps
`default_nettype none
// Register bank and read-only block window, all in ui_clk.
// Writes are explicit commands. Reads never advance or release a data block.
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
    reg [15:0] duration_ms, scratch, command_count, last_command;
    reg [6:0] events;
    reg local_error, ram_pending;
    reg [3:0] ram_wait;
    wire [5:0] event_now = {rd_rejected,ack_rejected,ack_accepted,read_accepted,rejected,accepted};
    wire [15:0] status = {2'b00,mode_valid,(protocol_error|local_error),read_error,
        stream_done,block_last,block_ready,read_ready,calib,cfg_done,overflow,valid,done,busy,ready};
    // 100 MSPS: one millisecond equals 100000 pairs. START latches this downstream.
    assign cfg_samples = duration_ms * 32'd100000;

    always @(posedge clk) begin
        if (rst) begin
            duration_ms <= 1; scratch <= 0; command_count <= 0; last_command <= 0;
            events <= 0; local_error <= 0; ram_pending <= 0; ram_wait <= 0;
            reply_valid <= 0; reply_data <= 0; clear_error <= 0;
            cmd_start <= 0; cmd_release <= 0; cmd_read_next <= 0; cmd_ack <= 0;
            rd_en <= 0; rd_addr <= 0;
        end else begin
            reply_valid <= 0; clear_error <= 0;
            cmd_start <= 0; cmd_release <= 0; cmd_read_next <= 0; cmd_ack <= 0;
            rd_en <= 0;
            events <= events | {1'b0,event_now};
            if (ram_pending) begin
                ram_wait <= ram_wait + 1'b1;
                if (rd_valid) begin
                    reply_valid <= 1;
                    reply_data <= rd_data;
                    ram_pending <= 0;
                end else if (ram_wait == 4'd7) begin
                    reply_valid <= 1;
                    reply_data <= 16'hdead;
                    ram_pending <= 0;
                    local_error <= 1;
                    events[6] <= 1;
                end
            end
            if (bus_read) begin
                reply_valid <= 1;
                reply_data <= 16'hffff;
                if (bus_addr >= 24'h002000 && bus_addr < 24'h004000) begin
                    if (block_ready && !ram_pending && {1'b0,bus_addr[12:0]} < block_bytes) begin
                        rd_addr <= bus_addr[12:1];
                        rd_en <= 1;
                        ram_pending <= 1;
                        ram_wait <= 0;
                        reply_valid <= 0;
                    end else begin
                        reply_data <= 16'hdead;
                        local_error <= 1;
                        events[6] <= 1;
                    end
                end else begin
                    case (bus_addr)
                        24'h000000: reply_data <= 16'hadfc;
                        24'h000002: reply_data <= 16'h0100;
                        24'h000004: reply_data <= status;
                        24'h000006: reply_data <= {9'b0,events};
                        24'h000008: reply_data <= duration_ms;
                        24'h00000a: reply_data <= 0;
                        24'h00000c: reply_data <= command_count;
                        24'h00000e: reply_data <= last_command;
                        24'h000010: reply_data <= record_samples[15:0];
                        24'h000012: reply_data <= record_samples[31:16];
                        24'h000014: reply_data <= record_bytes[15:0];
                        24'h000016: reply_data <= record_bytes[31:16];
                        24'h000018: reply_data <= blocks[15:0];
                        24'h00001a: reply_data <= blocks[31:16];
                        24'h00001c: reply_data <= block_index[15:0];
                        24'h00001e: reply_data <= block_index[31:16];
                        24'h000020: reply_data <= block_offset[15:0];
                        24'h000022: reply_data <= block_offset[31:16];
                        24'h000024: reply_data <= {2'b0,block_bytes};
                        24'h000026: reply_data <= scratch;
                        default: reply_data <= 16'hffff;
                    endcase
                end
            end
            if (bus_write && bus_mask != 2'b11) begin
                case (bus_addr)
                    24'h000026: begin
                        if (!bus_mask[0]) scratch[7:0] <= bus_wdata[7:0];
                        if (!bus_mask[1]) scratch[15:8] <= bus_wdata[15:8];
                    end
                    24'h000008: begin
                        if (bus_mask == 0 && bus_wdata >= 1 && bus_wdata <= 200)
                            duration_ms <= bus_wdata;
                        else begin local_error <= 1; events[6] <= 1; end
                    end
                    24'h00000a: begin
                        command_count <= command_count + 1'b1;
                        last_command <= bus_wdata;
                        if (bus_mask != 0) begin local_error <= 1; events[6] <= 1; end
                        else begin
                            case (bus_wdata)
                                16'd1: begin
                                    if (ready && read_idle) cmd_start <= 1;
                                    else begin local_error <= 1; events[6] <= 1; end
                                end
                                16'd2: begin
                                    if (read_ready) cmd_read_next <= 1;
                                    else begin local_error <= 1; events[6] <= 1; end
                                end
                                16'd3: begin
                                    if (block_ready && !ram_pending && !rd_en) cmd_ack <= 1;
                                    else begin local_error <= 1; events[6] <= 1; end
                                end
                                16'd4: begin
                                    if (done && read_idle && !busy) cmd_release <= 1;
                                    else begin local_error <= 1; events[6] <= 1; end
                                end
                                16'd5: begin
                                    events <= {1'b0,event_now};
                                    local_error <= 0;
                                    clear_error <= 1;
                                end
                                default: begin local_error <= 1; events[6] <= 1; end
                            endcase
                        end
                    end
                    default: begin local_error <= 1; events[6] <= 1; end
                endcase
            end
        end
    end
endmodule
`default_nettype wire
