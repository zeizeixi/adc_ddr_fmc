`timescale 1ns / 1ps
`default_nettype none
// UI-domain acquisition commands, FMC-domain RAM reads/ACK, coherent UI snapshots.
// FIFO preserves SET/START/READ_NEXT/RELEASE ordering; ACK stays in the RAM domain.
module fmc_record_link (
    input wire ui_clk,
    input wire ui_rst,
    input wire fmc_clk,
    input wire fmc_rst,
    input wire bus_read,
    input wire bus_write,
    input wire [23:0] bus_addr,
    input wire [15:0] bus_wdata,
    input wire [1:0] bus_mask,
    output reg [15:0] register_data,
    output wire memory_selected,
    input wire reads_idle,
    input wire mode_valid,
    input wire protocol_error,
    output wire clear_error,
    output wire [31:0] cfg_samples,
    output wire cmd_start,
    output wire cmd_release,
    output wire cmd_read_next,
    output wire cmd_ack,
    output wire rd_en,
    output wire [11:0] rd_addr,
    input wire ready,
    input wire busy,
    input wire done,
    input wire valid,
    input wire overflow,
    input wire cfg_done,
    input wire calib,
    input wire read_ready,
    input wire read_idle,
    input wire stream_done,
    input wire read_error,
    input wire block_ready,
    input wire block_last,
    input wire accepted,
    input wire rejected,
    input wire read_accepted,
    input wire ack_accepted,
    input wire ack_rejected,
    input wire rd_rejected,
    input wire [31:0] record_samples,
    input wire [31:0] record_bytes,
    input wire [31:0] blocks,
    input wire [31:0] block_index,
    input wire [31:0] block_offset,
    input wire [13:0] block_bytes
);
    reg [15:0] duration_ui;
    reg [15:0] duration_fmc;
    reg [15:0] scratch;
    reg [15:0] command_count;
    reg [15:0] last_command;
    reg [2:0] events_ui;
    reg [1:0] events_ack;
    reg local_error_ui;
    reg local_error_fmc;
    reg clear_epoch_ui;
    reg clear_epoch_fmc;
    reg write_gap;
    reg ack_lock;
    reg cmd_start_o;
    reg cmd_release_o;
    reg cmd_read_next_o;
    reg cmd_ack_o;
    wire [41:0] fifo_data;
    wire fifo_full;
    wire fifo_empty;
    wire fifo_write_busy;
    wire fifo_read_busy;
    wire fifo_overflow;
    wire fifo_underflow;
    wire fifo_read = !ui_rst && !fifo_empty && !fifo_read_busy && !write_gap;
    wire [23:0] queued_addr = fifo_data[41:18];
    wire [15:0] queued_data = fifo_data[17:2];
    wire [1:0] queued_mask = fifo_data[1:0];
    wire command_address = bus_addr == 24'h00000a;
    wire command_known = bus_wdata >= 1 && bus_wdata <= 5;
    wire duration_write = bus_addr == 24'h000008 && bus_mask == 0 && bus_wdata >= 1 && bus_wdata <= 200;
    wire queued_command = command_address && bus_mask == 0 && command_known && bus_wdata != 3;
    wire enqueue = bus_write && (duration_write || queued_command);
    wire enqueue_ready = !fifo_full && !fifo_write_busy && !fmc_rst;
    wire write_fifo = enqueue && enqueue_ready;
    wire ack_write = bus_write && command_address && bus_mask == 0 && bus_wdata == 3;
    wire clear_write = write_fifo && command_address && bus_wdata == 5;
    wire window_address = bus_addr >= 24'h002000 && bus_addr < 24'h004000;
    wire block_available = block_ready && !ack_lock;
    wire word_in_block = {1'b0, bus_addr[12:0]} < block_bytes;
    wire [127:0] snapshot_data;
    wire snapshot_busy;
    wire snapshot_valid;
    wire [15:0] ui_flags = {1'b0, read_idle, 2'b00, read_error, stream_done,
        2'b00, read_ready, calib, cfg_done, overflow, valid, done, busy, ready};
    wire [127:0] snapshot_source = {11'b0, clear_epoch_ui, local_error_ui, events_ui,
        ui_flags, blocks, record_bytes, record_samples};
    wire epoch_matches = snapshot_data[116] == clear_epoch_fmc;
    wire [15:0] status = {2'b00, mode_valid,
        (protocol_error || local_error_fmc || (epoch_matches && snapshot_data[115])),
        snapshot_data[107], snapshot_data[106], block_last, block_available,
        (snapshot_data[103] && !block_ready && !ack_lock), snapshot_data[102:96]};
    wire [6:0] events = {local_error_fmc || (epoch_matches && snapshot_data[115]),
        1'b0, events_ack, (epoch_matches ? snapshot_data[114:112] : 3'b000)};

    assign cfg_samples = duration_ui * 32'd100000;
    assign cmd_start = cmd_start_o;
    assign cmd_release = cmd_release_o;
    assign cmd_read_next = cmd_read_next_o;
    assign cmd_ack = cmd_ack_o;
    assign clear_error = clear_write;
    assign memory_selected = window_address && block_available && word_in_block;
    assign rd_en = bus_read && memory_selected && !fmc_rst;
    assign rd_addr = bus_addr[12:1];

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(3), .DOUT_RESET_VALUE("0"), .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"), .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(16), .FULL_RESET_VALUE(1), .PROG_EMPTY_THRESH(5),
        .PROG_FULL_THRESH(10), .RD_DATA_COUNT_WIDTH(5), .READ_DATA_WIDTH(42),
        .READ_MODE("fwft"), .RELATED_CLOCKS(0), .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"), .WAKEUP_TIME(0), .WRITE_DATA_WIDTH(42),
        .WR_DATA_COUNT_WIDTH(5)
    ) u_commands (
        .rst(fmc_rst), .wr_clk(fmc_clk), .rd_clk(ui_clk),
        .din({bus_addr, bus_wdata, bus_mask}), .wr_en(write_fifo), .rd_en(fifo_read),
        .dout(fifo_data), .full(fifo_full), .empty(fifo_empty),
        .wr_rst_busy(fifo_write_busy), .rd_rst_busy(fifo_read_busy),
        .overflow(fifo_overflow), .underflow(fifo_underflow),
        .sleep(1'b0), .injectdbiterr(1'b0), .injectsbiterr(1'b0),
        .almost_empty(), .almost_full(), .data_valid(), .dbiterr(),
        .sbiterr(), .prog_empty(), .prog_full(), .rd_data_count(),
        .wr_data_count(), .wr_ack()
    );

    cdc_mailbox #(.WIDTH(128)) u_status_mail (
        .src_clk(ui_clk), .src_rst(ui_rst), .src_send(!snapshot_busy),
        .src_data(snapshot_source), .src_busy(snapshot_busy),
        .dst_clk(fmc_clk), .dst_rst(fmc_rst), .dst_valid(snapshot_valid),
        .dst_data(snapshot_data)
    );

    // All metadata from UI arrives as one coherent, acknowledged image.
    always @(*) begin
        register_data = 16'hffff;
        if (window_address) register_data = 16'hdead;
        else begin
            case (bus_addr)
                24'h000000: register_data = 16'hadfc;
                24'h000002: register_data = 16'h0100;
                24'h000004: register_data = status;
                24'h000006: register_data = {9'b0, events};
                24'h000008: register_data = duration_fmc;
                24'h00000a: register_data = 0;
                24'h00000c: register_data = command_count;
                24'h00000e: register_data = last_command;
                24'h000010: register_data = snapshot_data[15:0];
                24'h000012: register_data = snapshot_data[31:16];
                24'h000014: register_data = snapshot_data[47:32];
                24'h000016: register_data = snapshot_data[63:48];
                24'h000018: register_data = snapshot_data[79:64];
                24'h00001a: register_data = snapshot_data[95:80];
                24'h00001c: register_data = block_index[15:0];
                24'h00001e: register_data = block_index[31:16];
                24'h000020: register_data = block_offset[15:0];
                24'h000022: register_data = block_offset[31:16];
                24'h000024: register_data = {2'b0, block_bytes};
                24'h000026: register_data = scratch;
                default: register_data = 16'hffff;
            endcase
        end
    end

    always @(posedge fmc_clk or posedge fmc_rst) begin
        if (fmc_rst) begin
            duration_fmc <= 1;
            scratch <= 0;
            command_count <= 0;
            last_command <= 0;
            events_ack <= 0;
            local_error_fmc <= 0;
            clear_epoch_fmc <= 0;
            ack_lock <= 0;
            cmd_ack_o <= 0;
        end else begin
            cmd_ack_o <= 0;
            if (!block_ready) ack_lock <= 0;
            if (ack_accepted) events_ack[0] <= 1;
            if (ack_rejected) events_ack[1] <= 1;
            if (rd_rejected) local_error_fmc <= 1;
            if (bus_read && window_address && !memory_selected) local_error_fmc <= 1;
            if (enqueue && !enqueue_ready) local_error_fmc <= 1;
            if (bus_write && bus_mask != 2'b11) begin
                if (bus_addr == 24'h000026) begin
                    if (!bus_mask[0]) scratch[7:0] <= bus_wdata[7:0];
                    if (!bus_mask[1]) scratch[15:8] <= bus_wdata[15:8];
                end else if (bus_addr == 24'h000008) begin
                    if (duration_write && enqueue_ready) duration_fmc <= bus_wdata;
                    else local_error_fmc <= 1;
                end else if (command_address) begin
                    command_count <= command_count + 1'b1;
                    last_command <= bus_wdata;
                    if (!command_known || bus_mask != 0) local_error_fmc <= 1;
                    if (ack_write) begin
                        if (block_available && reads_idle && !cmd_ack_o) begin
                            cmd_ack_o <= 1;
                            ack_lock <= 1;
                        end else begin
                            events_ack[1] <= 1;
                            local_error_fmc <= 1;
                        end
                    end
                    if (clear_write) begin
                        events_ack <= 0;
                        local_error_fmc <= 0;
                        clear_epoch_fmc <= !clear_epoch_fmc;
                    end
                end else local_error_fmc <= 1;
            end
        end
    end

    always @(posedge ui_clk or posedge ui_rst) begin
        if (ui_rst) begin
            duration_ui <= 1;
            events_ui <= 0;
            local_error_ui <= 0;
            clear_epoch_ui <= 0;
            write_gap <= 0;
            cmd_start_o <= 0;
            cmd_release_o <= 0;
            cmd_read_next_o <= 0;
        end else begin
            write_gap <= fifo_read;
            cmd_start_o <= 0;
            cmd_release_o <= 0;
            cmd_read_next_o <= 0;
            events_ui <= events_ui | {read_accepted, rejected, accepted};
            if (fifo_read) begin
                if (queued_addr == 24'h000008) duration_ui <= queued_data;
                else if (queued_addr == 24'h00000a && queued_mask == 0) begin
                    case (queued_data)
                        16'd1: begin
                            if (ready && read_idle) cmd_start_o <= 1;
                            else begin local_error_ui <= 1; events_ui[1] <= 1; end
                        end
                        16'd2: begin
                            if (read_ready) cmd_read_next_o <= 1;
                            else begin local_error_ui <= 1; events_ui[1] <= 1; end
                        end
                        16'd4: begin
                            if (done && read_idle && !busy) cmd_release_o <= 1;
                            else begin local_error_ui <= 1; events_ui[1] <= 1; end
                        end
                        16'd5: begin
                            events_ui <= {read_accepted, rejected, accepted};
                            local_error_ui <= 0;
                            clear_epoch_ui <= !clear_epoch_ui;
                        end
                        default: local_error_ui <= 1;
                    endcase
                end else local_error_ui <= 1;
            end
        end
    end
endmodule
`default_nettype wire
