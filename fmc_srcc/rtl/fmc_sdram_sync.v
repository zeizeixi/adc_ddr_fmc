`timescale 1ns / 1ps
`default_nettype none
// SDRAM-shaped peripheral clocked directly by the buffered MCU SDCLK.
// BL1, CAS3, single write, 13 row bits, 8 column bits, four banks.
// C0 registers pins, C1 launches RAM read, C3 launches the two-cycle RAM response.
// MCU configuration: SDCLK=56 MHz, CAS3, RPIPE2, RBURST disabled.
module fmc_sdram_sync (
    input wire clk,
    input wire rst,
    input wire enabled,
    input wire clear_error,
    input wire cke,
    input wire cs_n,
    input wire ras_n,
    input wire cas_n,
    input wire we_n,
    input wire [12:0] addr,
    input wire [1:0] bank,
    input wire [1:0] dqm,
    inout wire [15:0] dq,
    output wire bus_read,
    output wire bus_write,
    output wire [23:0] bus_addr,
    output wire [15:0] bus_wdata,
    output wire [1:0] bus_mask,
    input wire [15:0] register_data,
    input wire memory_selected,
    input wire [15:0] memory_data,
    input wire memory_valid,
    output wire reads_idle,
    output wire mode_valid,
    output wire protocol_error
);
    reg [12:0] row_first;
    reg [12:0] row_second;
    reg [12:0] row_third;
    reg [12:0] row_fourth;
    reg [12:0] selected_row;
    reg [3:0] row_open;
    (* IOB = "FALSE" *) reg cke_q;
    (* IOB = "FALSE" *) reg cs_q;
    (* IOB = "FALSE" *) reg [2:0] command_q;
    (* IOB = "FALSE" *) reg [12:0] addr_q;
    (* IOB = "FALSE" *) reg [1:0] bank_q;
    (* IOB = "FALSE" *) reg [1:0] mask_q;
    (* IOB = "FALSE" *) reg [15:0] data_q;
    reg [1:0] read_pipe;
    reg [1:0] memory_pipe;
    reg [15:0] register_first;
    reg [15:0] register_second;
    (* IOB = "TRUE" *) reg [15:0] drive_data;
    (* IOB = "TRUE", DONT_TOUCH = "TRUE" *) reg [15:0] drive_tristate;
    reg [1:0] mask_first;
    reg [1:0] mask_second;
    reg mode_valid_o;
    reg protocol_error_o;
    wire selected = enabled && !rst && cke_q && !cs_q;
    wire address_valid = mode_valid_o && row_open[bank_q];

    assign bus_read = selected && command_q == 3'b101 && address_valid;
    assign bus_write = selected && command_q == 3'b100 && address_valid;
    assign bus_addr = {bank_q, selected_row, addr_q[7:0], 1'b0};
    assign bus_wdata = data_q;
    assign bus_mask = mask_q;
    assign reads_idle = read_pipe == 0;
    assign mode_valid = mode_valid_o;
    assign protocol_error = protocol_error_o;
    genvar data_bit;
    generate
        for (data_bit = 0; data_bit < 16; data_bit = data_bit + 1) begin : gen_data_pin
            assign dq[data_bit] = drive_tristate[data_bit] ? 1'bz : drive_data[data_bit];
        end
    endgenerate

    always @(*) begin
        case (bank_q)
            2'd0: selected_row = row_first;
            2'd1: selected_row = row_second;
            2'd2: selected_row = row_third;
            default: selected_row = row_fourth;
        endcase
    end

    // Register pins before decoding. Fabric FFs avoid HR-bank automatic ZHOLD
    // delay on this unadjusted BUFG clock. No reset is needed while bus_read
    // and bus_write are suppressed by rst and the cleared mode-valid flag.
    always @(posedge clk) begin
        cke_q <= cke;
        cs_q <= cs_n;
        command_q <= {ras_n, cas_n, we_n};
        addr_q <= addr;
        bank_q <= bank;
        mask_q <= dqm;
        data_q <= dq;
    end

    // One I/O tristate FF per pin: no fabric enable/reset LUT in the pin path.
    // Asynchronous preset releases DQ even if SDCLK stops during system reset.
    always @(posedge clk or posedge rst) begin
        if (rst) drive_tristate <= 16'hffff;
        else if (!enabled || !cke_q || (!cs_q && command_q == 3'b100))
            drive_tristate <= 16'hffff;
        else drive_tristate <= read_pipe[1] ?
            {{8{mask_second[1]}}, {8{mask_second[0]}}} : 16'hffff;
    end

    always @(posedge clk) begin
        if (rst) begin
            row_first <= 0;
            row_second <= 0;
            row_third <= 0;
            row_fourth <= 0;
            row_open <= 0;
            read_pipe <= 0;
            memory_pipe <= 0;
            register_first <= 0;
            register_second <= 0;
            drive_data <= 0;
            mask_first <= 0;
            mask_second <= 0;
            mode_valid_o <= 0;
            protocol_error_o <= 0;
        end else if (!enabled) begin
            row_open <= 0;
            read_pipe <= 0;
            memory_pipe <= 0;
            mode_valid_o <= 0;
            protocol_error_o <= 0;
        end else begin
            if (clear_error) protocol_error_o <= 0;
            if (cke_q) begin
                mask_first <= dqm;
                mask_second <= mask_first;
                read_pipe <= {read_pipe[0], 1'b0};
                memory_pipe <= {memory_pipe[0], 1'b0};
                register_second <= register_first;
                if (read_pipe[1]) begin
                    if (memory_pipe[1]) begin
                        drive_data <= memory_valid ? memory_data : 16'hdead;
                        if (!memory_valid) protocol_error_o <= 1;
                    end else drive_data <= register_second;
                end
                if (!cs_q) begin
                    case (command_q)
                        3'b011: begin
                            row_open[bank_q] <= 1;
                            case (bank_q)
                                2'd0: row_first <= addr_q;
                                2'd1: row_second <= addr_q;
                                2'd2: row_third <= addr_q;
                                default: row_fourth <= addr_q;
                            endcase
                        end
                        3'b101: begin
                            read_pipe[0] <= 1;
                            memory_pipe[0] <= bus_read && memory_selected;
                            register_first <= bus_read ? register_data : 16'hdead;
                            if (!address_valid) protocol_error_o <= 1;
                            if (addr_q[10]) row_open[bank_q] <= 0;
                        end
                        3'b100: begin
                            if (!address_valid || read_pipe != 0) protocol_error_o <= 1;
                            if (addr_q[10]) row_open[bank_q] <= 0;
                        end
                        3'b010: begin
                            if (addr_q[10]) row_open <= 0;
                            else row_open[bank_q] <= 0;
                        end
                        3'b000: begin
                            mode_valid_o <= addr_q == 13'h230 && bank_q == 0;
                            if (addr_q != 13'h230 || bank_q != 0) protocol_error_o <= 1;
                        end
                        default: begin
                            // NOP, refresh and burst terminate do not change ownership.
                        end
                    endcase
                end
            end else begin
                if (read_pipe != 0) protocol_error_o <= 1;
                read_pipe <= 0;
                memory_pipe <= 0;
            end
        end
    end
endmodule
`default_nettype wire
