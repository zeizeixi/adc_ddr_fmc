`timescale 1ns/1ps
`default_nettype none
// TI SLAS576C: 16-bit serial writes, MSB first, latched on SCLK FALLING edges.
// 0x14 <- 0x80: override pins, CMOS, internal reference, 0 dB, both channels on.
// 0x16 <- 0x10: straight binary, normal data. 0x14 instead enables digital ramp.
// This is a startup sequencer, not a general SPI bus or readback controller.
module ads62p24_init #(
    parameter integer CLK_HZ = 100000000,
    parameter integer SPI_HZ = 1000000,
    parameter integer POWER_WAIT_CYCLES = 100000, // 1 ms at 100 MHz
    parameter integer RESET_HIGH_CYCLES = 100,   // 1 us, datasheet requires >10 ns
    parameter integer RESET_WAIT_CYCLES = 100,
    parameter integer SETTLE_CYCLES = 10000,     // 100 us AFTER last register write
    parameter integer TEST_RAMP = 0
)(
    input wire clk, input wire rst,
    output reg adc_reset, output reg adc_cs_n,
    output reg adc_sck, output reg adc_sdi,
    output wire [2:0] adc_ctrl,
    output reg done
);
    localparam integer HALF_PERIOD = CLK_HZ / (2 * SPI_HZ);
    localparam [3:0] POWER_WAIT=0, RESET_HIGH=1, RESET_WAIT=2, LOAD=3,
                     SHIFT=4, CS_HOLD=5, CS_GAP=6, SETTLE=7, FINISHED=8;
    reg [3:0] state;
    reg [31:0] delay_count;
    reg [15:0] shift_word;
    reg [3:0] bit_count;
    reg word_index;
    assign adc_ctrl = 3'b000; // Register 0x14 overrides power/mux pin settings.
    always @(posedge clk) begin
        if (rst) begin
            state <= POWER_WAIT; delay_count <= 0; shift_word <= 0;
            bit_count <= 0; word_index <= 0; done <= 0;
            adc_reset <= 0; adc_cs_n <= 1; adc_sck <= 0; adc_sdi <= 0;
        end else begin
            case (state)
                POWER_WAIT: if (delay_count == POWER_WAIT_CYCLES-1) begin
                    delay_count <= 0; adc_reset <= 1; state <= RESET_HIGH;
                end else delay_count <= delay_count+1;
                RESET_HIGH: if (delay_count == RESET_HIGH_CYCLES-1) begin
                    delay_count <= 0; adc_reset <= 0; state <= RESET_WAIT;
                end else delay_count <= delay_count+1;
                RESET_WAIT: if (delay_count == RESET_WAIT_CYCLES-1) begin
                    delay_count <= 0; state <= LOAD;
                end else delay_count <= delay_count+1;
                LOAD: begin
                    shift_word <= word_index ? (TEST_RAMP ? 16'h1614 : 16'h1610)
                                             : 16'h1480;
                    adc_sdi <= 0; // MSB of both configured register addresses is 0.
                    adc_cs_n <= 0; adc_sck <= 0;
                    bit_count <= 0; delay_count <= 0; state <= SHIFT;
                end
                SHIFT: if (delay_count == HALF_PERIOD-1) begin
                    delay_count <= 0;
                    if (!adc_sck) begin
                        adc_sck <= 1;
                        adc_sdi <= shift_word[15]; // Update on rising edge.
                    end else begin
                        adc_sck <= 0; // ADC samples here; SDI stays unchanged.
                        shift_word <= {shift_word[14:0],1'b0};
                        if (bit_count == 15) state <= CS_HOLD;
                        else bit_count <= bit_count+1;
                    end
                end else delay_count <= delay_count+1;
                CS_HOLD: if (delay_count == HALF_PERIOD-1) begin
                    delay_count <= 0; adc_cs_n <= 1; state <= CS_GAP;
                end else delay_count <= delay_count+1;
                CS_GAP: if (delay_count == HALF_PERIOD-1) begin
                    delay_count <= 0;
                    if (!word_index) begin word_index <= 1; state <= LOAD; end
                    else state <= SETTLE;
                end else delay_count <= delay_count+1;
                SETTLE: if (delay_count == SETTLE_CYCLES-1) begin
                    done <= 1; state <= FINISHED;
                end else delay_count <= delay_count+1;
                FINISHED: done <= 1;
                default: begin state <= POWER_WAIT; done <= 0; delay_count <= 0; end
            endcase
        end
    end
    // synthesis translate_off
    initial begin
        if (CLK_HZ % (2*SPI_HZ) != 0 || HALF_PERIOD < 1 || SPI_HZ > 20000000)
            $fatal(1,"Invalid ADS62P24 serial clock parameters");
        if (POWER_WAIT_CYCLES<1 || RESET_HIGH_CYCLES<1 || RESET_WAIT_CYCLES<1 || SETTLE_CYCLES<1)
            $fatal(1,"All startup waits must be positive");
    end
    // synthesis translate_on
endmodule
`default_nettype wire
