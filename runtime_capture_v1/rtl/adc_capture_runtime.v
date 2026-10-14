`timescale 1ns/1ps
`default_nettype none
// Command/status domain is MIG ui_clk (100 MHz for the supplied board MIG).
// cmd_start/cmd_release are rising-edge commands, synchronous to ui_clk.
// Future FMC bridge must handshake its commands into this domain.
// record_done = all commands/payloads accepted; NOT a physical DDR write ACK.
module adc_capture_runtime #(
    parameter integer MAX_SAMPLES=20000000,
    parameter integer APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0,
    parameter integer TEST_RAMP=0,
    parameter integer CFG_POWER_WAIT=100000,
    parameter integer CFG_RESET_HIGH=100,
    parameter integer CFG_RESET_WAIT=100,
    parameter integer CFG_SETTLE=10000
)(
    input wire ui_clk, ui_rst, global_rst, init_calib_complete,
    input wire adc_clk_out, input wire [13:2] adc_da, adc_db,
    output wire adc_reset, adc_cs_n, adc_sck, adc_sdi, output wire [2:0] adc_ctrl,
    input wire [31:0] cfg_samples, input wire cmd_start, cmd_release,
    output wire ready, busy, cfg_done,
    output reg start_accepted, command_rejected,
    output reg record_done, record_valid,
    output wire capture_finished, overflow,
    output reg [31:0] record_samples, record_bytes,
    output reg [31:0] latched_samples,
    output wire [31:0] submitted_blocks,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire [2:0] app_cmd, output wire app_en, input wire app_rdy,
    output wire [255:0] app_wdf_data, output wire [31:0] app_wdf_mask,
    output wire app_wdf_wren, app_wdf_end, input wire app_wdf_rdy
);
    wire rst, adc_clk, adc_rst;
    reset_sync u_ui_reset(.clk(ui_clk),.arst(global_rst|ui_rst),.rst(rst));
    BUFG u_adc_bufg(.I(adc_clk_out),.O(adc_clk));
    ads62p24_init #(.TEST_RAMP(TEST_RAMP),.POWER_WAIT_CYCLES(CFG_POWER_WAIT),
        .RESET_HIGH_CYCLES(CFG_RESET_HIGH),.RESET_WAIT_CYCLES(CFG_RESET_WAIT),
        .SETTLE_CYCLES(CFG_SETTLE)) u_init(
        .clk(ui_clk),.rst(rst),.adc_reset(adc_reset),.adc_cs_n(adc_cs_n),
        .adc_sck(adc_sck),.adc_sdi(adc_sdi),.adc_ctrl(adc_ctrl),.done(cfg_done));
    wire fifo_reset = global_rst | ui_rst | rst | !cfg_done;
    reset_sync u_adc_reset(.clk(adc_clk),.arst(fifo_reset),.rst(adc_rst));
    wire full,empty,wr_rst_busy,rd_rst_busy;
    wire wr_busy_ui, full_ui, pack_idle_ui;
    level_sync #(.RESET_VALUE(1'b1)) u_wbusy(.clk(ui_clk),.rst(rst),.async_in(wr_rst_busy),.sync_out(wr_busy_ui));
    level_sync #(.RESET_VALUE(1'b1)) u_full(.clk(ui_clk),.rst(rst),.async_in(full),.sync_out(full_ui));
    reg send_start;
    wire start_mail_busy, start_adc;
    wire [31:0] samples_adc;
    cdc_mailbox #(.WIDTH(32)) u_start_mail(
        .src_clk(ui_clk),.src_rst(rst),.src_send(send_start),.src_data(latched_samples),.src_busy(start_mail_busy),
        .dst_clk(adc_clk),.dst_rst(adc_rst),.dst_valid(start_adc),.dst_data(samples_adc));
    wire pack_idle, pack_error, result_send, result_busy, result_valid;
    wire [64:0] result_adc, result_ui;
    wire [255:0] pack_data, fifo_data;
    wire pack_valid, writer_ready;
    wire pack_ready=!full && !wr_rst_busy && !adc_rst;
    ads62p24_pack_runtime u_pack(
        .adc_clk(adc_clk),.rst(adc_rst),.start(start_adc),.sample_limit(samples_adc),
        .adc_a(adc_da),.adc_b(adc_db),.out_data(pack_data),.out_valid(pack_valid),.out_ready(pack_ready),
        .idle(pack_idle),.overflow(pack_error),.result_send(result_send),.result_busy(result_busy),.result_data(result_adc));
    cdc_mailbox #(.WIDTH(65)) u_result_mail(
        .src_clk(adc_clk),.src_rst(adc_rst),.src_send(result_send),.src_data(result_adc),.src_busy(result_busy),
        .dst_clk(ui_clk),.dst_rst(rst),.dst_valid(result_valid),.dst_data(result_ui));
    level_sync u_idle(.clk(ui_clk),.rst(rst),.async_in(pack_idle),.sync_out(pack_idle_ui));
    wire error_ui;
    level_sync u_error(.clk(ui_clk),.rst(rst),.async_in(pack_error),.sync_out(error_ui));
    wire fifo_valid=!empty && !rd_rst_busy && !rst;
    adc_fifo_256x512 u_fifo(
        .rst(fifo_reset),.wr_clk(adc_clk),.rd_clk(ui_clk),
        .din(pack_data),.wr_en(pack_valid && pack_ready),.rd_en(fifo_valid && writer_ready),
        .dout(fifo_data),.full(full),.empty(empty),.wr_rst_busy(wr_rst_busy),.rd_rst_busy(rd_rst_busy));
    localparam IDLE=0, RUN=1, HOLD=2;
    reg [1:0] state;
    reg start_d,release_d,writer_clear,have_result;
    reg [64:0] result_q;
    reg overflow_latched;
    wire writer_idle;
    wire start_edge=cmd_start && !start_d;
    wire release_edge=cmd_release && !release_d;
    wire ready_conditions=state==IDLE && cfg_done && init_calib_complete && !rst &&
        !wr_busy_ui && !rd_rst_busy && !full_ui && empty && writer_idle &&
        pack_idle_ui && !start_mail_busy && !writer_clear;
    // Allow reset-busy/full CDC pipelines to settle after FIFO reset release.
    // Also keeps READY low until both record mailboxes have returned to idle.
    reg [5:0] ready_guard;
    always @(posedge ui_clk) begin
        if(rst || !ready_conditions) ready_guard<=0;
        else if(!ready_guard[5]) ready_guard<=ready_guard+1'b1;
    end
    assign ready=ready_conditions && ready_guard[5];
    assign busy=state==RUN;
    assign capture_finished=have_result;
    assign overflow=overflow_latched;
    mig_write_runtime #(.APP_ADDR_WIDTH(APP_ADDR_WIDTH),.BASE_APP_ADDR(BASE_APP_ADDR)) u_writer(
        .clk(ui_clk),.rst(rst),.clear(writer_clear),.enable(state==RUN && init_calib_complete),
        .s_data(fifo_data),.s_valid(fifo_valid),.s_ready(writer_ready),
        .app_addr(app_addr),.app_cmd(app_cmd),.app_en(app_en),.app_rdy(app_rdy),
        .app_wdf_data(app_wdf_data),.app_wdf_mask(app_wdf_mask),
        .app_wdf_wren(app_wdf_wren),.app_wdf_end(app_wdf_end),.app_wdf_rdy(app_wdf_rdy),
        .idle(writer_idle),.submitted_blocks(submitted_blocks));
    always @(posedge ui_clk) begin
        if(rst) begin
            state<=IDLE; start_d<=0; release_d<=0; send_start<=0; writer_clear<=0;
            start_accepted<=0; command_rejected<=0; record_done<=0; record_valid<=0;
            have_result<=0; result_q<=0; overflow_latched<=0;
            latched_samples<=0; record_samples<=0; record_bytes<=0;
        end else begin
            start_d<=cmd_start; release_d<=cmd_release;
            send_start<=0; writer_clear<=0; start_accepted<=0; command_rejected<=0;
            if(start_edge || release_edge) command_rejected<=1;
            case(state)
                IDLE: if(start_edge && !release_edge && ready && cfg_samples>=1 && cfg_samples<=MAX_SAMPLES) begin
                    latched_samples<=cfg_samples; send_start<=1; writer_clear<=1;
                    have_result<=0; result_q<=0; overflow_latched<=0;
                    record_done<=0; record_valid<=0; record_samples<=0; record_bytes<=0;
                    state<=RUN; start_accepted<=1; command_rejected<=0;
                end
                RUN: begin
                    // pack_error can be stale until the next ADC start is received.
                    if(!pack_idle_ui && !start_mail_busy && error_ui) overflow_latched<=1;
                    if(result_valid) begin
                        result_q<=result_ui; have_result<=1;
                        overflow_latched<=result_ui[64];
                    end
                    if(have_result && submitted_blocks==result_q[63:32] && writer_idle && empty) begin
                        record_done<=1; record_samples<=result_q[31:0];
                        record_valid<=!result_q[64] && result_q[31:0]==latched_samples;
                        record_bytes<=(!result_q[64] && result_q[31:0]==latched_samples) ? (result_q[31:0]<<2) : 0;
                        state<=HOLD;
                    end
                end
                HOLD: if(release_edge && !start_edge) begin
                    state<=IDLE; writer_clear<=1; record_done<=0; record_valid<=0;
                    have_result<=0; record_samples<=0; record_bytes<=0; overflow_latched<=0;
                    command_rejected<=0;
                end
                default: state<=IDLE;
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if(MAX_SAMPLES<1 || MAX_SAMPLES>20000000 || BASE_APP_ADDR%8!=0)
            $fatal(1,"Invalid maximum size or unaligned base address");
        if(({1'b0,BASE_APP_ADDR} + ((MAX_SAMPLES+7)/8-1)*64'd8) >> APP_ADDR_WIDTH)
            $fatal(1,"MIG address range wraps");
    end
    // synthesis translate_on
endmodule
`default_nettype wire
