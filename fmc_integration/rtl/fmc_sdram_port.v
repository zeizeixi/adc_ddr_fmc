`timescale 1ns/1ps
`default_nettype none
// SDRAM-shaped peripheral, not a general SDRAM memory replacement.
// clk=100 MHz; external SDCLK=1..5 MHz, high/low>=100 ns.
// Mode: 13 row bits, 8 column bits, four banks, BL1, CAS3, single write.
// STM32 must use RPIPE=2 and RBURST=0. Read data is launched after C3.
module fmc_sdram_port (
    input wire clk, rst, enabled, clear_error,
    input wire sdclk, cke, cs_n, ras_n, cas_n, we_n,
    input wire [12:0] addr,
    input wire [1:0] bank, dqm,
    inout wire [15:0] dq,
    output reg bus_read, bus_write,
    output reg [23:0] bus_addr,
    output reg [15:0] bus_wdata,
    output reg [1:0] bus_mask,
    input wire reply_valid,
    input wire [15:0] reply_data,
    output reg mode_valid, protocol_error
);
    // Delay the bus longer than the edge detector so decoding uses a sample
    // from BEFORE the external rising edge. Require >=30 ns input setup.
    // Do not depend on the MCU holding the old command long after that edge.
    (* ASYNC_REG="TRUE" *) reg [2:0] clock_sync;
    (* ASYNC_REG="TRUE" *) reg [37:0] pins_meta, pins_sync;
    (* SHREG_EXTRACT="NO" *) reg [37:0] pins_history_first, pins_history_second, pins_history_third;
    reg clock_last;
    wire rise = clock_sync[2] && !clock_last;
    wire [37:0] pins = {cke,cs_n,ras_n,cas_n,we_n,addr,bank,dqm,dq};
    wire cke_q = pins_history_third[37];
    wire cs_q = pins_history_third[36];
    wire [2:0] command = pins_history_third[35:33];
    wire [12:0] addr_q = pins_history_third[32:20];
    wire [1:0] bank_q = pins_history_third[19:18];
    wire [1:0] mask_q = pins_history_third[17:16];
    wire [15:0] data_q = pins_history_third[15:0];
    reg [12:0] row_a, row_b, row_c, row_d;
    reg [3:0] row_open;
    reg [12:0] selected_row;
    reg [2:0] read_pipe;
    reg [15:0] response_first, response_second, response_third;
    reg response_pending;
    reg [1:0] mask_first, mask_second;
    reg [15:0] drive_data;
    reg [1:0] drive_enable;
    reg [7:0] edge_age;
    reg edge_seen;

    assign dq[7:0] = (enabled && !rst && drive_enable[0]) ? drive_data[7:0] : 8'bz;
    assign dq[15:8] = (enabled && !rst && drive_enable[1]) ? drive_data[15:8] : 8'bz;

    always @* begin
        case (bank_q)
            2'd0: selected_row = row_a;
            2'd1: selected_row = row_b;
            2'd2: selected_row = row_c;
            default: selected_row = row_d;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            clock_sync <= 0;
            clock_last <= 0;
            pins_meta <= 0;
            pins_sync <= 0;
            pins_history_first <= 0;
            pins_history_second <= 0;
            pins_history_third <= 0;
        end else begin
            clock_sync <= {clock_sync[1:0],sdclk};
            clock_last <= clock_sync[2];
            pins_meta <= pins;
            pins_sync <= pins_meta;
            pins_history_first <= pins_sync;
            pins_history_second <= pins_history_first;
            pins_history_third <= pins_history_second;
        end
    end

    always @(posedge clk) begin
        if (rst || !enabled) begin
            row_a <= 0; row_b <= 0; row_c <= 0; row_d <= 0;
            row_open <= 0;
            read_pipe <= 0;
            response_first <= 0; response_second <= 0; response_third <= 0;
            response_pending <= 0;
            mask_first <= 0; mask_second <= 0;
            drive_data <= 0; drive_enable <= 0;
            bus_read <= 0; bus_write <= 0;
            bus_addr <= 0; bus_wdata <= 0; bus_mask <= 0;
            mode_valid <= 0; protocol_error <= 0;
            edge_age <= 0; edge_seen <= 0;
        end else begin
            bus_read <= 0;
            bus_write <= 0;
            if (clear_error) protocol_error <= 0;
            if (edge_age != 8'hff) edge_age <= edge_age + 1'b1;
            if (reply_valid && response_pending) begin
                response_first <= reply_data;
                response_pending <= 0;
            end
            // A stopped MCU clock must not leave DQ driven indefinitely.
            if (edge_age == 8'hfe) begin
                drive_enable <= 0;
                read_pipe <= 0;
                response_pending <= 0;
            end
            if (rise) begin
                edge_age <= 0;
                edge_seen <= 1;
                if (edge_seen && edge_age < 8'd19) protocol_error <= 1;
                if (cke_q) begin
                    mask_first <= mask_q;
                    mask_second <= mask_first;
                    drive_enable <= read_pipe[2] ? ~mask_second : 2'b00;
                    drive_data <= response_third;
                    read_pipe <= {read_pipe[1:0],1'b0};
                    response_third <= response_second;
                    response_second <= response_first;
                    if (response_pending) begin
                        protocol_error <= 1;
                        response_pending <= 0;
                        response_second <= 16'hdead;
                    end
                    if (!cs_q) begin
                        case (command)
                            3'b011: begin // ACTIVE
                                row_open[bank_q] <= 1;
                                case (bank_q)
                                    2'd0: row_a <= addr_q;
                                    2'd1: row_b <= addr_q;
                                    2'd2: row_c <= addr_q;
                                    2'd3: row_d <= addr_q;
                                endcase
                            end
                            3'b101: begin // READ, one halfword
                                read_pipe[0] <= 1;
                                response_first <= 16'hdead;
                                if (mode_valid && row_open[bank_q]) begin
                                    bus_addr <= {bank_q,selected_row,addr_q[7:0],1'b0};
                                    bus_read <= 1;
                                    response_pending <= 1;
                                end else protocol_error <= 1;
                                if (addr_q[10]) row_open[bank_q] <= 0;
                            end
                            3'b100: begin // WRITE: DQM=1 masks a byte
                                drive_enable <= 0;
                                if (mode_valid && row_open[bank_q]) begin
                                    bus_addr <= {bank_q,selected_row,addr_q[7:0],1'b0};
                                    bus_wdata <= data_q;
                                    bus_mask <= mask_q;
                                    bus_write <= 1;
                                end else protocol_error <= 1;
                                if (addr_q[10]) row_open[bank_q] <= 0;
                            end
                            3'b010: begin // PRECHARGE does not discard read replies
                                if (addr_q[10]) row_open <= 0;
                                else row_open[bank_q] <= 0;
                            end
                            3'b000: begin // MRS: only the documented mode is supported
                                mode_valid <= (addr_q == 13'h230 && bank_q == 0);
                                if (addr_q != 13'h230 || bank_q != 0) protocol_error <= 1;
                            end
                            3'b110: begin // BURST TERMINATE: no burst in BL1 mode
                            end
                            3'b001: begin // AUTO REFRESH: no local SDRAM array
                            end
                            default: begin // NOP
                            end
                        endcase
                    end
                end else begin
                    drive_enable <= 0;
                    if (|read_pipe || response_pending) protocol_error <= 1;
                    read_pipe <= 0;
                    response_pending <= 0;
                end
            end
        end
    end
endmodule
`default_nettype wire
