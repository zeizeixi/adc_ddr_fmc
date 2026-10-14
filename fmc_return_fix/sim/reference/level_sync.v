`timescale 1ns/1ps
`default_nettype none
// For persistent status/control levels only, NOT narrow pulses or data buses.
module level_sync #(parameter RESET_VALUE = 1'b0)(
    input wire clk, input wire rst, input wire async_in, output wire sync_out
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;
    always @(posedge clk or posedge rst)
        if (rst) sync_ff <= {3{RESET_VALUE}};
        else     sync_ff <= {sync_ff[1:0], async_in};
    assign sync_out = sync_ff[2];
endmodule
`default_nettype wire
