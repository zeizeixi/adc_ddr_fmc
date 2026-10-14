`timescale 1ns/1ps
`default_nettype none
// 计算 P=floor(N×前触发百分比/100)，32 周期迭代除法；环形区额外保留一拍补零空间。
// 接口协议与边界条件见同目录 trigger_geometry_spec.md。
module trigger_geometry (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [31:0] samples,
    input wire [6:0] percent,
    output reg busy,
    output reg done,
    output reg [31:0] pre_samples,
    output reg [31:0] ring_samples
);
    reg [31:0] quotient;
    reg [7:0] remainder;
    reg [5:0] steps;
    wire [8:0] shifted = {remainder, quotient[31]};
    always @(posedge clk) begin
        if (rst) begin
            busy <= 0;
            done <= 0;
            pre_samples <= 0;
            ring_samples <= 0;
            quotient <= 0;
            remainder <= 0;
            steps <= 0;
        end else begin
            done <= 0;
            if (start && !busy) begin
                quotient <= samples * percent; // 最大 20000000*100，可放入 32 位。
                remainder <= 0;
                steps <= 32;
                ring_samples <= (((samples + 7) >> 3) + 1) << 3; // 多留一拍，末拍补零不能覆盖有效历史。
                busy <= 1;
            end else if (busy) begin
                if (shifted >= 100) begin
                    remainder <= shifted - 100;
                    quotient <= {quotient[30:0], 1'b1};
                end else begin
                    remainder <= shifted[7:0];
                    quotient <= {quotient[30:0], 1'b0};
                end
                steps <= steps - 1'b1;
                if (steps == 1) begin
                    pre_samples <= {quotient[30:0], (shifted >= 100)};
                    busy <= 0;
                    done <= 1;
                end
            end
        end
    end
endmodule
`default_nettype wire

