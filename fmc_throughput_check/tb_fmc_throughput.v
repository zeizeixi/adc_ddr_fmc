`timescale 1ns / 1ps
`default_nettype none
module tb_fmc_throughput;
    parameter integer DDR_READY_PERIOD = 1;
    parameter integer PHASE_PS = 1300;
    parameter integer HALF_PERIOD_PS = 8929;
    parameter integer DUTY_SKEW_PS = 0;
    reg ui_clk = 0;
    reg sdclk = 0;
    reg reset_n = 0;
    always #5 ui_clk = !ui_clk;
    initial begin #(PHASE_PS/1000.0); forever #((HALF_PERIOD_PS + (sdclk ? DUTY_SKEW_PS : -DUTY_SKEW_PS))/1000.0) sdclk = !sdclk; end
    reg cke = 1;
    reg cs_n = 1;
    reg [2:0] command = 3'b111;
    reg [12:0] addr = 0;
    reg [1:0] bank = 0;
    reg [1:0] dqm = 0;
    reg host_drive = 0;
    reg [15:0] host_data = 0;
    wire [15:0] dq;
    assign dq = host_drive ? host_data : 16'bz;
    fmc_throughput_system #(.DDR_READY_PERIOD(DDR_READY_PERIOD)) u_dut (
        .ui_clk(ui_clk), .reset_n(reset_n), .MCU_FMC_SDCLK(sdclk),
        .MCU_FMC_SDCKE1(cke), .MCU_FMC_SDNE1(cs_n),
        .MCU_FMC_SDNRAS(command[2]), .MCU_FMC_SDNCAS(command[1]), .MCU_FMC_SDNWE(command[0]),
        .MCU_FMC_A(addr), .MCU_FMC_BA(bank), .MCU_FMC_NBL(dqm), .MCU_FMC_D(dq)
    );
    reg expected_read = 0;
    reg [15:0] expected_data = 0;
    reg [15:0] expected_mask = 16'hffff;
    reg [3:0] score_valid = 0;
    reg [15:0] score_data_first, score_data_second, score_data_third, score_data_fourth;
    reg [15:0] score_mask_first, score_mask_second, score_mask_third, score_mask_fourth;
    reg [15:0] last_read;
    integer checks = 0;
    integer errors = 0;
    integer row_number;
    integer column_number;
    integer poll_count;
    integer word_number;
    realtime first_fill_start;
    realtime second_fill_start;
    realtime first_read_start;
    realtime second_read_start;
    realtime fill_started;
    realtime ack_started;
    realtime last_ack_start;
    realtime filling_total_ns = 0;
    realtime handshake_total_ns = 0;
    realtime first_fill_ns;
    realtime second_fill_ns;
    realtime full_read_ns;
    realtime tail_read_ns;
    realtime record_started;
    integer loaded_blocks = 0;
    integer accepted_acks = 0;

    // A legal write must never overlap an outstanding FPGA DQ drive.
    always @(posedge sdclk) begin
        if (reset_n && host_drive && u_dut.u_fmc_port.drive_tristate !== 16'hffff)
            $fatal(1, "Read-to-write handover caused DQ contention");
    end

    // Require data valid 2 ns before the C3 rising edge, rather than assuming
    // RPIPE2 shifts the external pin capture by two HCLK periods. The old
    // positive-C3 launch must fail this check; the C2 response must pass.
    always @(posedge sdclk) begin
        if (!reset_n) score_valid = 0;
        else begin
            score_valid = {score_valid[2:0], expected_read};
            score_data_fourth = score_data_third;
            score_data_third = score_data_second;
            score_data_second = score_data_first;
            score_data_first = expected_data;
            score_mask_fourth = score_mask_third;
            score_mask_third = score_mask_second;
            score_mask_second = score_mask_first;
            score_mask_first = expected_mask;
            #((2.0*HALF_PERIOD_PS)/1000.0 - 2.0);
            if (reset_n && score_valid[2]) begin
                last_read = dq;
                checks = checks + 1;
                if ((dq & score_mask_third) !== (score_data_third & score_mask_third)) begin
                    $display("FAIL expected=%h mask=%h got=%h time=%t", score_data_third, score_mask_third, dq, $time);
                    errors = errors + 1;
                end
            end else if (reset_n && !host_drive && dq !== 16'hzzzz) begin
                $display("FAIL unexpected DQ drive %h time=%t", dq, $time);
                errors = errors + 1;
            end
        end
    end

    // Measure UI READ_NEXT acceptance -> published block and ACK -> UI progress.
    always @(posedge u_dut.cmd_read_next) fill_started = $realtime;
    always @(posedge u_dut.block_ready) begin
        loaded_blocks = loaded_blocks + 1;
        filling_total_ns = filling_total_ns + ($realtime - fill_started);
        $display("FMC_FILL block=%0d ready_period=%0d ns=%0.3f", loaded_blocks,
                 DDR_READY_PERIOD, $realtime - fill_started);
    end
    always @(posedge u_dut.ack_accepted) ack_started = $realtime;
    always @(posedge u_dut.read_ready or posedge u_dut.stream_done) begin
        if (loaded_blocks > accepted_acks && !u_dut.block_ready) begin
            accepted_acks = accepted_acks + 1;
            handshake_total_ns = handshake_total_ns + ($realtime - ack_started);
            $display("FMC_ACK block=%0d ns=%0.3f", accepted_acks,
                     $realtime - ack_started);
        end
    end

    task cycle;
        input [2:0] operation;
        input [1:0] selected_bank;
        input [12:0] selected_addr;
        input drive;
        input [15:0] data;
        input [1:0] masks;
        input expected;
        input [15:0] read_value;
        input [15:0] read_mask;
        begin
            @(negedge sdclk); #0.5;
            cs_n = 0; command = operation; bank = selected_bank; addr = selected_addr;
            host_drive = drive; host_data = data; dqm = masks;
            expected_read = expected; expected_data = read_value; expected_mask = read_mask;
            @(posedge sdclk); #1;
            cs_n = 1; command = 3'b111; bank = 0; addr = 0;
            host_drive = 0; dqm = 0; expected_read = 0;
        end
    endtask
    task idle_cycles;
        input integer count;
        integer item;
        begin
            for (item = 0; item < count; item = item + 1)
                cycle(3'b111, 0, 0, 0, 0, 0, 0, 0, 0);
        end
    endtask
    task activate;
        input [12:0] row;
        begin cycle(3'b011, 0, row, 0, 0, 0, 0, 0, 0); idle_cycles(1); end
    endtask
    task write_word;
        input [7:0] column;
        input [15:0] value;
        input [1:0] masks;
        begin cycle(3'b100, 0, {5'b0,column}, 1, value, masks, 0, 0, 0); idle_cycles(2); end
    endtask
    task read_word;
        input [7:0] column;
        input [15:0] value;
        input [15:0] compare_mask;
        begin
            cycle(3'b101, 0, {5'b0,column}, 0, 0, 0, 1, value, compare_mask);
            idle_cycles(5);
        end
    endtask
    task wait_status;
        input [15:0] required_set;
        input [15:0] required_clear;
        begin
            poll_count = 0;
            read_word(8'd2, 0, 0);
            while (((last_read & required_set) != required_set || (last_read & required_clear) != 0) && poll_count < 2000) begin
                read_word(8'd2, 0, 0);
                poll_count = poll_count + 1;
            end
            if (poll_count == 2000) $fatal(1, "STATUS timeout set=%h clear=%h got=%h", required_set, required_clear, last_read);
        end
    endtask
    initial begin
        #103; reset_n = 1;
        idle_cycles(20);
        cycle(3'b010, 0, 13'h400, 0, 0, 0, 0, 0, 0);
        cycle(3'b001, 0, 0, 0, 0, 0, 0, 0, 0);
        cycle(3'b000, 0, 13'h230, 0, 0, 0, 0, 0, 0);
        idle_cycles(2); activate(0);
        read_word(0, 16'hadfc, 16'hffff);
        read_word(1, 16'h0100, 16'hffff);
        // Turnaround immediately after the last legal read-data edge.
        cycle(3'b101, 0, 0, 0, 0, 0, 1, 16'hadfc, 16'hffff);
        idle_cycles(3);
        write_word(8'h13, 16'hc35a, 0);
        read_word(8'h13, 16'hc35a, 16'hffff);
        wait_status(16'h2061, 16'h1810);
        write_word(8'h13, 16'h1234, 0);
        read_word(8'h13, 16'h1234, 16'hffff);
        write_word(8'h13, 16'habcd, 2'b10);
        read_word(8'h13, 16'h12cd, 16'hffff);
        write_word(8'h13, 16'h5678, 2'b01);
        read_word(8'h13, 16'h56cd, 16'hffff);
        // Adjacent SET / START writes must be delivered to UI in order.
        cycle(3'b100, 0, 13'd4, 1, 16'd200, 0, 0, 0, 0);
        cycle(3'b100, 0, 13'd5, 1, 16'd1, 0, 0, 0, 0);
        idle_cycles(8);
        wait_status(16'h208c, 16'h1812);
        if (u_dut.sampled_limit !== 32'd20000000 || u_dut.starts != 1)
            $fatal(1, "SET/START command ordering failed");
        read_word(8'd4, 16'd200, 16'hffff);
        read_word(8'd10, 16'd8232, 16'hffff);
        read_word(8'd11, 0, 16'hffff);
        record_started = $realtime;
        first_fill_start = $realtime;
        write_word(8'd5, 16'd2, 0);
        wait_status(16'h2100, 16'h1a10);
        first_fill_ns = $realtime - first_fill_start;
        read_word(8'd14, 0, 16'hffff);
        read_word(8'd18, 16'd8192, 16'hffff);
        // Full block: deliberately spaced BL1 commands, one halfword per six SDCLK cycles.
        first_read_start = $realtime;
        for (row_number = 0; row_number < 16; row_number = row_number + 1) begin
            activate(13'd16 + row_number);
            for (column_number = 0; column_number < 256; column_number = column_number + 1) begin
                word_number = row_number*256 + column_number;
                read_word(column_number, 16'ha500 ^ word_number, 16'hffff);
            end
            idle_cycles(5);
            cycle(3'b010, 0, 0, 0, 0, 0, 0, 0, 0);
        end
        full_read_ns = $realtime - first_read_start;
        $display("FMC_READ bytes=8192 ns=%0.3f raw_MBps=%0.3f", full_read_ns, 8192.0*1000.0/full_read_ns);
        if (!u_dut.block_ready) $fatal(1, "Reading must not imply ACK");
        activate(0);
        write_word(8'd5, 16'd3, 0);
        wait_status(16'h2080, 16'h1910);
        read_word(8'd3, 16'h0008, 16'h0018);
        second_fill_start = $realtime;
        write_word(8'd5, 16'd2, 0);
        wait_status(16'h2300, 16'h1810);
        second_fill_ns = $realtime - second_fill_start;
        read_word(8'd14, 16'd1, 16'hffff);
        read_word(8'd16, 16'd8192, 16'hffff);
        read_word(8'd18, 16'd40, 16'hffff);
        activate(16);
        second_read_start = $realtime;
        for (column_number = 0; column_number < 20; column_number = column_number + 1)
            read_word(column_number, 16'ha500 ^ (4096+column_number), 16'hffff);
        idle_cycles(5);
        tail_read_ns = $realtime - second_read_start;
        $display("FMC_READ bytes=40 ns=%0.3f", tail_read_ns);
        read_word(20, 16'hdead, 16'hffff);
        activate(0); write_word(8'd5, 16'd5, 0); idle_cycles(40);
        activate(0); write_word(8'd5, 16'd3, 0);
        wait_status(16'h2400, 16'h1910);
        write_word(8'd5, 16'd4, 0);
        wait_status(16'h2061, 16'h191e);
        if (u_dut.releases != 1 || u_dut.read_error || u_dut.protocol_error)
            $fatal(1, "Stream release or protocol error");
        $display("FMC_STREAM bytes=8232 ns=%0.3f blocks=%0d ACKs=%0d fill_ns=%0.3f handshake_ns=%0.3f",
                 $realtime-record_started, loaded_blocks, accepted_acks,
                 filling_total_ns, handshake_total_ns);
        $display("FMC_HOST_OBSERVED first_request_to_poll_ns=%0.3f second_request_to_poll_ns=%0.3f", first_fill_ns, second_fill_ns);
        if (loaded_blocks != 2 || accepted_acks != 2)
            $fatal(1, "Throughput fixture handshake count mismatch");
        // Rejected ACK and invalid SET become sticky errors, explicitly clearable.
        write_word(8'd5, 16'd3, 0);
        read_word(8'd3, 16'h0010, 16'h0010);
        write_word(8'd4, 16'd201, 0);
        read_word(8'd4, 16'd200, 16'hffff);
        write_word(8'd5, 16'd5, 0); idle_cycles(40);
        read_word(8'd3, 0, 16'h007f);
        wait_status(16'h2061, 16'h1810);
        // Illegal tail / unowned cache access must return DEAD, never stale RAM.
        activate(16); read_word(0, 16'hdead, 16'hffff);
        activate(0); write_word(8'd5, 16'd5, 0); idle_cycles(40);
        // Reset must remove FPGA drive asynchronously, including a stopped clock.
        cycle(3'b101, 0, 0, 0, 0, 0, 1, 16'hadfc, 16'hffff);
        idle_cycles(2);
        #1;
        if (dq !== 16'hadfc) $fatal(1, "Reset test did not interrupt an active read");
        reset_n = 0; #2;
        if (dq !== 16'hzzzz) $fatal(1, "DQ not released by reset");
        if (errors != 0) $fatal(1, "Read scoreboard failed: %0d errors", errors);
        $display("FMC_SRCC_PASS checks=%0d phase_ps=%0d half_period_ps=%0d duty_skew_ps=%0d", checks, PHASE_PS, HALF_PERIOD_PS, DUTY_SKEW_PS);
        $finish;
    end
    initial begin #3000000; $fatal(1, "Global timeout"); end
endmodule
`default_nettype wire
