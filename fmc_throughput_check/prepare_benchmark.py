from pathlib import Path

artifact = Path(__file__).resolve().parent
prior = artifact.parent / 'fmc_return_fix'

def replace_once(text, before, after):
    if text.count(before) != 1:
        raise ValueError(f'Unexpected source contract: {before[:90]}')
    return text.replace(before, after, 1)

# Copy the validated testbench into a separate measurement fixture.
# Production RTL and delivered BIT/LTX remain immutable.
bench = (prior / 'sim/tb_fmc_return_window.v').read_text(encoding='utf-8')
bench = replace_once(bench, 'module tb_fmc_return_window;',
                     'module tb_fmc_throughput;\n    parameter integer DDR_READY_PERIOD = 1;')
bench = replace_once(bench, 'fmc_test_system u_dut (',
                     'fmc_throughput_system #(.DDR_READY_PERIOD(DDR_READY_PERIOD)) u_dut (')
bench = replace_once(bench, 'poll_count < 300', 'poll_count < 2000')
bench = replace_once(bench, 'poll_count == 300', 'poll_count == 2000')
bench = replace_once(bench, 'integer word_number;',
                     'integer word_number;\n    realtime first_fill_start;\n    realtime second_fill_start;\n    realtime first_read_start;\n    realtime second_read_start;\n    realtime fill_started;\n    realtime ack_started;\n    realtime last_ack_start;\n    realtime filling_total_ns = 0;\n    realtime handshake_total_ns = 0;\n    realtime first_fill_ns;\n    realtime second_fill_ns;\n    realtime full_read_ns;\n    realtime tail_read_ns;\n    realtime record_started;\n    integer loaded_blocks = 0;\n    integer accepted_acks = 0;')
bench = replace_once(bench, '    task cycle;', '''    // Measure UI READ_NEXT acceptance -> published block and ACK -> UI progress.
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

    task cycle;''')
bench = replace_once(bench, '        write_word(8\'d5, 16\'d2, 0);\n        wait_status(16\'h2100, 16\'h1a10);',
                     '        record_started = $realtime;\n        first_fill_start = $realtime;\n        write_word(8\'d5, 16\'d2, 0);\n        wait_status(16\'h2100, 16\'h1a10);\n        first_fill_ns = $realtime - first_fill_start;')
bench = replace_once(bench, '// Full block: pipelined BL1 commands, one halfword every SDCLK.',
                     '// Full block: deliberately spaced BL1 commands, one halfword per six SDCLK cycles.\n        first_read_start = $realtime;')
bench = replace_once(bench,
                     "cycle(3'b101, 0, column_number, 0, 0, 0, 1, 16'ha500 ^ word_number, 16'hffff);",
                     "read_word(column_number, 16'ha500 ^ word_number, 16'hffff);")
bench = replace_once(bench, '        if (!u_dut.block_ready)',
                     '        full_read_ns = $realtime - first_read_start;\n        $display("FMC_READ bytes=8192 ns=%0.3f raw_MBps=%0.3f", full_read_ns, 8192.0*1000.0/full_read_ns);\n        if (!u_dut.block_ready)')
bench = replace_once(bench, "        write_word(8'd5, 16'd2, 0);\n        wait_status(16'h2300, 16'h1810);",
                     "        second_fill_start = $realtime;\n        write_word(8'd5, 16'd2, 0);\n        wait_status(16'h2300, 16'h1810);\n        second_fill_ns = $realtime - second_fill_start;")
bench = replace_once(bench, '        activate(16);\n        for (column_number = 0; column_number < 20;',
                     '        activate(16);\n        second_read_start = $realtime;\n        for (column_number = 0; column_number < 20;')
bench = replace_once(bench,
                     "cycle(3'b101, 0, column_number, 0, 0, 0, 1, 16'ha500 ^ (4096+column_number), 16'hffff);",
                     "read_word(column_number, 16'ha500 ^ (4096+column_number), 16'hffff);")
