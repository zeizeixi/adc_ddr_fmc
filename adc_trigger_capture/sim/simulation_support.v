`timescale 1ns/1ps
// 仿真专用：ILA 无功能模型；生产工程继续使用原 ILA IP。
// FIFO 使用厂商 XPM 模型，配置为 256x512、FWFT、独立时钟。
module adc_raw_ila(input clk,input [11:0] probe0,probe1,probe2,probe3,input probe4,probe5);
endmodule
module adc_fifo_256x512 (
    input rst,wr_clk,rd_clk,
    input [255:0] din,
    input wr_en,rd_en,
    output [255:0] dout,
    output full,empty,wr_rst_busy,rd_rst_busy
);
    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE("block"),.FIFO_WRITE_DEPTH(512),
        .WRITE_DATA_WIDTH(256),.READ_DATA_WIDTH(256),.READ_MODE("fwft"),
        .FIFO_READ_LATENCY(0),.CDC_SYNC_STAGES(3),.RELATED_CLOCKS(0),
        .USE_ADV_FEATURES("0000"),.SIM_ASSERT_CHK(1)
    ) u_fifo (
        .rst(rst),.wr_clk(wr_clk),.rd_clk(rd_clk),.din(din),
        .wr_en(wr_en),.rd_en(rd_en),.dout(dout),.full(full),.empty(empty),
        .wr_rst_busy(wr_rst_busy),.rd_rst_busy(rd_rst_busy),
        .sleep(1'b0),.injectdbiterr(1'b0),.injectsbiterr(1'b0),
        .almost_empty(),.almost_full(),.data_valid(),.dbiterr(),.sbiterr(),
        .overflow(),.underflow(),.prog_empty(),.prog_full(),
        .rd_data_count(),.wr_data_count(),.wr_ack()
    );
endmodule

