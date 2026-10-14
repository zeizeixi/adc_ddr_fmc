`timescale 1ns/1ps
`default_nettype none
// 8 KiB: 256 x 256-bit writes, 4096 x 16-bit reads. Lowest halfword first.
// No simultaneous read/write ownership: enforced by ddr_block_reader.
// READ_LATENCY_B=2. Contents are not cleared by reset; valid flags are cleared.
module ram256x16_8k(
    input wire wr_clk, wr_en, input wire [7:0] wr_addr,
    input wire [255:0] wr_data,
    input wire rd_clk, rd_rst, rd_en, input wire [11:0] rd_addr,
    output wire [15:0] rd_data
);
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(8),.ADDR_WIDTH_B(12),.AUTO_SLEEP_TIME(0),
        .BYTE_WRITE_WIDTH_A(256),.CLOCKING_MODE("independent_clock"),
        .ECC_MODE("no_ecc"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),
        .MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(65536),
        .MESSAGE_CONTROL(0),.READ_DATA_WIDTH_B(16),.READ_LATENCY_B(2),
        .READ_RESET_VALUE_B("0"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(1),
        .USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(256),.WRITE_MODE_B("no_change")
    ) u_ram(
        .clka(wr_clk),.ena(wr_en),.wea(wr_en),.addra(wr_addr),.dina(wr_data),
        .clkb(rd_clk),.rstb(rd_rst),.enb(rd_en),.addrb(rd_addr),.doutb(rd_data),
        .regceb(1'b1),.sleep(1'b0),.injectdbiterra(1'b0),.injectsbiterra(1'b0),
        .dbiterrb(),.sbiterrb());
endmodule
`default_nettype wire
