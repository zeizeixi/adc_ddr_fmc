`timescale 1ns/1ps
module tb_fmc_window_short_low;
    tb_fmc_return_window #(.PHASE_PS(0), .DUTY_SKEW_PS(2976)) u_test();
endmodule
