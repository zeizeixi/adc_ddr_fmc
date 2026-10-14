module tb_fmc_case_0; tb_fmc_srcc #(.PHASE_PS(0), .DUTY_SKEW_PS(0)) u_case(); endmodule
module tb_fmc_case_1; tb_fmc_srcc #(.PHASE_PS(1600), .DUTY_SKEW_PS(2976)) u_case(); endmodule
module tb_fmc_case_2; tb_fmc_srcc #(.PHASE_PS(3200), .DUTY_SKEW_PS(-2976)) u_case(); endmodule
module tb_fmc_case_3; tb_fmc_srcc #(.PHASE_PS(4800), .DUTY_SKEW_PS(0)) u_case(); endmodule
module tb_fmc_case_4; tb_fmc_srcc #(.PHASE_PS(6400), .DUTY_SKEW_PS(2976)) u_case(); endmodule
module tb_fmc_case_5; tb_fmc_srcc #(.PHASE_PS(8000), .DUTY_SKEW_PS(-2976)) u_case(); endmodule