bench = replace_once(bench, "        read_word(20, 16'hdead, 16'hffff);",
                     "        tail_read_ns = $realtime - second_read_start;\n        $display(\"FMC_READ bytes=40 ns=%0.3f\", tail_read_ns);\n        read_word(20, 16'hdead, 16'hffff);")
bench = replace_once(bench, "        // Rejected ACK and invalid SET become sticky errors, explicitly clearable.",
                     '''        $display("FMC_STREAM bytes=8232 ns=%0.3f blocks=%0d ACKs=%0d fill_ns=%0.3f handshake_ns=%0.3f",
                 $realtime-record_started, loaded_blocks, accepted_acks,
                 filling_total_ns, handshake_total_ns);
        $display("FMC_HOST_OBSERVED first_request_to_poll_ns=%0.3f second_request_to_poll_ns=%0.3f", first_fill_ns, second_fill_ns);
        if (loaded_blocks != 2 || accepted_acks != 2)
            $fatal(1, "Throughput fixture handshake count mismatch");
        // Rejected ACK and invalid SET become sticky errors, explicitly clearable.''')
bench = replace_once(bench, '#1000000; $fatal', '#3000000; $fatal')
(artifact / 'tb_fmc_throughput.v').write_text(bench, encoding='utf-8')

# DDR command readiness is deliberately throttled; read responses are delayed
# by 32 UI cycles. Real production reader and real XPM RAM remain unchanged.
system = (prior / 'sim/reference/fmc_test_system.v').read_text(encoding='utf-8')
system = replace_once(system, 'module fmc_test_system (',
                      'module fmc_throughput_system #(parameter integer DDR_READY_PERIOD = 1) (')
system = replace_once(system, '    reg [2:0] response_valid;\n    reg [255:0] response_first, response_second, response_third;',
                      '    reg [31:0] response_valid;\n    reg [255:0] response_data [0:31];\n    integer pipeline_stage;\n    integer ready_phase;\n    wire app_ready = ready_phase == 0;')
system = replace_once(system, ".app_rdy(1'b1)", '.app_rdy(app_ready)')
system = replace_once(system, '.app_rd_data(response_third), .app_rd_data_valid(response_valid[2])',
                      '.app_rd_data(response_data[31]), .app_rd_data_valid(response_valid[31])')
system = replace_once(system, '            response_valid <= 0;\n            response_first <= 0; response_second <= 0; response_third <= 0;',
                      '            response_valid <= 0;\n            ready_phase <= 0;\n            for (pipeline_stage = 0; pipeline_stage < 32; pipeline_stage = pipeline_stage + 1)\n                response_data[pipeline_stage] <= 0;')
system = replace_once(system, '            response_valid <= {response_valid[1:0], app_en};\n            response_second <= response_first;\n            response_third <= response_second;\n            if (app_en) begin',
                      '            if (ready_phase == DDR_READY_PERIOD-1) ready_phase <= 0;\n            else ready_phase <= ready_phase + 1;\n            response_valid <= {response_valid[30:0], app_en && app_ready};\n            for (pipeline_stage = 1; pipeline_stage < 32; pipeline_stage = pipeline_stage + 1)\n                response_data[pipeline_stage] <= response_data[pipeline_stage-1];\n            if (app_en && app_ready) begin')
system = replace_once(system, 'response_first[halfword*16 +: 16]', 'response_data[0][halfword*16 +: 16]')
(artifact / 'fmc_throughput_system.v').write_text(system, encoding='utf-8')

for mode, period in [('ready', 1), ('throttled', 16)]:
    (artifact / f'tb_fmc_throughput_{mode}.v').write_text(
        '`timescale 1ns/1ps\n`default_nettype none\n'
        f'module tb_fmc_throughput_{mode};\n'
        f'    tb_fmc_throughput #(.DDR_READY_PERIOD({period}), .PHASE_PS(0), .DUTY_SKEW_PS(2976)) u_test();\n'
        'endmodule\n`default_nettype wire\n', encoding='utf-8')

print('Created measurement fixtures only; no production source or BIT changed.')
