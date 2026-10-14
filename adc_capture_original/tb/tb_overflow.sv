`timescale 1ns/1ps
module tb_overflow;
    reg sys_clk=0, adc_clk=0, ui_clk=0, rst=1, start=0;
    always #5 sys_clk=~sys_clk;
    initial begin #1; forever #5 adc_clk=~adc_clk; end
    always #4 ui_clk=~ui_clk;
    wire ready, done, overflow, busy, valid;
    wire [255:0] data;
    wire [31:0] count;
    ads62p24_capture_top #(.CAPTURE_SAMPLES(5000),.CFG_POWER_WAIT(20),
        .CFG_RESET_HIGH(20),.CFG_RESET_WAIT(20),.CFG_SETTLE(100)) dut (
        .i_sys_clk_100m(sys_clk),.i_sys_rst(rst),.i_adc_clk_out(adc_clk),
        .i_adc_da(12'h123),.i_adc_db(12'habc),.o_adc_reset(),.o_adc_cs_n(),
        .o_adc_sck(),.o_adc_sdi(),.o_adc_ctrl(),.i_ui_clk(ui_clk),.i_ui_rst(rst),
        .i_mig_calib_done(!rst),.i_start_sys(start),.o_ready_sys(ready),.o_cfg_done_sys(),
        .o_capture_done_sys(done),.o_overflow_sys(overflow),.o_capture_busy_sys(busy),
        .o_data_ui(data),.o_valid_ui(valid),.i_ready_ui(1'b0),
        .o_adc_clk_debug(),.o_sample_count_adc(count)
    );
    initial begin
        #200; rst=0; wait(ready);
        @(negedge sys_clk); start=1; @(negedge sys_clk); start=0;
        wait(overflow); repeat(20) @(posedge sys_clk);
        if (done || busy || count>=5000 || !valid) $fatal(1,"Overflow handling failed");
        $display("PASS tb_overflow: actual FIFO full, capture aborted at %0d pairs, error latched",count);
        $finish;
    end
    initial begin #500000; $fatal(1,"tb_overflow timeout"); end
endmodule
