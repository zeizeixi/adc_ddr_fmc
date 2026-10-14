`timescale 1ns/1ps
module tb_fmc_phase_0;
tb_fmc_link #(.CLOCK_PHASE(0),.DUTY_SKEW(5),.EXTRA_RAM_CYCLES(2)) u_case();
endmodule
module tb_fmc_phase_1;
tb_fmc_link #(.CLOCK_PHASE(1),.DUTY_SKEW(-5),.EXTRA_RAM_CYCLES(0)) u_case();
endmodule
module tb_fmc_phase_2;
tb_fmc_link #(.CLOCK_PHASE(2),.DUTY_SKEW(0),.EXTRA_RAM_CYCLES(2)) u_case();
endmodule
module tb_fmc_phase_3;
tb_fmc_link #(.CLOCK_PHASE(3),.DUTY_SKEW(5),.EXTRA_RAM_CYCLES(0)) u_case();
endmodule
module tb_fmc_phase_4;
tb_fmc_link #(.CLOCK_PHASE(4),.DUTY_SKEW(-5),.EXTRA_RAM_CYCLES(2)) u_case();
endmodule
module tb_fmc_phase_5;
tb_fmc_link #(.CLOCK_PHASE(5),.DUTY_SKEW(0),.EXTRA_RAM_CYCLES(0)) u_case();
endmodule
module tb_fmc_phase_6;
tb_fmc_link #(.CLOCK_PHASE(6),.DUTY_SKEW(5),.EXTRA_RAM_CYCLES(2)) u_case();
endmodule
module tb_fmc_phase_7;
tb_fmc_link #(.CLOCK_PHASE(7),.DUTY_SKEW(-5),.EXTRA_RAM_CYCLES(0)) u_case();
endmodule
module tb_fmc_phase_8;
tb_fmc_link #(.CLOCK_PHASE(8),.DUTY_SKEW(0),.EXTRA_RAM_CYCLES(2)) u_case();
endmodule
module tb_fmc_phase_9;
tb_fmc_link #(.CLOCK_PHASE(9),.DUTY_SKEW(5),.EXTRA_RAM_CYCLES(0)) u_case();
endmodule
