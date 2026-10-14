`timescale 1ns/1ps
`default_nettype none
// Four-phase bundled-data mailbox. Both domains MUST reset together.
// Source holds payload until destination acknowledgement returns.
// Destination adds two settling cycles after synchronized request.
// See constraints/runtime_cdc.xdc for the bounded payload crossing.
module cdc_mailbox #(parameter WIDTH=32)(
    input wire src_clk, src_rst, src_send,
    input wire [WIDTH-1:0] src_data,
    output wire src_busy,
    input wire dst_clk, dst_rst,
    output reg dst_valid,
    output reg [WIDTH-1:0] dst_data
);
    reg req, ack;
    reg [WIDTH-1:0] payload_hold;
    (* ASYNC_REG="TRUE" *) reg [2:0] req_sync, ack_sync;
    reg src_wait;
    reg [1:0] dst_state;
    assign src_busy = src_wait;
    always @(posedge src_clk) begin
        if (src_rst) begin
            req<=0; src_wait<=0; payload_hold<=0; ack_sync<=0;
        end else begin
            ack_sync <= {ack_sync[1:0],ack};
            if (!src_wait && src_send) begin
                payload_hold<=src_data; req<=1; src_wait<=1;
            end else if (req && ack_sync[2]) req<=0;
            else if (src_wait && !req && !ack_sync[2]) src_wait<=0;
        end
    end
    always @(posedge dst_clk) begin
        if (dst_rst) begin
            req_sync<=0; dst_state<=0; dst_valid<=0; dst_data<=0; ack<=0;
        end else begin
            req_sync <= {req_sync[1:0],req};
            dst_valid<=0;
            case (dst_state)
                0: if (req_sync[2]) dst_state<=1;
                1: dst_state<=2;
                2: begin dst_data<=payload_hold; dst_valid<=1; ack<=1; dst_state<=3; end
                3: if (!req_sync[2]) begin ack<=0; dst_state<=0; end
            endcase
        end
    end
endmodule
`default_nettype wire
