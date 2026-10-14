`timescale 1ns/1ps
`default_nettype none
// ADC 域打包及当前码值比较；每个 32 位样本对低半字 A、高半字 B；没有边沿触发判断。
// 接口协议与边界条件见同目录 ads62p24_pack_runtime_spec.md。
module ads62p24_pack_runtime (
    input wire adc_clk,
    input wire rst,
    input wire start,
    input wire [31:0] sample_limit,
    input wire [31:0] pre_samples,
    input wire [31:0] ring_samples,
    input wire [11:0] threshold_a,
    input wire [11:0] threshold_b,
    input wire [2:0] trigger_type_a, // 0：>=；1：>；2：==；3：<=；4：<。
    input wire [2:0] trigger_type_b,
    input wire auto_mode,
    input wire [1:0] trigger_enable,
    input wire immediate,
    input wire force_trigger,
    input wire abort_capture,
    input wire [11:0] adc_a,
    input wire [11:0] adc_b,
    output reg [255:0] out_data,
    output reg out_valid,
    input wire out_ready,
    output reg idle,
    output reg overflow,
    output wire history_ready, // 前触发历史已足够，手动模式可发送 FORCE。
    output reg triggered,
    output reg result_send,
    input wire result_busy,
    output wire [68:0] result_data
);
    (* IOB="TRUE" *) reg [11:0] adc_a_q;
    (* IOB="TRUE" *) reg [11:0] adc_b_q;
    wire [11:0] adc_a_corrected = ~adc_a_q;
    wire [11:0] adc_b_corrected = ~adc_b_q;
    always @(posedge adc_clk) begin
        adc_a_q <= adc_a;
        adc_b_q <= adc_b;
    end
    adc_raw_ila u_adc_raw_ila (
        .clk(adc_clk),
        .probe0(adc_a_q),
        .probe1(adc_b_q),
        .probe2(adc_a_corrected),
        .probe3(adc_b_corrected),
        .probe4(rst),
        .probe5(start)
    );

    localparam IDLE=0, CAPTURE=1, FLUSH=2, REPORT=3, WAIT_BUSY=4, WAIT_ACK=5;
    reg [2:0] state;
    reg [2:0] pack_index;
    reg [255:0] pack_data;
    reg [255:0] next_pack;
    reg [31:0] pre_q;
    reg [31:0] ring_q;
    reg [31:0] post_q;
    reg [31:0] post_left;
    reg [31:0] history_count;
    reg [31:0] position;
    reg [31:0] record_start;
    reg [31:0] blocks;
    reg [11:0] threshold_a_q;
    reg [11:0] threshold_b_q;
    reg [2:0] type_a_q;
    reg [2:0] type_b_q;
    reg auto_q;
    reg [1:0] enable_q;
    reg immediate_q;
    reg aborted;
    reg [2:0] reason;
    wire slot_available = !out_valid || out_ready;
    // 只比较当前校正码值，不检查前一个采样点，也不要求产生跳变。
    function level_matches;
        input [11:0] sample_code;
        input [11:0] threshold_code;
        input [2:0] comparison;
        begin
            case (comparison)
                3'd0: level_matches = sample_code >= threshold_code;
                3'd1: level_matches = sample_code >  threshold_code;
                3'd2: level_matches = sample_code == threshold_code;
                3'd3: level_matches = sample_code <= threshold_code;
                3'd4: level_matches = sample_code <  threshold_code;
                default: level_matches = 1'b0; // 保留编码不触发；UI 同时拒绝非法配置。
            endcase
        end
    endfunction
    wire hit_a = enable_q[0] && level_matches(adc_a_corrected, threshold_a_q, type_a_q);
    wire hit_b = enable_q[1] && level_matches(adc_b_corrected, threshold_b_q, type_b_q);
    wire manual_hit = !auto_q && (force_trigger || immediate_q);
    wire trigger_now = history_ready && !triggered &&
                       (manual_hit || (auto_q && (hit_a || hit_b)));
    wire take_sample = state == CAPTURE && !abort_capture &&
                       !(trigger_now && post_q == 0);
    assign history_ready = state == CAPTURE && !triggered && history_count >= pre_q;
    assign result_data = {overflow, aborted, reason, record_start, blocks};

    always @(*) begin
        next_pack = pack_data;
        next_pack[pack_index*32 +: 32] = {4'b0, adc_b_corrected, 4'b0, adc_a_corrected};
    end

    always @(posedge adc_clk) begin
        if (rst) begin
            state <= IDLE;
            idle <= 1;
            overflow <= 0;
            triggered <= 0;
            result_send <= 0;
            out_valid <= 0;
            out_data <= 0;
            pack_data <= 0;
            pack_index <= 0;
            pre_q <= 0;
            ring_q <= 8;
            post_q <= 0;
            post_left <= 0;
            history_count <= 0;
            position <= 0;
            record_start <= 0;
            blocks <= 0;
            threshold_a_q <= 0;
            threshold_b_q <= 0;
            type_a_q <= 0;
            type_b_q <= 0;
            auto_q <= 0;
            enable_q <= 0;
            immediate_q <= 0;
            aborted <= 0;
            reason <= 0;
        end else begin
            result_send <= 0;
            if (out_valid && out_ready) begin
                out_valid <= 0;
                blocks <= blocks + 1'b1; // 与 MIG 提交计数采用相同模 2^32 计数。
            end
            case (state)
                IDLE: if (start) begin
                    pre_q <= pre_samples;
                    ring_q <= ring_samples;
                    post_q <= sample_limit - pre_samples;
                    threshold_a_q <= threshold_a;
                    threshold_b_q <= threshold_b;
                    type_a_q <= trigger_type_a;
                    type_b_q <= trigger_type_b;
                    auto_q <= auto_mode;
                    enable_q <= trigger_enable;
                    immediate_q <= immediate;
                    post_left <= 0;
                    history_count <= 0;
                    position <= 0;
                    record_start <= 0;
                    blocks <= 0;
                    pack_index <= 0;
                    pack_data <= 0;
                    overflow <= 0;
                    aborted <= 0;
                    reason <= 0;
                    triggered <= 0;
                    idle <= 0;
                    state <= CAPTURE;
                end
                CAPTURE: begin
                    if (abort_capture) begin
                        aborted <= 1;
                        pack_index <= 0; // 取消的记录无效，不再提交部分末拍。
                        state <= FLUSH;
                    end else begin
                        if (trigger_now) begin
                            triggered <= 1;
                            immediate_q <= 0;
                            reason <= manual_hit ? 3'b100 : {1'b0, hit_b, hit_a};
                            if (position >= pre_q)
                                record_start <= position - pre_q;
                            else
                                record_start <= position + ring_q - pre_q;
                            post_left <= post_q == 0 ? 0 : post_q - 1'b1;
                            if (post_q <= 1) state <= FLUSH;
                        end else if (triggered) begin
                            post_left <= post_left - 1'b1;
                            if (post_left == 1) state <= FLUSH;
                        end
                        if (take_sample) begin
                            if (history_count < pre_q) history_count <= history_count + 1'b1;
                            if (position == ring_q - 1'b1) position <= 0;
                            else position <= position + 1'b1;
                            if (pack_index == 7) begin
                                if (slot_available) begin
                                    out_data <= next_pack;
                                    out_valid <= 1;
                                    pack_index <= 0;
                                    pack_data <= 0;
                                end else begin
                                    overflow <= 1; // ADC 不可反压；缺失样本使整条记录无效。
                                    pack_index <= 0;
                                    state <= FLUSH;
                                end
                            end else begin
                                pack_data <= next_pack;
                                pack_index <= pack_index + 1'b1;
                            end
                        end
                    end
                end
                FLUSH: begin
                    if (pack_index != 0 && slot_available) begin
                        out_data <= pack_data; // 未使用的高位保持为零，读回时按有效点数截断。
                        out_valid <= 1;
                        pack_index <= 0;
                    end else if (pack_index == 0 && !out_valid) state <= REPORT;
                end
                REPORT: if (!result_busy) begin
                    result_send <= 1;
                    state <= WAIT_BUSY;
                end
                WAIT_BUSY: if (result_busy) state <= WAIT_ACK;
                WAIT_ACK: if (!result_busy) begin
                    idle <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire

