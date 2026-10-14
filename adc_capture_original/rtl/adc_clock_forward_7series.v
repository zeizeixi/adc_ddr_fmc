`timescale 1ns/1ps
`default_nettype none
// OPTIONAL pin-clock forwarding, NOT a PLL and NOT a frequency divider.
// Input must already be a clean, continuous 100 MHz clock from a suitable source.
// Set output IOSTANDARD in board XDC after checking bank VCCO and ADC levels.
module adc_clock_forward_7series(
    input wire clk_100m, output wire adc_clk_p, output wire adc_clk_n
);
    wire forwarded;
    ODDR #(.DDR_CLK_EDGE("SAME_EDGE"),.INIT(1'b0),.SRTYPE("SYNC")) u_oddr (
        .Q(forwarded),.C(clk_100m),.CE(1'b1),.D1(1'b1),.D2(1'b0),.R(1'b0),.S(1'b0)
    );
    OBUFDS u_obufds(.I(forwarded),.O(adc_clk_p),.OB(adc_clk_n));
endmodule
`default_nettype wire
