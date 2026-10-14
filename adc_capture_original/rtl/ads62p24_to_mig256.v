`timescale 1ns/1ps
`default_nettype none
// Example integration; connect to a SEPARATELY generated, matching MIG.
// This is not a pin-complete board top. See README before using on hardware.
module ads62p24_to_mig256 #(
    parameter integer CAPTURE_SAMPLES = 20000000,
    parameter integer APP_ADDR_WIDTH = 29,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR = 0,
    parameter integer TEST_RAMP = 0,
    parameter integer CFG_POWER_WAIT = 100000,
    parameter integer CFG_RESET_HIGH = 100,
    parameter integer CFG_RESET_WAIT = 100,
    parameter integer CFG_SETTLE = 10000
)(
    input wire i_sys_clk_100m, input wire i_sys_rst,
    input wire i_adc_clk_out,
    input wire [13:2] i_adc_da, input wire [13:2] i_adc_db,
    output wire o_adc_reset, output wire o_adc_cs_n,
    output wire o_adc_sck, output wire o_adc_sdi, output wire [2:0] o_adc_ctrl,
    input wire i_ui_clk, input wire i_ui_rst, input wire i_mig_calib_done,
    input wire i_start_sys,
    output wire o_ready_sys, output wire o_cfg_done_sys,
    output wire o_capture_done_sys, output wire o_capture_busy_sys,
    output wire o_overflow_sys, output wire o_mig_submitted_sys,
    output wire [APP_ADDR_WIDTH-1:0] app_addr, output wire [2:0] app_cmd,
    output wire app_en, input wire app_rdy,
    output wire [255:0] app_wdf_data, output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren, output wire app_wdf_end, input wire app_wdf_rdy
);
    wire [255:0] data;
    wire valid, ready;
    ads62p24_capture_top #(
        .CAPTURE_SAMPLES(CAPTURE_SAMPLES),.TEST_RAMP(TEST_RAMP),
        .CFG_POWER_WAIT(CFG_POWER_WAIT),.CFG_RESET_HIGH(CFG_RESET_HIGH),
        .CFG_RESET_WAIT(CFG_RESET_WAIT),.CFG_SETTLE(CFG_SETTLE)
    ) u_front (
        .i_sys_clk_100m(i_sys_clk_100m),.i_sys_rst(i_sys_rst),
        .i_adc_clk_out(i_adc_clk_out),.i_adc_da(i_adc_da),.i_adc_db(i_adc_db),
        .o_adc_reset(o_adc_reset),.o_adc_cs_n(o_adc_cs_n),.o_adc_sck(o_adc_sck),
        .o_adc_sdi(o_adc_sdi),.o_adc_ctrl(o_adc_ctrl),
        .i_ui_clk(i_ui_clk),.i_ui_rst(i_ui_rst),.i_mig_calib_done(i_mig_calib_done),
        .i_start_sys(i_start_sys),.o_ready_sys(o_ready_sys),.o_cfg_done_sys(o_cfg_done_sys),
        .o_capture_done_sys(o_capture_done_sys),.o_capture_busy_sys(o_capture_busy_sys),
        .o_overflow_sys(o_overflow_sys),.o_data_ui(data),.o_valid_ui(valid),.i_ready_ui(ready),
        .o_adc_clk_debug(),.o_sample_count_adc()
    );
    wire writer_rst;
    reset_sync u_writer_reset(.clk(i_ui_clk),
        .arst(i_sys_rst | i_ui_rst | !o_cfg_done_sys),.rst(writer_rst));
    wire submitted;
    mig_native_write256 #(.CAPTURE_SAMPLES(CAPTURE_SAMPLES),
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH),.BASE_APP_ADDR(BASE_APP_ADDR)) u_writer (
        .ui_clk(i_ui_clk),.rst(writer_rst),.init_calib_complete(i_mig_calib_done),
        .s_data(data),.s_valid(valid),.s_ready(ready),
        .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),.app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy),
        .done(submitted),.words_submitted()
    );
    level_sync u_submitted(.clk(i_sys_clk_100m),.rst(i_sys_rst | i_ui_rst),
        .async_in(submitted),.sync_out(o_mig_submitted_sys));
endmodule
`default_nettype wire
