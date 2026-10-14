`timescale 1ns/1ps
`default_nettype none
module tb_fmc_throughput_throttled;
    tb_fmc_throughput #(.DDR_READY_PERIOD(16), .PHASE_PS(0), .DUTY_SKEW_PS(2976)) u_test();
endmodule
`default_nettype wire
