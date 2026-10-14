`timescale 1ns/1ps
`default_nettype none
// Capture and DDR readout integration; VIO commands precede the future FMC bridge.
// ADC package pins / input delays still REQUIRED before implementation.
module adc_ddr_fbg484_top(
    input wire sys_clk, sys_rst_n,
    input wire ADC_CLK_OUT_P,
    input wire [13:2] ADC_DA, ADC_DB,
    output wire ADC_CLK_IN_P, ADC_CLK_IN_N,
    output wire ADC_RESET, ADC_CS, ADC_SCK, ADC_SDI,
    output wire [2:0] ADC_CTRL,

    inout wire [31:0] ddr3_dq,
    inout wire [3:0] ddr3_dqs_n, ddr3_dqs_p,
    output wire [13:0] ddr3_addr,
    output wire [2:0] ddr3_ba,
    output wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n,
    output wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt,
    output wire [3:0] ddr3_dm
);
    wire clk_200m,clk_100m,locked,ui_clk,ui_rst,calib;
    capture_clocks u_clocks(.clk_in1(sys_clk),.reset(!sys_rst_n),.locked(locked),
        .clk_out1(clk_200m),.clk_out2(clk_100m));
    adc_clock_forward_7series u_forward(.clk_100m(clk_100m),.adc_clk_p(ADC_CLK_IN_P),.adc_clk_n(ADC_CLK_IN_N));
    wire [27:0] app_addr;
    wire [2:0] app_cmd;
    wire app_en,app_rdy,app_wdf_wren,app_wdf_end,app_wdf_rdy;
    wire [255:0] app_wdf_data;
    wire [31:0] app_wdf_mask;
    wire [31:0] cfg_samples,record_samples,record_bytes,blocks,latched_samples;
    wire start,release_record,ready,busy,done,valid,overflow,cfg_done,accepted,rejected,capture_finished;
    wire [255:0] app_rd_data;
    wire app_rd_data_valid,app_rd_data_end;
    wire read_next,read_ready,read_accepted,read_idle,stream_done,read_error;
    wire read_word,rd_en,block_ack,clear_debug;
    wire [11:0] rd_addr;
    wire [15:0] rd_data,debug_status,debug_data;
    wire rd_valid,block_ready,block_last,ack_accepted,ack_rejected,rd_rejected;
    wire [31:0] block_index,block_offset,debug_words,debug_acks,debug_requests;
    wire [13:0] block_bytes;
    wire debug_rst;
    reset_sync u_debug_reset(.clk(ui_clk),.arst(!sys_rst_n || !locked || ui_rst),.rst(debug_rst));
    adc_record_store #(.APP_ADDR_WIDTH(28)) u_store(
        .ui_clk(ui_clk),.ui_rst(ui_rst),.global_rst(!sys_rst_n || !locked),.init_calib_complete(calib),
        .adc_clk_out(ADC_CLK_OUT_P),.adc_da(ADC_DA),.adc_db(ADC_DB),
        .adc_reset(ADC_RESET),.adc_cs_n(ADC_CS),.adc_sck(ADC_SCK),.adc_sdi(ADC_SDI),.adc_ctrl(ADC_CTRL),
        .cfg_samples(cfg_samples),.cmd_start(start),.cmd_release(release_record),.cmd_read_next(read_next),
        .ready(ready),.busy(busy),.cfg_done(cfg_done),.start_accepted(accepted),.command_rejected(rejected),
        .record_done(done),.record_valid(valid),.capture_finished(capture_finished),.overflow(overflow),
        .record_samples(record_samples),.record_bytes(record_bytes),.latched_samples(latched_samples),.submitted_blocks(blocks),
        .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),.app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy),
        .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),.app_rd_data_end(app_rd_data_end),
        .read_ready(read_ready),.read_accepted(read_accepted),.read_idle(read_idle),
        .stream_done(stream_done),.read_error(read_error),
        .rd_clk(ui_clk),.rd_en(rd_en),.rd_addr(rd_addr),.rd_data(rd_data),.rd_valid(rd_valid),
        .block_ready(block_ready),.block_index(block_index),.block_offset(block_offset),
        .block_bytes(block_bytes),.block_last(block_last),.cmd_block_ack(block_ack),
        .ack_accepted(ack_accepted),.ack_rejected(ack_rejected),.rd_rejected(rd_rejected));
    // Debug consumer runs on ui_clk. FMC will provide its own consumer clock.
    // VIO toggles become one read pulse; returned data and event flags are held.
    readout_debug u_read_debug(
        .clk(ui_clk),.rst(debug_rst),.read_word(read_word),.clear_debug(clear_debug),.rd_en(rd_en),
        .read_ready(read_ready),.read_idle(read_idle),.block_ready(block_ready),.block_last(block_last),
        .stream_done(stream_done),.read_error(read_error),.rd_valid(rd_valid),.rd_data(rd_data),
        .read_accepted(read_accepted),.ack_accepted(ack_accepted),.command_rejected(rejected),
        .ack_rejected(ack_rejected),.rd_rejected(rd_rejected),.start_accepted(accepted),
        .status(debug_status),.last_data(debug_data),.word_count(debug_words),
        .ack_count(debug_acks),.request_count(debug_requests));
    readout_vio u_read_vio(.clk(ui_clk),
        .probe_in0(debug_status),.probe_in1(block_index),.probe_in2(block_offset),
        .probe_in3(block_bytes),.probe_in4(debug_data),.probe_in5(debug_words),
        .probe_in6(debug_acks),.probe_in7(debug_requests),
        .probe_out0(read_next),.probe_out1(rd_addr),.probe_out2(read_word),
        .probe_out3(block_ack),.probe_out4(clear_debug));
    // Level statuses are readable in VIO. accepted/rejected are one-cycle pulses
    // for the future register bridge, not reliable indicators in a polled VIO UI.
    capture_vio u_vio(.clk(ui_clk),
        .probe_in0(ready),.probe_in1(busy),.probe_in2(done),.probe_in3(valid),
        .probe_in4(overflow),.probe_in5(record_samples),.probe_in6(record_bytes),
        .probe_in7(blocks),.probe_in8(cfg_done),
        .probe_out0(cfg_samples),.probe_out1(start),.probe_out2(release_record));

    mig_7series_0 u_mig(
        .ddr3_dq(ddr3_dq),.ddr3_dqs_n(ddr3_dqs_n),.ddr3_dqs_p(ddr3_dqs_p),
        .ddr3_addr(ddr3_addr),.ddr3_ba(ddr3_ba),.ddr3_ras_n(ddr3_ras_n),
        .ddr3_cas_n(ddr3_cas_n),.ddr3_we_n(ddr3_we_n),.ddr3_reset_n(ddr3_reset_n),
        .ddr3_ck_p(ddr3_ck_p),.ddr3_ck_n(ddr3_ck_n),.ddr3_cke(ddr3_cke),
        .ddr3_cs_n(ddr3_cs_n),.ddr3_odt(ddr3_odt),.ddr3_dm(ddr3_dm),
        .sys_clk_i(clk_200m),.clk_ref_i(clk_200m),.sys_rst(sys_rst_n && locked),
        .ui_clk(ui_clk),.ui_clk_sync_rst(ui_rst),.init_calib_complete(calib),
        .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),.app_wdf_end(app_wdf_end),
        .app_wdf_wren(app_wdf_wren),.app_wdf_rdy(app_wdf_rdy),
        .app_rd_data(app_rd_data),.app_rd_data_valid(app_rd_data_valid),.app_rd_data_end(app_rd_data_end),
        .app_sr_req(1'b0),.app_ref_req(1'b0),.app_zq_req(1'b0),
        .app_sr_active(),.app_ref_ack(),.app_zq_ack());
endmodule
`default_nettype wire

