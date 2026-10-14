`timescale 1ns/1ps
`default_nettype none
// �첽��λ��ͬ���ͷš���λ�ڼ�ʱ�ӱ�������
module reset_sync (
    input  wire clk,
    input  wire arst,
    output wire rst
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;

    always @(posedge clk or posedge arst) begin
        if (arst) begin
            sync_ff <= 3'b111;
        end else begin
            sync_ff <= {sync_ff[1:0], 1'b0};
        end
    end

    assign rst = sync_ff[2];

endmodule
`default_nettype wire
