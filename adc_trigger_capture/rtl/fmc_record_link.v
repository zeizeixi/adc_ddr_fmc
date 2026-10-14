`timescale 1ns/1ps
`default_nettype none
// FMC V2 寄存器及跨域命令桥；配置/采集命令有序进入 UI 域，ACK 留在缓存读时钟域。
// 接口协议与边界条件见同目录 fmc_record_link_spec.md。
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
    input wire reads_idle, // FMC 返回流水线为空；ACK 必须等待读操作结束。
    input wire mode_valid,
    input wire protocol_error,
    output wire clear_error,
    output wire [31:0] cfg_samples, // 下一次记录的 A/B 总对数；不是单通道半字数。
    output reg [6:0] cfg_pre_percent, // 前触发比例 0～100；ARM/START 接受时锁存。
    output reg [2:0] cfg_trigger_type_a, // A 路比较：0 >=、1 >、2 ==、3 <=、4 <。
    output reg [2:0] cfg_trigger_type_b, // B 路比较：0 >=、1 >、2 ==、3 <=、4 <。
    output reg cfg_auto_mode, // 0 手动 FORCE；1 自动等待比较条件，不设超时。
    output reg [1:0] cfg_trigger_enable, // bit0 电压 A，bit1 电流 B；已使能条件按 OR 组合。
    output reg [11:0] cfg_threshold_a, // A 路校正后 ADC 阈值码，0～4095。
    output reg [11:0] cfg_threshold_b, // B 路校正后 ADC 阈值码，0～4095。
    output reg cmd_arm, // 锁存配置并建立前触发历史。
    output reg cmd_force, // 手动触发命令；前触发历史就绪后才能接受。
    output reg cmd_abort, // 取消准备、等待或采集；排空已提交数据后回到 READY。
    input wire trigger_armed, // ADC 已进入本次采样且尚未触发。
    input wire history_ready, // 前触发历史已足够，手动模式可发送 FORCE。
    input wire trigger_seen, // 本次触发已发生；不等于 DDR 写入已排空。
    input wire capture_aborted, // 本次已取消；下次接受采集时清除。
    input wire [2:0] trigger_reason, // DONE 后有效：bit0 电压、bit1 电流、bit2 手动。
    input wire [31:0] record_pre_samples, // 本次前触发样本对数；100% 前触发时等于 N。
    output wire cmd_start,
    output wire cmd_release,
    output wire cmd_read_next,
    output wire cmd_ack,
    output wire rd_en,
    output wire [11:0] rd_addr, // 8 KiB 缓存的 16 位字地址，0～4095。
    input wire ready,
    input wire busy,
    input wire done,
    input wire valid,
    input wire overflow,
    input wire cfg_done,
    input wire calib,
    input wire read_ready, // 可请求下一块；没有当前块占用且还有剩余记录。
    input wire read_idle,
    input wire stream_done, // 最后一块 ACK 已返回 UI 域。
    input wire read_error,
    input wire block_ready,
    input wire block_last, // 仅 BLOCK_READY 时解释为当前块是否末块。
    input wire accepted,
    input wire rejected,
    input wire read_accepted,
    input wire ack_accepted,
    input wire ack_rejected,
    input wire rd_rejected,
    input wire [31:0] record_samples,
    input wire [31:0] record_bytes, // 有效记录字节数；每对 A/B 占 4 字节。
    input wire [31:0] blocks,
    input wire [31:0] block_index, // 当前读块序号，从 0 开始。
    input wire [31:0] block_offset, // 当前块在逻辑记录中的字节偏移。
    input wire [13:0] block_bytes // 当前读块有效字节数，最大 8192。
);
    reg [31:0] samples_ui;
    reg [31:0] samples_fmc;
    reg [6:0] percent_fmc;
    reg [2:0] type_a_fmc;
    reg [2:0] type_b_fmc;
    reg auto_fmc;
    reg [1:0] enable_fmc;
    reg [11:0] threshold_a_fmc;
    reg [11:0] threshold_b_fmc;
    reg length_mode_fmc;
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
    wire command_known = bus_wdata >= 1 && bus_wdata <= 8;
    wire duration_write = bus_addr == 24'h000008 && bus_mask == 0 && bus_wdata >= 1 && bus_wdata <= 200;
    wire queued_command = command_address && bus_mask == 0 && command_known && bus_wdata != 3;

    wire extension_address = (bus_addr>=24'h000028 && bus_addr<=24'h000034 && !bus_addr[0]) ||
                             bus_addr==24'h000042 || bus_addr==24'h000044;
    wire extension_value_ok =
        (bus_addr==24'h000028 || bus_addr==24'h00002a) ||
        (bus_addr==24'h00002c && bus_wdata<=100) ||
        (bus_addr==24'h00002e && bus_wdata<=1) ||
        ((bus_addr==24'h000030 || bus_addr==24'h000032) && bus_wdata<=4095) ||
        (bus_addr==24'h000034 && bus_wdata<=3) ||
        ((bus_addr==24'h000042 || bus_addr==24'h000044) && bus_wdata<=4);
    wire extension_write=extension_address && bus_mask==0 && extension_value_ok;
    wire enqueue = bus_write && (duration_write || queued_command || extension_write);
    wire enqueue_ready = !fifo_full && !fifo_write_busy && !fmc_rst;
    wire write_fifo = enqueue && enqueue_ready;
    wire ack_write = bus_write && command_address && bus_mask == 0 && bus_wdata == 3;
    wire clear_write = write_fifo && command_address && bus_wdata == 5;
    wire window_address = bus_addr >= 24'h002000 && bus_addr < 24'h004000;
    wire block_available = block_ready && !ack_lock;
    wire word_in_block = {1'b0, bus_addr[12:0]} < block_bytes;
    wire [255:0] snapshot_data;
    wire snapshot_busy;
    wire snapshot_valid;
    wire [15:0] ui_flags = {1'b0, read_idle, 2'b00, read_error, stream_done,
        2'b00, read_ready, calib, cfg_done, overflow, valid, done, busy, ready};
    wire [15:0] trigger_flags={8'b0,trigger_reason,capture_aborted,
        (busy && trigger_seen),trigger_seen,history_ready,trigger_armed};
    wire [255:0] snapshot_source = {64'b0,record_pre_samples,trigger_flags,16'b0,11'b0, clear_epoch_ui, local_error_ui, events_ui,
        ui_flags, blocks, record_bytes, record_samples};
    wire epoch_matches = snapshot_data[116] == clear_epoch_fmc;
    wire [15:0] status = {2'b00, mode_valid,
        (protocol_error || local_error_fmc || (epoch_matches && snapshot_data[115])),
        snapshot_data[107], snapshot_data[106], block_last, block_available,
        (snapshot_data[103] && !block_ready && !ack_lock), snapshot_data[102:96]};
    wire [6:0] events = {local_error_fmc || (epoch_matches && snapshot_data[115]),
        1'b0, events_ack, (epoch_matches ? snapshot_data[114:112] : 3'b000)};

    assign cfg_samples = samples_ui;
    assign cmd_start = cmd_start_o;
    assign cmd_release = cmd_release_o;
    assign cmd_read_next = cmd_read_next_o;
    assign cmd_ack = cmd_ack_o;
    assign clear_error = clear_write;
    assign memory_selected = window_address && block_available && word_in_block;
    assign rd_en = bus_read && memory_selected && !fmc_rst;
    assign rd_addr = bus_addr[12:1];

    xpm_fifo_async #(
        .CDC_SYNC_STAGES(3),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(16),
        .FULL_RESET_VALUE(1),
        .PROG_EMPTY_THRESH(5),
        .PROG_FULL_THRESH(10),
        .RD_DATA_COUNT_WIDTH(5),
        .READ_DATA_WIDTH(42),
        .READ_MODE("fwft"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(1),
        .USE_ADV_FEATURES("0000"),
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(42),
        .WR_DATA_COUNT_WIDTH(5)
    ) u_commands (
        .rst(fmc_rst),
        .wr_clk(fmc_clk),
        .rd_clk(ui_clk),
        .din({bus_addr, bus_wdata, bus_mask}),
        .wr_en(write_fifo),
        .rd_en(fifo_read),
        .dout(fifo_data),
        .full(fifo_full),
        .empty(fifo_empty),
        .wr_rst_busy(fifo_write_busy),
        .rd_rst_busy(fifo_read_busy),
        .overflow(fifo_overflow),
        .underflow(fifo_underflow),
        .sleep(1'b0),
        .injectdbiterr(1'b0),
        .injectsbiterr(1'b0),
        .almost_empty(),
        .almost_full(),
        .data_valid(),
        .dbiterr(),
        .sbiterr(),
        .prog_empty(),
        .prog_full(),
        .rd_data_count(),
        .wr_data_count(),
        .wr_ack()
    );

    cdc_mailbox #(.WIDTH(256)) u_status_mail (
        .src_clk(ui_clk),
        .src_rst(ui_rst),
        .src_send(!snapshot_busy),
        .src_data(snapshot_source),
        .src_busy(snapshot_busy),
        .dst_clk(fmc_clk),
        .dst_rst(fmc_rst),
        .dst_valid(snapshot_valid),
        .dst_data(snapshot_data)
    );

    // All metadata from UI arrives as one coherent, acknowledged image.
    always @(*) begin
        register_data = 16'hffff;
        if (window_address) register_data = 16'hdead;
        else begin
            case (bus_addr)
                24'h000000: register_data = 16'hadfc;
                24'h000002: register_data = 16'h0200;
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
                24'h000028: register_data = samples_fmc[15:0];
                24'h00002a: register_data = samples_fmc[31:16];
                24'h00002c: register_data = {9'b0,percent_fmc};
                24'h00002e: register_data = {15'b0,auto_fmc};
                24'h000030: register_data = {4'b0,threshold_a_fmc};
                24'h000032: register_data = {4'b0,threshold_b_fmc};
                24'h000034: register_data = {14'b0,enable_fmc};
                24'h000036: register_data = snapshot_data[159:144];
                24'h000038: register_data = snapshot_data[175:160];
                24'h00003a: register_data = snapshot_data[191:176];
                24'h00003c: register_data = 16'he100; // 100000000 Hz low
                24'h00003e: register_data = 16'h05f5; // 100000000 Hz high
                24'h000040: register_data = {15'b0,length_mode_fmc};
                24'h000042: register_data = {13'b0,type_a_fmc};
                24'h000044: register_data = {13'b0,type_b_fmc};
                default: register_data = 16'hffff;
            endcase
        end
    end

    always @(posedge fmc_clk or posedge fmc_rst) begin
        if (fmc_rst) begin
            duration_fmc <= 1;
            samples_fmc <= 100000;
            percent_fmc <= 0;
            auto_fmc <= 0;
            type_a_fmc <= 0;
            type_b_fmc <= 0;
            enable_fmc <= 3;
            threshold_a_fmc <= 4095;
            threshold_b_fmc <= 4095;
            length_mode_fmc <= 0;
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
                    if (duration_write && enqueue_ready) begin
                        duration_fmc <= bus_wdata;
                        samples_fmc <= bus_wdata * 32'd100000;
                        length_mode_fmc <= 0;
                    end
                    else local_error_fmc <= 1;
                end else if (extension_address) begin
                    if (extension_write && enqueue_ready) begin
                        case(bus_addr)
                            24'h000028: begin samples_fmc[15:0]<=bus_wdata; length_mode_fmc<=1; duration_fmc<=0; end
                            24'h00002a: begin samples_fmc[31:16]<=bus_wdata; length_mode_fmc<=1; duration_fmc<=0; end
                            24'h00002c: percent_fmc<=bus_wdata[6:0];
                            24'h00002e: auto_fmc<=bus_wdata[0];
                            24'h000030: threshold_a_fmc<=bus_wdata[11:0];
                            24'h000032: threshold_b_fmc<=bus_wdata[11:0];
                            24'h000034: enable_fmc<=bus_wdata[1:0];
                            24'h000042: type_a_fmc<=bus_wdata[2:0];
                            24'h000044: type_b_fmc<=bus_wdata[2:0];
                        endcase
                    end else local_error_fmc<=1;
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
            samples_ui <= 100000;
            cfg_pre_percent <= 0;
            cfg_auto_mode <= 0;
            cfg_trigger_type_a <= 0;
            cfg_trigger_type_b <= 0;
            cfg_trigger_enable <= 3;
            cfg_threshold_a <= 4095;
            cfg_threshold_b <= 4095;
            cmd_arm <= 0;
            cmd_force <= 0;
            cmd_abort <= 0;
            events_ui <= 0;
            local_error_ui <= 0;
            clear_epoch_ui <= 0;
            write_gap <= 0;
            cmd_start_o <= 0;
            cmd_release_o <= 0;
            cmd_read_next_o <= 0;
            cmd_arm <= 0; cmd_force <= 0; cmd_abort <= 0;
        end else begin
            write_gap <= fifo_read;
            cmd_start_o <= 0;
            cmd_release_o <= 0;
            cmd_read_next_o <= 0;
            cmd_arm <= 0; cmd_force <= 0; cmd_abort <= 0;
            events_ui <= events_ui | {read_accepted, rejected, accepted};
            if (fifo_read) begin
                if (queued_addr == 24'h000008) samples_ui <= queued_data * 32'd100000;
                else if (queued_addr==24'h000028) samples_ui[15:0]<=queued_data;
                else if (queued_addr==24'h00002a) samples_ui[31:16]<=queued_data;
                else if (queued_addr==24'h00002c) cfg_pre_percent<=queued_data[6:0];
                else if (queued_addr==24'h00002e) cfg_auto_mode<=queued_data[0];
                else if (queued_addr==24'h000030) cfg_threshold_a<=queued_data[11:0];
                else if (queued_addr==24'h000032) cfg_threshold_b<=queued_data[11:0];
                else if (queued_addr==24'h000034) cfg_trigger_enable<=queued_data[1:0];
                else if (queued_addr==24'h000042) cfg_trigger_type_a<=queued_data[2:0];
                else if (queued_addr==24'h000044) cfg_trigger_type_b<=queued_data[2:0];
                else if (queued_addr == 24'h00000a && queued_mask == 0) begin
                    case (queued_data)
                        16'd1: begin
                            if (ready && read_idle && !cfg_auto_mode && cfg_pre_percent==0) cmd_start_o <= 1;
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
                        16'd6: begin
                            if (ready && read_idle) cmd_arm<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        16'd7: begin
                            if (trigger_armed && history_ready) cmd_force<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        16'd8: begin
                            if (busy) cmd_abort<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        default: local_error_ui <= 1;
                    endcase
                end else local_error_ui <= 1;
            end
        end
    end
endmodule
`default_nettype wire
