`timescale 1ns/1ps
`default_nettype none
// One capture per reset. start is a persistent level in THIS clock domain.
// ADC has no backpressure: overflow aborts capture; reset is required to retry.
// Sample n is {4'b0, B[n], 4'b0, A[n]}; earliest sample is in bits [31:0].
// A partial final block is zero-padded; only CAPTURE_SAMPLES*4 bytes are valid.
module ads62p24_pack256 #(
    parameter integer CAPTURE_SAMPLES = 20000000
)(
    input wire adc_clk, input wire rst, input wire start,
    input wire [11:0] adc_a, input wire [11:0] adc_b,
    output reg [255:0] out_data, output reg out_valid, input wire out_ready,
    output reg busy, output reg done, output reg overflow,
    output reg [31:0] sample_count
);
    (* IOB = "TRUE" *) reg [11:0] adc_a_q, adc_b_q;
    always @(posedge adc_clk) begin
        adc_a_q <= adc_a;
        adc_b_q <= adc_b;
    end
    localparam [2:0] IDLE=0, CAPTURE=1, FLUSH=2, FINISHED=3, FAILED=4;
    reg [2:0] state, pack_index;
    reg [255:0] pack_data;
    reg [255:0] next_pack;
    wire slot_available = !out_valid || out_ready;
    always @* begin
        next_pack = pack_data;
        next_pack[pack_index*32 +: 32] = {4'b0000,adc_b_q,4'b0000,adc_a_q};
    end
    always @(posedge adc_clk) begin
        if (rst) begin
            state <= IDLE; pack_index <= 0; pack_data <= 0;
            out_data <= 0; out_valid <= 0; busy <= 0; done <= 0;
            overflow <= 0; sample_count <= 0;
        end else begin
            if (out_valid && out_ready) out_valid <= 0;
            case (state)
                IDLE: if (start) begin
                    busy <= 1; state <= CAPTURE;
                end
                CAPTURE: begin
                    sample_count <= sample_count+1;
                    if (pack_index == 7 || sample_count == CAPTURE_SAMPLES-1) begin
                        if (slot_available) begin
                            out_data <= next_pack; out_valid <= 1;
                            pack_index <= 0; pack_data <= 0;
                            if (sample_count == CAPTURE_SAMPLES-1) state <= FLUSH;
                        end else begin
                            overflow <= 1; busy <= 0; state <= FAILED;
                        end
                    end else begin
                        pack_data <= next_pack; pack_index <= pack_index+1;
                    end
                end
                FLUSH: if (out_valid && out_ready) begin
                    done <= 1; busy <= 0; state <= FINISHED;
                end
                FINISHED: begin end
                FAILED: begin end // The previously queued word may still drain.
                default: begin overflow <= 1; busy <= 0; state <= FAILED; end
            endcase
        end
    end
    // synthesis translate_off
    initial if (CAPTURE_SAMPLES < 1 || CAPTURE_SAMPLES > 20000000)
        $fatal(1,"CAPTURE_SAMPLES must be 1..20000000 pairs");
    // synthesis translate_on
endmodule
`default_nettype wire
