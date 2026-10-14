`timescale 1ns/1ps
`default_nettype none
// Stage 1 board integration: VIO commands replace the future FMC bridge.
// ADC package pins / input delays still REQUIRED before implementation.
module adc_ddr_fbg484_top(
    input wire sys_clk, sys_rst_n,
    input wire ADC_CLK_OUT_P,
    input wire [13:2] ADC_DA, ADC_DB,
    output wire ADC_CLK_IN_P, ADC_CLK_IN_N,
    output wire ADC_RESET, ADC_CS, ADC_SCK, ADC_SDI,
    output wire [2:0] ADC_CTRL,
    output wire [1:0] led,
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
    adc_capture_runtime #(.APP_ADDR_WIDTH(28)) u_capture(
        .ui_clk(ui_clk),.ui_rst(ui_rst),.global_rst(!sys_rst_n || !locked),.init_calib_complete(calib),
        .adc_clk_out(ADC_CLK_OUT_P),.adc_da(ADC_DA),.adc_db(ADC_DB),
        .adc_reset(ADC_RESET),.adc_cs_n(ADC_CS),.adc_sck(ADC_SCK),.adc_sdi(ADC_SDI),.adc_ctrl(ADC_CTRL),
        .cfg_samples(cfg_samples),.cmd_start(start),.cmd_release(release_record),
        .ready(ready),.busy(busy),.cfg_done(cfg_done),.start_accepted(accepted),.command_rejected(rejected),
        .record_done(done),.record_valid(valid),.capture_finished(capture_finished),.overflow(overflow),
        .record_samples(record_samples),.record_bytes(record_bytes),.latched_samples(latched_samples),.submitted_blocks(blocks),
        .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),.app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy));
    // Level statuses are readable in VIO. accepted/rejected are one-cycle pulses
    // for the future register bridge, not reliable indicators in a polled VIO UI.
    capture_vio u_vio(.clk(ui_clk),
        .probe_in0(ready),.probe_in1(busy),.probe_in2(done),.probe_in3(valid),
        .probe_in4(overflow),.probe_in5(record_samples),.probe_in6(record_bytes),
        .probe_in7(blocks),.probe_in8(cfg_done),
        .probe_out0(cfg_samples),.probe_out1(start),.probe_out2(release_record));
    assign led={overflow,calib}; // Raw levels; adjust presentation for LED polarity.
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
        .app_rd_data(),.app_rd_data_valid(),.app_rd_data_end(),
        .app_sr_req(1'b0),.app_ref_req(1'b0),.app_zq_req(1'b0),
        .app_sr_active(),.app_ref_ack(),.app_zq_ack());
endmodule
`default_nettype wire
