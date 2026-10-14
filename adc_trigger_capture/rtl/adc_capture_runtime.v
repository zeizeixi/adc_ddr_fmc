`timescale 1ns/1ps
`default_nettype none
// 锁存配置，建立前触发历史，接收触发/取消，排空 FIFO 和 MIG 写命令后发布记录。
// 接口协议与边界条件见同目录 adc_capture_runtime_spec.md。
module adc_capture_runtime #(
    parameter integer MAX_SAMPLES=20000000,
    parameter integer APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0,
    parameter integer TEST_RAMP=0,
    parameter integer CFG_POWER_WAIT=500000,
    parameter integer CFG_RESET_HIGH=100,
    parameter integer CFG_RESET_WAIT=100,
    parameter integer CFG_SETTLE=300000
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
    input wire cmd_start,
    input wire cmd_arm, // 锁存配置并建立前触发历史。
    input wire cmd_force, // 手动触发命令；前触发历史就绪后才能接受。
    input wire cmd_abort, // 取消准备、等待或采集；排空已提交数据后回到 READY。
    input wire cmd_release,
    output wire trigger_armed, // ADC 已进入本次采样且尚未触发。
    output wire history_ready, // 前触发历史已足够，手动模式可发送 FORCE。
    output wire trigger_seen, // 本次触发已发生；不等于 DDR 写入已排空。
    output reg capture_aborted, // 本次已取消；下次接受采集时清除。
    output reg [2:0] trigger_reason, // DONE 后有效：bit0 电压、bit1 电流、bit2 手动。
    output reg [31:0] record_start_sample, // 有效记录第一对样本的物理环形索引。
    output wire [31:0] record_ring_samples, // 物理环形容量，8 对对齐并额外保留 8 对。
    output wire [31:0] record_pre_samples, // 本次前触发样本对数；100% 前触发时等于 N。
    output wire ready,
    output wire busy,
    output wire cfg_done,
    output reg start_accepted,
    output reg command_rejected,
    output reg record_done, // 本条采集收尾完成，所有待写数据和命令已被 MIG 接受。
    output reg record_valid, // 本条记录有效；溢出或取消时不能读为有效记录。
    output wire capture_finished,
    output wire overflow,
    output reg [31:0] record_samples,
    output reg [31:0] record_bytes, // 有效记录字节数；每对 A/B 占 4 字节。
    output reg [31:0] latched_samples,
    output wire [31:0] submitted_blocks, // MIG 已接受的 32 字节写突发次数，含环形覆盖，32 位回绕。
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire [2:0] app_cmd,
    output wire app_en,
    input wire app_rdy,
    output wire [255:0] app_wdf_data,
    output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren,
    output wire app_wdf_end,
    input wire app_wdf_rdy
);
    wire rst, adc_clk, adc_rst;
    reset_sync u_ui_reset(.clk(ui_clk),
        .arst(global_rst|ui_rst),
        .rst(rst));
    BUFG u_adc_bufg(.I(adc_clk_out),
        .O(adc_clk));
    ads62p24_init #(.TEST_RAMP(TEST_RAMP),
        .POWER_WAIT_CYCLES(CFG_POWER_WAIT),
        .RESET_HIGH_CYCLES(CFG_RESET_HIGH),
        .RESET_WAIT_CYCLES(CFG_RESET_WAIT),
        .SETTLE_CYCLES(CFG_SETTLE)) u_init(
        .clk(ui_clk),
        .rst(rst),
        .adc_reset(adc_reset),
        .adc_cs_n(adc_cs_n),
        .adc_sck(adc_sck),
        .adc_sdi(adc_sdi),
        .adc_ctrl(adc_ctrl),
        .done(cfg_done));
    wire fifo_reset = global_rst | ui_rst | rst | !cfg_done;
    reset_sync u_adc_reset(.clk(adc_clk),
        .arst(fifo_reset),
        .rst(adc_rst));
    wire full,empty,wr_rst_busy,rd_rst_busy;
    wire wr_busy_ui, full_ui, pack_idle_ui;
    level_sync #(.RESET_VALUE(1'b1)) u_wbusy(.clk(ui_clk),
        .rst(rst),
        .async_in(wr_rst_busy),
        .sync_out(wr_busy_ui));
    level_sync #(.RESET_VALUE(1'b1)) u_full(.clk(ui_clk),
        .rst(rst),
        .async_in(full),
        .sync_out(full_ui));
    reg send_start;
    wire start_mail_busy, start_adc;

    wire [129:0] config_adc;
    reg [11:0] threshold_a_q;
    reg [11:0] threshold_b_q;
    reg [2:0] type_a_q;
    reg [2:0] type_b_q;
    reg auto_q;
    reg [1:0] trigger_enable_q;
    reg immediate_q;
    reg [6:0] percent_q;
    reg geometry_start;
    wire geometry_busy;
    wire geometry_done;
    wire [31:0] pre_q;
    wire [31:0] ring_q;
    trigger_geometry u_geometry (
        .clk(ui_clk),
        .rst(rst),
        .start(geometry_start),
        .samples(latched_samples),
        .percent(percent_q),
        .busy(geometry_busy),
        .done(geometry_done),
        .pre_samples(pre_q),
        .ring_samples(ring_q)
    );
    assign record_ring_samples = ring_q;
    assign record_pre_samples = pre_q;
    reg control_send;
    reg [1:0] control_data;
    wire control_busy;
    wire control_valid;
    wire [1:0] control_adc;
    cdc_mailbox #(.WIDTH(2)) u_control_mail (
        .src_clk(ui_clk),
        .src_rst(rst),
        .src_send(control_send),
        .src_data(control_data),
        .src_busy(control_busy),
        .dst_clk(adc_clk),
        .dst_rst(adc_rst),
        .dst_valid(control_valid),
        .dst_data(control_adc)
    );
    cdc_mailbox #(.WIDTH(130)) u_start_mail(
        .src_clk(ui_clk),
        .src_rst(rst),
        .src_send(send_start),
        .src_data({type_a_q,type_b_q,latched_samples,pre_q,ring_q,threshold_a_q,threshold_b_q,auto_q,trigger_enable_q,immediate_q}),
        .src_busy(start_mail_busy),
        .dst_clk(adc_clk),
        .dst_rst(adc_rst),
        .dst_valid(start_adc),
        .dst_data(config_adc));

    wire pack_idle, pack_error, result_send, result_busy, result_valid;
    wire history_adc, triggered_adc, history_ui, triggered_ui;
    level_sync u_history(.clk(ui_clk),
        .rst(rst),
        .async_in(history_adc),
        .sync_out(history_ui));
    level_sync u_trigger(.clk(ui_clk),
        .rst(rst),
        .async_in(triggered_adc),
        .sync_out(triggered_ui));
    wire [68:0] result_adc, result_ui;
    wire [255:0] pack_data, fifo_data;
    wire pack_valid, writer_ready;
    wire pack_ready=!full && !wr_rst_busy && !adc_rst;
    ads62p24_pack_runtime u_pack(
        .adc_clk(adc_clk),
        .rst(adc_rst),
        .start(start_adc),
        .sample_limit(config_adc[123:92]),
        .pre_samples(config_adc[91:60]),
        .ring_samples(config_adc[59:28]),
        .threshold_a(config_adc[27:16]),
        .threshold_b(config_adc[15:4]),
        .trigger_type_a(config_adc[129:127]),
        .trigger_type_b(config_adc[126:124]),
        .auto_mode(config_adc[3]),
        .trigger_enable(config_adc[2:1]),
        .immediate(config_adc[0]),
        .force_trigger(control_valid && control_adc[0]),
        .abort_capture(control_valid && control_adc[1]),
        .history_ready(history_adc),
        .triggered(triggered_adc),
        .adc_a(adc_da),
        .adc_b(adc_db),
        .out_data(pack_data),
        .out_valid(pack_valid),
        .out_ready(pack_ready),
        .idle(pack_idle),
        .overflow(pack_error),
        .result_send(result_send),
        .result_busy(result_busy),
        .result_data(result_adc));
    cdc_mailbox #(.WIDTH(69)) u_result_mail(
        .src_clk(adc_clk),
        .src_rst(adc_rst),
        .src_send(result_send),
        .src_data(result_adc),
        .src_busy(result_busy),
        .dst_clk(ui_clk),
        .dst_rst(rst),
        .dst_valid(result_valid),
        .dst_data(result_ui));
    level_sync u_idle(.clk(ui_clk),
        .rst(rst),
        .async_in(pack_idle),
        .sync_out(pack_idle_ui));
    wire error_ui;
    level_sync u_error(.clk(ui_clk),
        .rst(rst),
        .async_in(pack_error),
        .sync_out(error_ui));
    wire fifo_valid=!empty && !rd_rst_busy && !rst;
    adc_fifo_256x512 u_fifo(
        .rst(fifo_reset),
        .wr_clk(adc_clk),
        .rd_clk(ui_clk),
        .din(pack_data),
        .wr_en(pack_valid && pack_ready),
        .rd_en(fifo_valid && writer_ready),
        .dout(fifo_data),
        .full(full),
        .empty(empty),
        .wr_rst_busy(wr_rst_busy),
        .rd_rst_busy(rd_rst_busy));
    localparam IDLE=0, RUN=1, HOLD=2, PREP=3;
    reg [1:0] state;
    reg start_d,arm_d,release_d,writer_clear,have_result;
    reg [68:0] result_q;
    reg overflow_latched;
    wire writer_idle;
    wire start_edge=cmd_start && !start_d;

    wire release_edge=cmd_release && !release_d;
    wire arm_edge=cmd_arm && !arm_d;
    wire options_valid=cfg_samples>=1 && cfg_samples<=MAX_SAMPLES &&
        cfg_pre_percent<=100 && cfg_trigger_type_a<=4 && cfg_trigger_type_b<=4 && (!cfg_auto_mode || cfg_trigger_enable!=0);
    reg launch_settled;
    reg abort_pending;
    reg abort_sent;
    assign trigger_armed=state==RUN && launch_settled && !triggered_ui;
    assign history_ready=trigger_armed && history_ui && !pack_idle_ui && !control_busy && !control_send && !geometry_busy && !geometry_start && !geometry_done;
    assign trigger_seen=state!=IDLE && launch_settled && triggered_ui;

    wire ready_conditions=state==IDLE && cfg_done && init_calib_complete && !rst &&
        !wr_busy_ui && !rd_rst_busy && !full_ui && empty && writer_idle &&
        pack_idle_ui && !start_mail_busy && !writer_clear && !control_busy && !control_send && !geometry_busy && !geometry_start && !geometry_done;
    // Allow reset-busy/full CDC pipelines to settle after FIFO reset release.
    // Also keeps READY low until both record mailboxes have returned to idle.
    reg [5:0] ready_guard;
    always @(posedge ui_clk) begin
        if(rst || !ready_conditions) ready_guard<=0;
        else if(!ready_guard[5]) ready_guard<=ready_guard+1'b1;
    end
    assign ready=ready_conditions && ready_guard[5];
    assign busy=state==RUN || state==PREP;
    assign capture_finished=have_result;
    assign overflow=overflow_latched;
    mig_write_runtime #(.APP_ADDR_WIDTH(APP_ADDR_WIDTH),
        .BASE_APP_ADDR(BASE_APP_ADDR)) u_writer(
        .clk(ui_clk),
        .rst(rst),
        .clear(writer_clear),
        .enable(state==RUN && init_calib_complete),
        .ring_samples(ring_q),
        .s_data(fifo_data),
        .s_valid(fifo_valid),
        .s_ready(writer_ready),
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),
        .app_wdf_end(app_wdf_end),
        .app_wdf_rdy(app_wdf_rdy),
        .idle(writer_idle),
        .submitted_blocks(submitted_blocks));

    always @(posedge ui_clk) begin
        if (rst) begin
            state<=IDLE;
            start_d<=0; arm_d<=0; release_d<=0;
            send_start<=0; writer_clear<=0; geometry_start<=0;
            start_accepted<=0; command_rejected<=0;
            record_done<=0; record_valid<=0;
            have_result<=0; result_q<=0; overflow_latched<=0;
            latched_samples<=0; record_samples<=0; record_bytes<=0;
            percent_q<=0; threshold_a_q<=0; threshold_b_q<=0;
            auto_q<=0; trigger_enable_q<=0; immediate_q<=0; type_a_q<=0; type_b_q<=0;
            control_send<=0; control_data<=0;
            launch_settled<=0; capture_aborted<=0; abort_pending<=0; abort_sent<=0;
            trigger_reason<=0; record_start_sample<=0;
        end else begin
            start_d<=cmd_start; arm_d<=cmd_arm; release_d<=cmd_release;
            send_start<=0; writer_clear<=0; geometry_start<=0; control_send<=0;
            start_accepted<=0; command_rejected<=0;
            if (start_edge || arm_edge || release_edge || cmd_force || cmd_abort)
                command_rejected<=1;
            case (state)
                IDLE: if ((start_edge ^ arm_edge) && !release_edge && !cmd_force &&
                          !cmd_abort && ready && options_valid &&
                          (!start_edge || (!cfg_auto_mode && cfg_pre_percent==0))) begin
                    latched_samples<=cfg_samples; percent_q<=cfg_pre_percent;
                    threshold_a_q<=cfg_threshold_a; threshold_b_q<=cfg_threshold_b;
                    type_a_q<=cfg_trigger_type_a; type_b_q<=cfg_trigger_type_b;
                    auto_q<=cfg_auto_mode; trigger_enable_q<=cfg_trigger_enable;
                    immediate_q<=start_edge;
                    geometry_start<=1; writer_clear<=1;
                    have_result<=0; overflow_latched<=0; launch_settled<=0;
                    record_done<=0; record_valid<=0; record_samples<=0; record_bytes<=0;
                    capture_aborted<=0; abort_pending<=0; abort_sent<=0; trigger_reason<=0; record_start_sample<=0;
                    state<=PREP; start_accepted<=1; command_rejected<=0;
                end
                PREP: begin
                    if (cmd_abort && !cmd_force) begin
                        capture_aborted<=1;
                        command_rejected<=0;
                        state<=IDLE;
                    end else if (geometry_done) begin
                        send_start<=1;
                        state<=RUN;
                    end
                end
                RUN: begin
                    // 接受启动跨域期间的取消请求；等 ADC 确实启动后只发送一次。
                    if (cmd_abort && !cmd_force) begin
                        abort_pending<=1;
                        command_rejected<=0;
                    end
                    if (!start_mail_busy && !pack_idle_ui) launch_settled<=1;
                    if (!pack_idle_ui && launch_settled && error_ui) overflow_latched<=1;
                    if (!control_busy && !control_send && launch_settled && !pack_idle_ui) begin
                        if ((abort_pending || (cmd_abort && !cmd_force)) && !abort_sent) begin
                            control_send<=1; control_data<=2'b10; abort_sent<=1;
                        end else if (cmd_force && !cmd_abort && !abort_pending && !auto_q && history_ready) begin
                            control_send<=1; control_data<=2'b01; command_rejected<=0;
                        end
                    end
                    if (result_valid) begin
                        result_q<=result_ui; have_result<=1;
                        overflow_latched<=result_ui[68];
                    end
                    if (have_result && submitted_blocks==result_q[31:0] && writer_idle && empty) begin
                        capture_aborted<=result_q[67] || abort_pending || cmd_abort;
                        trigger_reason<=result_q[66:64];
                        record_start_sample<=result_q[63:32];
                        if (result_q[67] || abort_pending || cmd_abort) begin
                            state<=IDLE;
                            writer_clear<=1;
                        end else begin
                            record_done<=1;
                            record_valid<=!result_q[68];
                            record_samples<=result_q[68] ? 0 : latched_samples;
                            record_bytes<=result_q[68] ? 0 : (latched_samples<<2);
                            state<=HOLD;
                        end
                    end
                end
                HOLD: if (release_edge && !start_edge && !arm_edge) begin
                    state<=IDLE; writer_clear<=1; record_done<=0; record_valid<=0;
                    have_result<=0; record_samples<=0; record_bytes<=0; overflow_latched<=0;
                    launch_settled<=0; command_rejected<=0;
                end
                default: state<=IDLE;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if(MAX_SAMPLES<1 || MAX_SAMPLES>20000000 || BASE_APP_ADDR%8!=0)
            $fatal(1,"Invalid maximum size or unaligned base address");
        if(({1'b0,BASE_APP_ADDR} + (((MAX_SAMPLES+7)/8+1)*64'd8)-1) >> APP_ADDR_WIDTH)
            $fatal(1,"MIG address range wraps");
    end
    // synthesis translate_on
endmodule
`default_nettype wire
