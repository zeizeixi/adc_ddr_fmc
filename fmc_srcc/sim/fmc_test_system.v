`timescale 1ns / 1ps
`default_nettype none
// Verification harness ONLY: acquisition/MIG traffic is modeled here.
// Production uses adc_ddr_fbg484_top, its existing store and real MIG.
module fmc_test_system (
    input wire ui_clk,
    input wire reset_n,
    input wire MCU_FMC_SDCLK,
    input wire MCU_FMC_SDCKE1,
    input wire MCU_FMC_SDNE1,
    input wire MCU_FMC_SDNRAS,
    input wire MCU_FMC_SDNCAS,
    input wire MCU_FMC_SDNWE,
    input wire [12:0] MCU_FMC_A,
    input wire [1:0] MCU_FMC_BA,
    input wire [1:0] MCU_FMC_NBL,
    inout wire [15:0] MCU_FMC_D
);
    wire fmc_clk;
    wire ui_rst;
    wire fmc_rst;
    BUFG u_fmc_bufg (.I(MCU_FMC_SDCLK), .O(fmc_clk));
    reset_sync u_ui_reset (.clk(ui_clk), .arst(!reset_n), .rst(ui_rst));
    reset_sync u_fmc_reset (.clk(fmc_clk), .arst(!reset_n), .rst(fmc_rst));
    wire bus_read, bus_write, memory_selected, reads_idle, clear_error;
    wire [23:0] bus_addr;
    wire [15:0] bus_wdata, register_data;
    wire [1:0] bus_mask;
    wire mode_valid, protocol_error;
    wire [31:0] cfg_samples;
    wire cmd_start, cmd_release, cmd_read_next, cmd_ack, rd_en;
    wire [11:0] rd_addr;
    wire [15:0] rd_data;
    wire rd_valid, block_ready, block_last, read_ready, read_idle, stream_done, read_error;
    wire read_accepted, ack_accepted, ack_rejected, rd_rejected, reader_rejected;
    wire [31:0] block_index, block_offset;
    wire [13:0] block_bytes;
    reg ready;
    reg busy;
    reg done;
    reg valid;
    reg accepted;
    reg [7:0] capture_wait;
    reg [31:0] sampled_limit;
    integer starts;
    integer releases;
    fmc_sdram_sync u_fmc_port (
        .clk(fmc_clk), .rst(fmc_rst), .enabled(1'b1), .clear_error(clear_error),
        .cke(MCU_FMC_SDCKE1), .cs_n(MCU_FMC_SDNE1), .ras_n(MCU_FMC_SDNRAS),
        .cas_n(MCU_FMC_SDNCAS), .we_n(MCU_FMC_SDNWE), .addr(MCU_FMC_A),
        .bank(MCU_FMC_BA), .dqm(MCU_FMC_NBL), .dq(MCU_FMC_D),
        .bus_read(bus_read), .bus_write(bus_write), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_mask(bus_mask), .register_data(register_data),
        .memory_selected(memory_selected), .memory_data(rd_data), .memory_valid(rd_valid),
        .reads_idle(reads_idle), .mode_valid(mode_valid), .protocol_error(protocol_error)
    );
    fmc_record_link u_fmc_regs (
        .ui_clk(ui_clk), .ui_rst(ui_rst), .fmc_clk(fmc_clk), .fmc_rst(fmc_rst),
        .bus_read(bus_read), .bus_write(bus_write), .bus_addr(bus_addr),
        .bus_wdata(bus_wdata), .bus_mask(bus_mask), .register_data(register_data),
        .memory_selected(memory_selected), .reads_idle(reads_idle),
        .mode_valid(mode_valid), .protocol_error(protocol_error), .clear_error(clear_error),
        .cfg_samples(cfg_samples), .cmd_start(cmd_start), .cmd_release(cmd_release),
        .cmd_read_next(cmd_read_next), .cmd_ack(cmd_ack), .rd_en(rd_en), .rd_addr(rd_addr),
        .ready(ready), .busy(busy), .done(done), .valid(valid), .overflow(1'b0),
        .cfg_done(1'b1), .calib(1'b1), .read_ready(read_ready), .read_idle(read_idle),
        .stream_done(stream_done), .read_error(read_error), .block_ready(block_ready),
        .block_last(block_last), .accepted(accepted), .rejected(reader_rejected),
        .read_accepted(read_accepted), .ack_accepted(ack_accepted),
        .ack_rejected(ack_rejected), .rd_rejected(rd_rejected),
        .record_samples(32'd2058), .record_bytes(32'd8232), .blocks(32'd258),
        .block_index(block_index), .block_offset(block_offset), .block_bytes(block_bytes)
    );
    wire [27:0] app_addr;
    wire app_en;
    reg [2:0] response_valid;
    reg [255:0] response_first, response_second, response_third;
    integer halfword;
    ddr_block_reader u_reader (
        .ui_clk(ui_clk), .rst(ui_rst), .init_calib_complete(1'b1),
        .stream_clear(accepted || cmd_release), .record_done(done),
        .record_valid(valid), .record_bytes(32'd8232), .cmd_read_next(cmd_read_next),
        .idle(read_idle), .read_ready(read_ready), .read_accepted(read_accepted),
        .command_rejected(reader_rejected), .stream_done(stream_done), .protocol_error(read_error),
        .app_addr(app_addr), .app_en(app_en), .app_rdy(1'b1),
        .app_rd_data(response_third), .app_rd_data_valid(response_valid[2]), .app_rd_data_end(1'b1),
        .rd_clk(fmc_clk), .rd_rst(fmc_rst), .rd_en(rd_en), .rd_addr(rd_addr),
        .rd_data(rd_data), .rd_valid(rd_valid), .block_ready(block_ready),
        .block_index(block_index), .block_offset(block_offset), .block_bytes(block_bytes),
        .block_last(block_last), .cmd_block_ack(cmd_ack), .ack_accepted(ack_accepted),
        .ack_rejected(ack_rejected), .rd_rejected(rd_rejected)
    );
    always @(posedge ui_clk) begin
        if (ui_rst) begin
            ready <= 1; busy <= 0; done <= 0; valid <= 0; accepted <= 0;
            capture_wait <= 0; sampled_limit <= 0; starts <= 0; releases <= 0;
            response_valid <= 0;
            response_first <= 0; response_second <= 0; response_third <= 0;
        end else begin
            accepted <= 0;
            if (cmd_start) begin
                sampled_limit <= cfg_samples; starts <= starts + 1;
                ready <= 0; busy <= 1; done <= 0; valid <= 0;
                capture_wait <= 20; accepted <= 1;
            end
            if (capture_wait != 0) begin
                capture_wait <= capture_wait - 1'b1;
                if (capture_wait == 1) begin busy <= 0; done <= 1; valid <= 1; end
            end
            if (cmd_release) begin
                ready <= 1; done <= 0; valid <= 0; releases <= releases + 1;
            end
            response_valid <= {response_valid[1:0], app_en};
            response_second <= response_first;
            response_third <= response_second;
            if (app_en) begin
                for (halfword = 0; halfword < 16; halfword = halfword + 1)
                    response_first[halfword*16 +: 16] <= 16'ha500 ^ ((app_addr >> 3)*16 + halfword);
            end
        end
    end
endmodule
`default_nettype wire
