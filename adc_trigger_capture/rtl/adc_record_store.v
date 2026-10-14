`timescale 1ns/1ps
`default_nettype none
// 集成采集管理器与分块读出器；UI 域控制采集，读时钟域消费缓存，读写按记录状态互斥。
// 接口协议与边界条件见同目录 adc_record_store_spec.md。
module adc_record_store #(
    parameter MAX_SAMPLES=20000000,APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0,
    parameter TEST_RAMP=0,CFG_POWER_WAIT=500000,CFG_RESET_HIGH=100,
    parameter CFG_RESET_WAIT=100,CFG_SETTLE=300000
)(
    input wire ui_clk,
    input wire ui_rst,
    input wire global_rst,
    input wire init_calib_complete,
    input wire adc_clk_out,
    input wire [13:2] adc_da,
    input wire [13:2] adc_db,
    output wire adc_reset,
    output wire adc_cs_n,
    output wire adc_sck,
    output wire adc_sdi,
    output wire [2:0] adc_ctrl,
    input wire [31:0] cfg_samples, // 下一次记录的 A/B 总对数；不是单通道半字数。
    input wire [6:0] cfg_pre_percent, // 前触发比例 0～100；ARM/START 接受时锁存。
    input wire [2:0] cfg_trigger_type_a, // A 路比较：0 >=、1 >、2 ==、3 <=、4 <。
    input wire [2:0] cfg_trigger_type_b, // B 路比较：0 >=、1 >、2 ==、3 <=、4 <。
    input wire cfg_auto_mode, // 0 手动 FORCE；1 自动等待比较条件，不设超时。
    input wire [1:0] cfg_trigger_enable, // bit0 电压 A，bit1 电流 B；已使能条件按 OR 组合。
    input wire [11:0] cfg_threshold_a, // A 路校正后 ADC 阈值码，0～4095。
    input wire [11:0] cfg_threshold_b, // B 路校正后 ADC 阈值码，0～4095。
    input wire cmd_arm, // 锁存配置并建立前触发历史。
    input wire cmd_force, // 手动触发命令；前触发历史就绪后才能接受。
    input wire cmd_abort, // 取消准备、等待或采集；排空已提交数据后回到 READY。
    output wire trigger_armed, // ADC 已进入本次采样且尚未触发。
    output wire history_ready, // 前触发历史已足够，手动模式可发送 FORCE。
    output wire trigger_seen, // 本次触发已发生；不等于 DDR 写入已排空。
    output wire capture_aborted, // 本次已取消；下次接受采集时清除。
    output wire [2:0] trigger_reason, // DONE 后有效：bit0 电压、bit1 电流、bit2 手动。
    output wire [31:0] record_pre_samples, // 本次前触发样本对数；100% 前触发时等于 N。
    input wire cmd_start,
    input wire cmd_release,
    input wire cmd_read_next,
    output wire ready,
    output wire busy,
    output wire cfg_done,
    output wire start_accepted,
    output wire command_rejected,
    output wire record_done, // 本条采集收尾完成，所有待写数据和命令已被 MIG 接受。
    output wire record_valid, // 本条记录有效；溢出或取消时不能读为有效记录。
    output wire capture_finished,
    output wire overflow,
    output wire [31:0] record_samples,
    output wire [31:0] record_bytes, // 有效记录字节数；每对 A/B 占 4 字节。
    output wire [31:0] latched_samples,
    output wire [31:0] submitted_blocks, // MIG 已接受的 32 字节写突发次数，含环形覆盖，32 位回绕。
    output wire read_ready, // 可请求下一块；没有当前块占用且还有剩余记录。
    output wire read_accepted,
    output wire read_idle,
    output wire stream_done, // 最后一块 ACK 已返回 UI 域。
    output wire read_error,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire [2:0] app_cmd,
    output wire app_en,
    input wire app_rdy,
    output wire [255:0] app_wdf_data,
    output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren,
    output wire app_wdf_end,
    input wire app_wdf_rdy,
    input wire [255:0] app_rd_data,
    input wire app_rd_data_valid,
    input wire app_rd_data_end,
    input wire rd_clk,
    input wire rd_en,
    input wire [11:0] rd_addr, // 8 KiB 缓存的 16 位字地址，0～4095。
    output wire [15:0] rd_data,
    output wire rd_valid, // 本拍 rd_data 为有效返回；缓存读延迟为两拍。
    output wire block_ready,
    output wire [31:0] block_index, // 当前读块序号，从 0 开始。
    output wire [31:0] block_offset, // 当前块在逻辑记录中的字节偏移。
    output wire [13:0] block_bytes, // 当前读块有效字节数，最大 8192。
    output wire block_last, // 仅 BLOCK_READY 时解释为当前块是否末块。
    input wire cmd_block_ack,
    output wire ack_accepted,
    output wire ack_rejected,
    output wire rd_rejected
);
    wire rst,rd_rst;
    wire [31:0] record_start_sample;
    wire [31:0] record_ring_samples;
    reset_sync u_ui_reset(.clk(ui_clk),
        .arst(global_rst|ui_rst),
        .rst(rst));
    reset_sync u_rd_reset(.clk(rd_clk),
        .arst(global_rst|ui_rst),
        .rst(rd_rst));
    reg start_d,arm_d,release_d,read_d,local_rejected;
    wire start_edge=cmd_start && !start_d;
    wire arm_edge=cmd_arm && !arm_d;
    wire release_edge=cmd_release && !release_d;
    wire read_edge=cmd_read_next && !read_d;
    wire [2:0] command_total={2'b0,start_edge}+{2'b0,arm_edge}+
        {2'b0,release_edge}+{2'b0,read_edge}+{2'b0,cmd_force}+{2'b0,cmd_abort};
    wire conflict=command_total>1;
    wire start_forward=start_edge && !conflict && read_idle;
    wire arm_forward=arm_edge && !conflict && read_idle;
    wire release_forward=release_edge && !conflict && read_idle && record_done;
    wire read_forward=read_edge && !conflict;
    always @(posedge ui_clk) begin
        if(rst) begin start_d<=0;arm_d<=0;release_d<=0;read_d<=0;local_rejected<=0;end
        else begin
            start_d<=cmd_start;arm_d<=cmd_arm;release_d<=cmd_release;read_d<=cmd_read_next;
            local_rejected<=conflict || ((start_edge || arm_edge) && !read_idle) || (release_edge && (!read_idle || !record_done));
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
    adc_capture_runtime #(.MAX_SAMPLES(MAX_SAMPLES),
        .APP_ADDR_WIDTH(APP_ADDR_WIDTH),
        .BASE_APP_ADDR(BASE_APP_ADDR),
        .TEST_RAMP(TEST_RAMP),
        .CFG_POWER_WAIT(CFG_POWER_WAIT),
        .CFG_RESET_HIGH(CFG_RESET_HIGH),
        .CFG_RESET_WAIT(CFG_RESET_WAIT),
        .CFG_SETTLE(CFG_SETTLE)) u_capture(
        .ui_clk(ui_clk),
        .ui_rst(ui_rst),
        .global_rst(global_rst),
        .init_calib_complete(init_calib_complete),
        .adc_clk_out(adc_clk_out),
        .adc_da(adc_da),
        .adc_db(adc_db),
        .adc_reset(adc_reset),
        .adc_cs_n(adc_cs_n),
        .adc_sck(adc_sck),
        .adc_sdi(adc_sdi),
        .adc_ctrl(adc_ctrl),
        .cfg_samples(cfg_samples),
        .cfg_trigger_type_a(cfg_trigger_type_a),
        .cfg_trigger_type_b(cfg_trigger_type_b),
        .cfg_pre_percent(cfg_pre_percent),
        .cfg_auto_mode(cfg_auto_mode),
        .cfg_trigger_enable(cfg_trigger_enable),
        .cfg_threshold_a(cfg_threshold_a),
        .cfg_threshold_b(cfg_threshold_b),
        .cmd_arm(arm_forward),
        .cmd_force(cmd_force && !conflict),
        .cmd_abort(cmd_abort && !conflict),
        .trigger_armed(trigger_armed),
        .history_ready(history_ready),
        .trigger_seen(trigger_seen),
        .capture_aborted(capture_aborted),
        .trigger_reason(trigger_reason),
        .record_start_sample(record_start_sample),
        .record_ring_samples(record_ring_samples),
        .record_pre_samples(record_pre_samples),
        .cmd_start(start_forward),
        .cmd_release(release_forward),
        .ready(capture_ready),
        .busy(busy),
        .cfg_done(cfg_done),
        .start_accepted(start_accepted),
        .command_rejected(capture_rejected),
        .record_done(record_done),
        .record_valid(record_valid),
        .capture_finished(capture_finished),
        .overflow(overflow),
        .record_samples(record_samples),
        .record_bytes(record_bytes),
        .latched_samples(latched_samples),
        .submitted_blocks(submitted_blocks),
        .app_addr(wr_addr),
        .app_cmd(wr_cmd),
        .app_en(wr_en),
        .app_rdy(app_rdy && !record_done),
        .app_wdf_data(app_wdf_data),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),
        .app_wdf_end(app_wdf_end),
        .app_wdf_rdy(app_wdf_rdy));
    ddr_block_reader #(.APP_ADDR_WIDTH(APP_ADDR_WIDTH),
        .BASE_APP_ADDR(BASE_APP_ADDR)) u_reader(
        .ui_clk(ui_clk),
        .rst(rst),
        .init_calib_complete(init_calib_complete),
        .stream_clear(start_accepted || release_forward),
        .record_done(record_done),
        .record_valid(record_valid),
        .record_bytes(record_bytes),
        .cmd_read_next(read_forward),
        .record_start_sample(record_start_sample),
        .record_ring_samples(record_ring_samples),
        .idle(read_idle),
        .read_ready(read_ready),
        .read_accepted(read_accepted),
        .command_rejected(reader_rejected),
        .stream_done(stream_done),
        .protocol_error(read_error),
        .app_addr(read_addr),
        .app_en(read_en),
        .app_rdy(app_rdy && record_done),
        .app_rd_data(app_rd_data),
        .app_rd_data_valid(app_rd_data_valid),
        .app_rd_data_end(app_rd_data_end),
        .rd_clk(rd_clk),
        .rd_rst(rd_rst),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rd_valid(rd_valid),
        .block_ready(block_ready),
        .block_index(block_index),
        .block_offset(block_offset),
        .block_bytes(block_bytes),
        .block_last(block_last),
        .cmd_block_ack(cmd_block_ack),
        .ack_accepted(ack_accepted),
        .ack_rejected(ack_rejected),
        .rd_rejected(rd_rejected));
endmodule
`default_nettype wire
