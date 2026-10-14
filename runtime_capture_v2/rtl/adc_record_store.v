`timescale 1ns/1ps
`default_nettype none
// Integration boundary for board top / future FMC bridge. No package pins here.
// cfg/start/release/read_next: ui_clk domain. RAM read/ACK: consumer rd_clk domain.
// Capture first, then read; single MIG command owner, no concurrent capture/read.
module adc_record_store #(
    parameter MAX_SAMPLES=20000000,APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0,
    parameter TEST_RAMP=0,CFG_POWER_WAIT=500000,CFG_RESET_HIGH=100,
    parameter CFG_RESET_WAIT=100,CFG_SETTLE=300000
)(
    input wire ui_clk,ui_rst,global_rst,init_calib_complete,
    input wire adc_clk_out,input wire [13:2] adc_da,adc_db,
    output wire adc_reset,adc_cs_n,adc_sck,adc_sdi,output wire [2:0] adc_ctrl,
    input wire [31:0] cfg_samples,input wire cmd_start,cmd_release,cmd_read_next,
    output wire ready,busy,cfg_done,start_accepted,command_rejected,record_done,record_valid,capture_finished,overflow,
    output wire [31:0] record_samples,record_bytes,latched_samples,submitted_blocks,
    output wire read_ready,read_accepted,read_idle,stream_done,read_error,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,output wire [2:0] app_cmd,
    output wire app_en,input wire app_rdy,
    output wire [255:0] app_wdf_data,output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren,app_wdf_end,input wire app_wdf_rdy,
    input wire [255:0] app_rd_data,input wire app_rd_data_valid,app_rd_data_end,
    input wire rd_clk,rd_en,input wire [11:0] rd_addr,
    output wire [15:0] rd_data,output wire rd_valid,block_ready,
    output wire [31:0] block_index,block_offset,output wire [13:0] block_bytes,
    output wire block_last,input wire cmd_block_ack,
    output wire ack_accepted,ack_rejected,rd_rejected
);
    wire rst,rd_rst;
    reset_sync u_ui_reset(.clk(ui_clk),.arst(global_rst|ui_rst),.rst(rst));
    reset_sync u_rd_reset(.clk(rd_clk),.arst(global_rst|ui_rst),.rst(rd_rst));
    reg start_d,release_d,read_d,local_rejected;
    wire start_edge=cmd_start && !start_d;
    wire release_edge=cmd_release && !release_d;
    wire read_edge=cmd_read_next && !read_d;
    wire conflict=(start_edge && release_edge)||(start_edge && read_edge)||(release_edge && read_edge);
    wire start_forward=start_edge && !conflict && read_idle;
    wire release_forward=release_edge && !conflict && read_idle && record_done;
    wire read_forward=read_edge && !conflict;
    always @(posedge ui_clk) begin
        if(rst) begin start_d<=0;release_d<=0;read_d<=0;local_rejected<=0;end
        else begin
            start_d<=cmd_start;release_d<=cmd_release;read_d<=cmd_read_next;
            local_rejected<=conflict || (start_edge && !read_idle) || (release_edge && (!read_idle || !record_done));
        end
    end
    wire capture_ready,capture_rejected,reader_rejected;
    wire [APP_ADDR_WIDTH-1:0] wr_addr,read_addr;
    wire [2:0] wr_cmd;
    wire wr_en,read_en;
    // record_done remains asserted throughout readout; release only when reader idle.
    assign app_addr=record_done?read_addr:wr_addr;
    assign app_cmd=record_done?3'b001:wr_cmd;
    assign app_en=record_done?read_en:wr_en;
    assign ready=capture_ready && read_idle;
    assign command_rejected=capture_rejected || reader_rejected || local_rejected;
    adc_capture_runtime #(.MAX_SAMPLES(MAX_SAMPLES),.APP_ADDR_WIDTH(APP_ADDR_WIDTH),.BASE_APP_ADDR(BASE_APP_ADDR),
        .TEST_RAMP(TEST_RAMP),.CFG_POWER_WAIT(CFG_POWER_WAIT),.CFG_RESET_HIGH(CFG_RESET_HIGH),
        .CFG_RESET_WAIT(CFG_RESET_WAIT),.CFG_SETTLE(CFG_SETTLE)) u_capture(
        .ui_clk(ui_clk),.ui_rst(ui_rst),.global_rst(global_rst),.init_calib_complete(init_calib_complete),
        .adc_clk_out(adc_clk_out),.adc_da(adc_da),.adc_db(adc_db),
        .adc_reset(adc_reset),.adc_cs_n(adc_cs_n),.adc_sck(adc_sck),.adc_sdi(adc_sdi),.adc_ctrl(adc_ctrl),
        .cfg_samples(cfg_samples),.cmd_start(start_forward),.cmd_release(release_forward),
        .ready(capture_ready),.busy(busy),.cfg_done(cfg_done),.start_accepted(start_accepted),.command_rejected(capture_rejected),
        .record_done(record_done),.record_valid(record_valid),.capture_finished(capture_finished),.overflow(overflow),
        .record_samples(record_samples),.record_bytes(record_bytes),.latched_samples(latched_samples),.submitted_blocks(submitted_blocks),
        .app_addr(wr_addr),.app_cmd(wr_cmd),.app_en(wr_en),.app_rdy(app_rdy && !record_done),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),.app_wdf_wren(app_wdf_wren),.app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy));
    ddr_block_reader #(.APP_ADDR_WIDTH(APP_ADDR_WIDTH),.BASE_APP_ADDR(BASE_APP_ADDR)) u_reader(
        .ui_clk(ui_clk),.rst(rst),.init_calib_complete(init_calib_complete),.stream_clear(start_accepted || release_forward),
        .record_done(record_done),.record_valid(record_valid),.record_bytes(record_bytes),.cmd_read_next(read_forward),
        .idle(read_idle),.read_ready(read_ready),.read_accepted(read_accepted),.command_rejected(reader_rejected),
        .stream_done(stream_done),.protocol_error(read_error),.app_addr(read_addr),.app_en(read_en),.app_rdy(app_rdy && record_done),
        .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),.app_rd_data_end(app_rd_data_end),
        .rd_clk(rd_clk),.rd_rst(rd_rst),.rd_en(rd_en),.rd_addr(rd_addr),.rd_data(rd_data),.rd_valid(rd_valid),
        .block_ready(block_ready),.block_index(block_index),.block_offset(block_offset),.block_bytes(block_bytes),.block_last(block_last),
        .cmd_block_ack(cmd_block_ack),.ack_accepted(ack_accepted),.ack_rejected(ack_rejected),.rd_rejected(rd_rejected));
endmodule
`default_nettype wire
