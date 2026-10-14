`timescale 1ns/1ps
module tb_fmc_window_middle;
    tb_fmc_return_window #(.PHASE_PS(3200), .DUTY_SKEW_PS(0)) u_test();
endmodule
