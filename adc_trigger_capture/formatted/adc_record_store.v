`timescale 1ns/1ps
`default_nettype none

////////////////////////////////////English///////////////////////////////////////
// Company:         
// Engineer:        
//
// Create Date:     2026/10/12 17:27:13
// Design Name:     adc_record_store
// Module Name:     adc_record_store
// Description:     description/adc_record_store_Design.pdf
// Simulations:     testbench/vivado/2021.1/adc_record_store
//
// Referrences:     None
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/12 17:27:13
// History:
// Time             Version     Revised by        Contents
// 2026/10/12       V1.0                          Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        
// 开发人员:        
//
// 创建日期:        2026年10月12日
// 设计名称:        adc_record_store
// 模块名称:        adc_record_store
// 模块说明:        Description/adc_record_store_Design.pdf
// 仿真工程:        TestBench/Vivado/2021.1/adc_record_store
//
// 参考资料:        None
//
// 依赖文件:        None
//
// 当前版本:        V1.0
// 修订日期:        2026年10月12日
// 修订历史:
// 时间             版本        修订人            修订内容
// 2026年10月12日   V1.0                          创建文件

module adc_record_store
#(
    parameter C_MAX_SAMPLES = 20000000, APP_ADDR_WIDTH = 28, // parameter
    parameter [APP_ADDR_WIDTH - 1:0]C_BASE_APP_ADDR = 0, // parameter
    parameter C_TEST_RAMP = 0, CFG_POWER_WAIT = 500000, CFG_RESET_HIGH = 100, // parameter
    parameter C_CFG_RESET_WAIT = 100, CFG_SETTLE = 300000 // parameter
)
(
    //-----------------全局信号-----------------//
    input i_ui_clk,                             // port signal
    input i_ui_rst,                             // port signal
    input i_global_rst,                         // port signal

    //-----------------用户接口-----------------//
    input i_init_calib_complete,                // port signal

    //-----------------全局信号-----------------//
    input i_adc_clk_out,                        // port signal

    //-----------------用户接口-----------------//
    input [13:2]i_adc_da,                       // port signal
    input [13:2]i_adc_db,                       // port signal

    //-----------------全局信号-----------------//
    output o_adc_reset,                         // port signal

    //-----------------用户接口-----------------//
    output o_adc_cs_n,                          // port signal

    //ADC接口
    output o_adc_sck,                           // port signal
    output o_adc_sdi,                           // port signal
    output [2:0]o_adc_ctrl,                     // port signal
    input [31:0]i_cfg_samples,                  // port signal
    input [6:0]i_cfg_pre_percent,               // port signal
    input i_cfg_auto_mode,                      // port signal
    input [1:0]i_cfg_trigger_enable,            // port signal
    input [11:0]i_cfg_threshold_a,              // port signal
    input [11:0]i_cfg_threshold_b,              // port signal

    //CMD接口
    input i_cmd_arm,                            // port signal
    input i_cmd_force,                          // port signal
    input i_cmd_abort,                          // port signal
    output o_trigger_armed,                     // port signal
    output o_history_ready,                     // port signal
    output o_trigger_seen,                      // port signal
    output o_capture_aborted,                   // port signal
    output [2:0]o_trigger_reason,               // port signal
    output [31:0]o_record_pre_samples,          // port signal
    input i_cmd_start,                          // port signal
    input i_cmd_release,                        // port signal
    input i_cmd_read_next,                      // port signal
    output o_ready,                             // port signal
    output o_busy,                              // port signal
    output o_cfg_done,                          // port signal
    output o_start_accepted,                    // port signal
    output o_command_rejected,                  // port signal
    output o_record_done,                       // port signal
    output o_record_valid,                      // port signal
    output o_capture_finished,                  // port signal
    output o_overflow,                          // port signal
    output [31:0]o_record_samples,              // port signal
    output [31:0]o_record_bytes,                // port signal
    output [31:0]o_latched_samples,             // port signal
    output [31:0]o_submitted_blocks,            // port signal

    //READ接口
    output o_read_ready,                        // port signal
    output o_read_accepted,                     // port signal
    output o_read_idle,                         // port signal
    output o_stream_done,                       // port signal
    output o_read_error,                        // port signal

    //APP接口
    output [APP_ADDR_WIDTH - 1:0]o_app_addr,    // port signal
    output [2:0]o_app_cmd,                      // port signal
    output o_app_en,                            // port signal
    input i_app_rdy,                            // port signal

    //APP_WDF接口
    output [255:0]o_app_wdf_data,               // port signal
    output [31:0]o_app_wdf_mask,                // port signal
    output o_app_wdf_wren,                      // port signal
    output o_app_wdf_end,                       // port signal
    input i_app_wdf_rdy,                        // port signal
    input [255:0]i_app_rd_data,                 // port signal
    input i_app_rd_data_valid,                  // port signal
    input i_app_rd_data_end,                    // port signal

    //-----------------全局信号-----------------//
    input i_rd_clk,                             // port signal

    //-----------------用户接口-----------------//
    input i_rd_en,                              // port signal

    //------------------RD接口------------------//

    //RD接口
    input [11:0]i_rd_addr,                      // port signal
    output [15:0]o_rd_data,                     // port signal
    output o_rd_valid,                          // port signal

    //-----------------用户接口-----------------//

    //BLOCK接口
    output o_block_ready,                       // port signal
    output [31:0]o_block_index,                 // port signal
    output [31:0]o_block_offset,                // port signal
    output [13:0]o_block_bytes,                 // port signal
    output o_block_last,                        // port signal
    input i_cmd_block_ack,                      // port signal
    output o_ack_accepted,                      // port signal
    output o_ack_rejected,                      // port signal
    output o_rd_rejected                        // port signal
);

    //--------------模块实例化信号--------------//
    //reset_sync--用户接口
    wire rst;                                   // signal
    wire rd_rst;                                // signal

    //adc_capture_runtime--用户接口
    wire [31:0]record_start_sample;             // signal
    wire [31:0]record_ring_samples;             // signal
    wire capture_ready;                         // signal
    wire capture_rejected;                      // signal
    wire [APP_ADDR_WIDTH - 1:0]wr_addr;         // signal
    wire [2:0]wr_cmd;                           // signal
    wire wr_en;                                 // signal

    //ddr_block_reader--用户接口
    wire reader_rejected;                       // signal
    wire [APP_ADDR_WIDTH - 1:0]read_addr;       // signal
    wire read_en;                               // signal

    //----------------寄存器信号----------------//
    reg reg_start_d = 0;                        // signal
    reg reg_arm_d = 0;                          // signal
    reg reg_release_d = 0;                      // signal
    reg reg_read_d = 0;                         // signal
    reg reg_local_rejected = 0;                 // signal

    //-----------------其他信号-----------------//
    wire start_edge = i_cmd_start && !reg_start_d; // signal
    wire arm_edge = i_cmd_arm && !reg_arm_d;    // signal
    wire release_edge = i_cmd_release && !reg_release_d; // signal
    wire read_edge = i_cmd_read_next && !reg_read_d; // signal
    wire [2:0]command_total = {2'b0, start_edge} + {2'b0, arm_edge} + {2'b0, release_edge} + {2'b0, read_edge} + {2'b0, i_cmd_force} + {2'b0, i_cmd_abort}; // signal
    wire conflict = command_total > 1;          // signal
    wire start_forward = start_edge && !conflict && read_idle_o; // signal
    wire arm_forward = arm_edge && !conflict && read_idle_o; // signal
    wire release_forward = release_edge && !conflict && read_idle_o && record_done_o; // signal
    wire read_forward = read_edge && !conflict; // signal

    //-----------------输出信号-----------------//
    //全局信号
    reg adc_reset_o = 0;                        // internal output signal

    //用户接口
    reg adc_cs_n_o = 0;                         // internal output signal

    //用户接口ADC接口
    reg adc_sck_o = 0;                          // internal output signal
    reg adc_sdi_o = 0;                          // internal output signal
    reg [2:0]adc_ctrl_o = 0;                    // internal output signal

    //用户接口
    reg trigger_armed_o = 0;                    // internal output signal
    reg history_ready_o = 0;                    // internal output signal
    reg trigger_seen_o = 0;                     // internal output signal
    reg capture_aborted_o = 0;                  // internal output signal
    reg [2:0]trigger_reason_o = 0;              // internal output signal
    reg [31:0]record_pre_samples_o = 0;         // internal output signal
    reg busy_o = 0;                             // internal output signal
    reg cfg_done_o = 0;                         // internal output signal
    reg start_accepted_o = 0;                   // internal output signal
    reg record_done_o = 0;                      // internal output signal
    reg record_valid_o = 0;                     // internal output signal
    reg capture_finished_o = 0;                 // internal output signal
    reg overflow_o = 0;                         // internal output signal
    reg [31:0]record_samples_o = 0;             // internal output signal
    reg [31:0]record_bytes_o = 0;               // internal output signal
    reg [31:0]latched_samples_o = 0;            // internal output signal
    reg [31:0]submitted_blocks_o = 0;           // internal output signal

    //用户接口READ接口
    reg read_ready_o = 0;                       // internal output signal
    reg read_accepted_o = 0;                    // internal output signal
    reg read_idle_o = 0;                        // internal output signal

    //用户接口
    reg stream_done_o = 0;                      // internal output signal
    reg read_error_o = 0;                       // internal output signal

    //用户接口APP_WDF接口
    reg [255:0]app_wdf_data_o = 0;              // internal output signal
    reg [31:0]app_wdf_mask_o = 0;               // internal output signal
    reg app_wdf_wren_o = 0;                     // internal output signal
    reg app_wdf_end_o = 0;                      // internal output signal

    //RD接口
    reg [15:0]rd_data_o = 0;                    // internal output signal
    reg rd_valid_o = 0;                         // internal output signal

    //用户接口BLOCK接口
    reg block_ready_o = 0;                      // internal output signal
    reg [31:0]block_index_o = 0;                // internal output signal
    reg [31:0]block_offset_o = 0;               // internal output signal
    reg [13:0]block_bytes_o = 0;                // internal output signal
    reg block_last_o = 0;                       // internal output signal

    //用户接口
    reg ack_accepted_o = 0;                     // internal output signal
    reg ack_rejected_o = 0;                     // internal output signal
    reg rd_rejected_o = 0;                      // internal output signal

    //---------------输出信号连线---------------//
    //全局信号
    assign o_adc_reset = adc_reset_o;           // output bridge

    //用户接口
    assign o_adc_cs_n = adc_cs_n_o;             // output bridge

    //用户接口ADC接口
    assign o_adc_sck = adc_sck_o;               // output bridge
    assign o_adc_sdi = adc_sdi_o;               // output bridge
    assign o_adc_ctrl = adc_ctrl_o;             // output bridge

    //用户接口
    assign o_trigger_armed = trigger_armed_o;   // output bridge
    assign o_history_ready = history_ready_o;   // output bridge
    assign o_trigger_seen = trigger_seen_o;     // output bridge
    assign o_capture_aborted = capture_aborted_o; // output bridge
    assign o_trigger_reason = trigger_reason_o; // output bridge
    assign o_record_pre_samples = record_pre_samples_o; // output bridge
    assign o_ready = capture_ready && read_idle_o; // assign
    assign o_busy = busy_o;                     // output bridge
    assign o_cfg_done = cfg_done_o;             // output bridge
    assign o_start_accepted = start_accepted_o; // output bridge
    assign o_command_rejected = capture_rejected || reader_rejected || reg_local_rejected; // assign
    assign o_record_done = record_done_o;       // output bridge
    assign o_record_valid = record_valid_o;     // output bridge
    assign o_capture_finished = capture_finished_o; // output bridge
    assign o_overflow = overflow_o;             // output bridge
    assign o_record_samples = record_samples_o; // output bridge
    assign o_record_bytes = record_bytes_o;     // output bridge
    assign o_latched_samples = latched_samples_o; // output bridge
    assign o_submitted_blocks = submitted_blocks_o; // output bridge

    //用户接口READ接口
    assign o_read_ready = read_ready_o;         // output bridge
    assign o_read_accepted = read_accepted_o;   // output bridge
    assign o_read_idle = read_idle_o;           // output bridge

    //用户接口
    assign o_stream_done = stream_done_o;       // output bridge
    assign o_read_error = read_error_o;         // output bridge

    //用户接口APP接口
    // record_done remains asserted throughout readout; release only when reader idle.
    assign o_app_addr = record_done_o ? read_addr : wr_addr; // assign
    assign o_app_cmd = record_done_o ? 3'b001 : wr_cmd; // assign
    assign o_app_en = record_done_o ? read_en : wr_en; // assign

    //用户接口APP_WDF接口
    assign o_app_wdf_data = app_wdf_data_o;     // output bridge
    assign o_app_wdf_mask = app_wdf_mask_o;     // output bridge
    assign o_app_wdf_wren = app_wdf_wren_o;     // output bridge
    assign o_app_wdf_end = app_wdf_end_o;       // output bridge

    //RD接口
    assign o_rd_data = rd_data_o;               // output bridge
    assign o_rd_valid = rd_valid_o;             // output bridge

    //用户接口BLOCK接口
    assign o_block_ready = block_ready_o;       // output bridge
    assign o_block_index = block_index_o;       // output bridge
    assign o_block_offset = block_offset_o;     // output bridge
    assign o_block_bytes = block_bytes_o;       // output bridge
    assign o_block_last = block_last_o;         // output bridge

    //用户接口
    assign o_ack_accepted = ack_accepted_o;     // output bridge
    assign o_ack_rejected = ack_rejected_o;     // output bridge
    assign o_rd_rejected = rd_rejected_o;       // output bridge

    //-------------主要任务处理区域-------------//
    always@(posedge i_ui_clk)begin
        if(rst == 1'b1)begin
            reg_start_d <= 0;
            reg_arm_d <= 0;
            reg_release_d <= 0;
            reg_read_d <= 0;
            reg_local_rejected <= 0;
        end else begin
            reg_start_d <= i_cmd_start; reg_arm_d <= i_cmd_arm; reg_release_d <= i_cmd_release; reg_read_d <= i_cmd_read_next;
            reg_local_rejected <= conflict || ((start_edge || arm_edge) && !read_idle_o) || (release_edge && (!read_idle_o || !record_done_o));
        end
    end

    //--------------模块实例化区域--------------//
    reset_sync u_ui_reset(
        .clk(i_ui_clk),                         // clk端口连接i_ui_clk
        .arst(i_global_rst | i_ui_rst),         // arst端口连接i_global_rst | i_ui_rst
        .rst(rst)                               // rst端口连接rst
    );

    reset_sync u_rd_reset(
        .clk(i_rd_clk),                         // clk端口连接i_rd_clk
        .arst(i_global_rst | i_ui_rst),         // arst端口连接i_global_rst | i_ui_rst
        .rst(rd_rst)                            // rst端口连接rd_rst
    );

    adc_capture_runtime #(
        .MAX_SAMPLES(C_MAX_SAMPLES),            // MAX_SAMPLES参数映射为C_MAX_SAMPLES
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH),        // APP_ADDR_WIDTH参数映射为APP_ADDR_WIDTH
        .BASE_APP_ADDR(C_BASE_APP_ADDR),        // BASE_APP_ADDR参数映射为C_BASE_APP_ADDR
        .TEST_RAMP(C_TEST_RAMP),                // TEST_RAMP参数映射为C_TEST_RAMP
        .CFG_POWER_WAIT(CFG_POWER_WAIT),        // CFG_POWER_WAIT参数映射为CFG_POWER_WAIT
        .CFG_RESET_HIGH(CFG_RESET_HIGH),        // CFG_RESET_HIGH参数映射为CFG_RESET_HIGH
        .CFG_RESET_WAIT(C_CFG_RESET_WAIT),      // CFG_RESET_WAIT参数映射为C_CFG_RESET_WAIT
        .CFG_SETTLE(CFG_SETTLE)                 // CFG_SETTLE参数映射为CFG_SETTLE
    )u_capture(
        .ui_clk(i_ui_clk),                      // ui_clk端口连接i_ui_clk
        .ui_rst(i_ui_rst),                      // ui_rst端口连接i_ui_rst
        .global_rst(i_global_rst),              // global_rst端口连接i_global_rst
        .init_calib_complete(i_init_calib_complete), // init_calib_complete端口连接i_init_calib_complete
        .adc_clk_out(i_adc_clk_out),            // adc_clk_out端口连接i_adc_clk_out
        .adc_da(i_adc_da),                      // adc_da端口连接i_adc_da
        .adc_db(i_adc_db),                      // adc_db端口连接i_adc_db
        .adc_reset(adc_reset_o),                // adc_reset端口连接adc_reset_o
        .adc_cs_n(adc_cs_n_o),                  // adc_cs_n端口连接adc_cs_n_o
        .adc_sck(adc_sck_o),                    // adc_sck端口连接adc_sck_o
        .adc_sdi(adc_sdi_o),                    // adc_sdi端口连接adc_sdi_o
        .adc_ctrl(adc_ctrl_o),                  // adc_ctrl端口连接adc_ctrl_o
        .cfg_samples(i_cfg_samples),            // cfg_samples端口连接i_cfg_samples
        .cfg_pre_percent(i_cfg_pre_percent),    // cfg_pre_percent端口连接i_cfg_pre_percent
        .cfg_auto_mode(i_cfg_auto_mode),        // cfg_auto_mode端口连接i_cfg_auto_mode
        .cfg_trigger_enable(i_cfg_trigger_enable), // cfg_trigger_enable端口连接i_cfg_trigger_enable
        .cfg_threshold_a(i_cfg_threshold_a),    // cfg_threshold_a端口连接i_cfg_threshold_a
        .cfg_threshold_b(i_cfg_threshold_b),    // cfg_threshold_b端口连接i_cfg_threshold_b
        .cmd_arm(arm_forward),                  // cmd_arm端口连接arm_forward
        .cmd_force(i_cmd_force && !conflict),   // cmd_force端口连接i_cmd_force && !conflict
        .cmd_abort(i_cmd_abort && !conflict),   // cmd_abort端口连接i_cmd_abort && !conflict
        .trigger_armed(trigger_armed_o),        // trigger_armed端口连接trigger_armed_o
        .history_ready(history_ready_o),        // history_ready端口连接history_ready_o
        .trigger_seen(trigger_seen_o),          // trigger_seen端口连接trigger_seen_o
        .capture_aborted(capture_aborted_o),    // capture_aborted端口连接capture_aborted_o
        .trigger_reason(trigger_reason_o),      // trigger_reason端口连接trigger_reason_o
        .record_start_sample(record_start_sample), // record_start_sample端口连接record_start_sample
        .record_ring_samples(record_ring_samples), // record_ring_samples端口连接record_ring_samples
        .record_pre_samples(record_pre_samples_o), // record_pre_samples端口连接record_pre_samples_o
        .cmd_start(start_forward),              // cmd_start端口连接start_forward
        .cmd_release(release_forward),          // cmd_release端口连接release_forward
        .ready(capture_ready),                  // ready端口连接capture_ready
        .busy(busy_o),                          // busy端口连接busy_o
        .cfg_done(cfg_done_o),                  // cfg_done端口连接cfg_done_o
        .start_accepted(start_accepted_o),      // start_accepted端口连接start_accepted_o
        .command_rejected(capture_rejected),    // command_rejected端口连接capture_rejected
        .record_done(record_done_o),            // record_done端口连接record_done_o
        .record_valid(record_valid_o),          // record_valid端口连接record_valid_o
        .capture_finished(capture_finished_o),  // capture_finished端口连接capture_finished_o
        .overflow(overflow_o),                  // overflow端口连接overflow_o
        .record_samples(record_samples_o),      // record_samples端口连接record_samples_o
        .record_bytes(record_bytes_o),          // record_bytes端口连接record_bytes_o
        .latched_samples(latched_samples_o),    // latched_samples端口连接latched_samples_o
        .submitted_blocks(submitted_blocks_o),  // submitted_blocks端口连接submitted_blocks_o
        .app_addr(wr_addr),                     // app_addr端口连接wr_addr
        .app_cmd(wr_cmd),                       // app_cmd端口连接wr_cmd
        .app_en(wr_en),                         // app_en端口连接wr_en
        .app_rdy(i_app_rdy && !record_done_o),  // app_rdy端口连接i_app_rdy && !record_done_o
        .app_wdf_data(app_wdf_data_o),          // app_wdf_data端口连接app_wdf_data_o
        .app_wdf_mask(app_wdf_mask_o),          // app_wdf_mask端口连接app_wdf_mask_o
        .app_wdf_wren(app_wdf_wren_o),          // app_wdf_wren端口连接app_wdf_wren_o
        .app_wdf_end(app_wdf_end_o),            // app_wdf_end端口连接app_wdf_end_o
        .app_wdf_rdy(i_app_wdf_rdy)             // app_wdf_rdy端口连接i_app_wdf_rdy
    );

    ddr_block_reader #(
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH),        // APP_ADDR_WIDTH参数映射为APP_ADDR_WIDTH
        .BASE_APP_ADDR(C_BASE_APP_ADDR)         // BASE_APP_ADDR参数映射为C_BASE_APP_ADDR
    )u_reader(
        .ui_clk(i_ui_clk),                      // ui_clk端口连接i_ui_clk
        .rst(rst),                              // rst端口连接rst
        .init_calib_complete(i_init_calib_complete), // init_calib_complete端口连接i_init_calib_complete
        .stream_clear(start_accepted_o || release_forward), // stream_clear端口连接start_accepted_o || release_forward
        .record_done(record_done_o),            // record_done端口连接record_done_o
        .record_valid(record_valid_o),          // record_valid端口连接record_valid_o
        .record_bytes(record_bytes_o),          // record_bytes端口连接record_bytes_o
        .cmd_read_next(read_forward),           // cmd_read_next端口连接read_forward
        .record_start_sample(record_start_sample), // record_start_sample端口连接record_start_sample
        .record_ring_samples(record_ring_samples), // record_ring_samples端口连接record_ring_samples
        .idle(read_idle_o),                     // idle端口连接read_idle_o
        .read_ready(read_ready_o),              // read_ready端口连接read_ready_o
        .read_accepted(read_accepted_o),        // read_accepted端口连接read_accepted_o
        .command_rejected(reader_rejected),     // command_rejected端口连接reader_rejected
        .stream_done(stream_done_o),            // stream_done端口连接stream_done_o
        .protocol_error(read_error_o),          // protocol_error端口连接read_error_o
        .app_addr(read_addr),                   // app_addr端口连接read_addr
        .app_en(read_en),                       // app_en端口连接read_en
        .app_rdy(i_app_rdy && record_done_o),   // app_rdy端口连接i_app_rdy && record_done_o
        .app_rd_data(i_app_rd_data),            // app_rd_data端口连接i_app_rd_data
        .app_rd_data_valid(i_app_rd_data_valid), // app_rd_data_valid端口连接i_app_rd_data_valid
        .app_rd_data_end(i_app_rd_data_end),    // app_rd_data_end端口连接i_app_rd_data_end
        .rd_clk(i_rd_clk),                      // rd_clk端口连接i_rd_clk
        .rd_rst(rd_rst),                        // rd_rst端口连接rd_rst
        .rd_en(i_rd_en),                        // rd_en端口连接i_rd_en
        .rd_addr(i_rd_addr),                    // rd_addr端口连接i_rd_addr
        .rd_data(rd_data_o),                    // rd_data端口连接rd_data_o
        .rd_valid(rd_valid_o),                  // rd_valid端口连接rd_valid_o
        .block_ready(block_ready_o),            // block_ready端口连接block_ready_o
        .block_index(block_index_o),            // block_index端口连接block_index_o
        .block_offset(block_offset_o),          // block_offset端口连接block_offset_o
        .block_bytes(block_bytes_o),            // block_bytes端口连接block_bytes_o
        .block_last(block_last_o),              // block_last端口连接block_last_o
        .cmd_block_ack(i_cmd_block_ack),        // cmd_block_ack端口连接i_cmd_block_ack
        .ack_accepted(ack_accepted_o),          // ack_accepted端口连接ack_accepted_o
        .ack_rejected(ack_rejected_o),          // ack_rejected端口连接ack_rejected_o
        .rd_rejected(rd_rejected_o)             // rd_rejected端口连接rd_rejected_o
    );

endmodule
