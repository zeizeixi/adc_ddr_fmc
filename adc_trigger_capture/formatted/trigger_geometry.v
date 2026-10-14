`timescale 1ns/1ps
`default_nettype none

////////////////////////////////////English///////////////////////////////////////
// Company:         
// Engineer:        
//
// Create Date:     2026/10/12 17:27:14
// Design Name:     trigger_geometry
// Module Name:     trigger_geometry
// Description:     description/trigger_geometry_Design.pdf
// Simulations:     testbench/vivado/2021.1/trigger_geometry
//
// Referrences:     None
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/12 17:27:14
// History:
// Time             Version     Revised by        Contents
// 2026/10/12       V1.0                          Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        
// 开发人员:        
//
// 创建日期:        2026年10月12日
// 设计名称:        trigger_geometry
// 模块名称:        trigger_geometry
// 模块说明:        Description/trigger_geometry_Design.pdf
// 仿真工程:        TestBench/Vivado/2021.1/trigger_geometry
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

module trigger_geometry
(
    //-----------------全局信号-----------------//
    input i_clk,                                // port signal
    input i_rst,                                // port signal

    //-----------------用户接口-----------------//
    input i_start,                              // port signal
    input [31:0]i_samples,                      // port signal
    input [6:0]i_percent,                       // port signal
    output o_busy,                              // port signal
    output o_done,                              // port signal
    output [31:0]o_pre_samples,                 // port signal
    output [31:0]o_ring_samples                 // port signal
);

    //----------------寄存器信号----------------//
    reg [31:0]reg_quotient = 0;                 // signal
    reg [7:0]reg_remainder = 0;                 // signal
    reg [5:0]reg_steps = 0;                     // signal

    //-----------------其他信号-----------------//
    wire [8:0]shifted = {reg_remainder, reg_quotient[31]}; // signal

    //-----------------输出信号-----------------//
    //用户接口
    reg busy_o = 0;                             // internal output signal
    reg done_o = 0;                             // internal output signal
    reg [31:0]pre_samples_o = 0;                // internal output signal
    reg [31:0]ring_samples_o = 0;               // internal output signal

    //---------------输出信号连线---------------//
    //用户接口
    assign o_busy = busy_o;                     // output bridge
    assign o_done = done_o;                     // output bridge
    assign o_pre_samples = pre_samples_o;       // output bridge
    assign o_ring_samples = ring_samples_o;     // output bridge

    //-------------输出信号处理区域-------------//
    //用户接口
    always@(posedge i_clk)begin
        if(i_rst == 1'b1)begin
            busy_o <= 0;
            done_o <= 0;
            pre_samples_o <= 0;
            ring_samples_o <= 0;
            reg_quotient <= 0;
            reg_remainder <= 0;
            reg_steps <= 0;
        end else begin
            done_o <= 0;
            if(i_start == 1'b1 && busy_o == 1'b0)begin
                reg_quotient <= i_samples * i_percent; // 最大 20000000*100，可放入 32 位。
                reg_remainder <= 0;
                reg_steps <= 32;
                ring_samples_o <= (((i_samples + 7) >> 3) + 1) << 3; // 多留一拍，末拍补零不能覆盖有效历史。
                busy_o <= 1;
            end else if(busy_o == 1'b1)begin
                if(shifted >= 100)begin
                    reg_remainder <= shifted - 100;
                    reg_quotient <= {reg_quotient[30:0], 1'b1};
                end else begin
                    reg_remainder <= shifted[7:0];
                    reg_quotient <= {reg_quotient[30:0], 1'b0};
                end
                reg_steps <= reg_steps - 1'b1;
                if(reg_steps == 1)begin
                    pre_samples_o <= {reg_quotient[30:0], (shifted >= 100)};
                    busy_o <= 0;
                    done_o <= 1;
                end
            end
        end
    end

endmodule
