from pathlib import Path
ROOT=Path(__file__).resolve().parent
SRC=Path(r"./local_inputs/rtl")
s=(SRC/"ddr_block_reader.v").read_text(encoding="utf-8")
s=s.replace("input wire record_done,record_valid,input wire [31:0] record_bytes,", """input wire record_done,record_valid,input wire [31:0] record_bytes,
    input wire [31:0] record_start_sample,
    input wire [31:0] record_ring_samples,""")
s=s.replace("reg [8:0] goal,issued,received;", """
    reg [255:0] burst_data;
    reg burst_loaded;
    reg read_pending;
    reg [2:0] source_lane;
    reg [2:0] output_lane;
    reg [255:0] output_pack;
    reg [255:0] assembled_pack;
    reg [11:0] copied_pairs;
    reg [11:0] goal_pairs;
    reg [7:0] write_index;
    wire [31:0] logical_start=record_start_sample+(next_offset>>2);
    wire [31:0] physical_start=logical_start>=record_ring_samples ?
                                  logical_start-record_ring_samples : logical_start;""")
s=s.replace("assign app_en=state==FILL && issued<goal && init_calib_complete && !protocol_error && !rst;", """assign app_en=state==FILL && !burst_loaded && !read_pending &&
        copied_pairs<goal_pairs && init_calib_complete && !protocol_error && !rst;""")
s=s.replace("wire response_expected=state==FILL && received<goal && (received<issued || issue);", "wire response_expected=state==FILL && !burst_loaded && (read_pending || issue);")
s=s.replace("wire store=app_rd_data_valid && app_rd_data_end && response_expected && !protocol_error && !rst;", """
    wire copy_pair=state==FILL && burst_loaded && !protocol_error && !rst;
    wire store=copy_pair && (output_lane==7 || copied_pairs==goal_pairs-1);
    always @(*) begin
        assembled_pack=output_pack;
        assembled_pack[output_lane*32 +: 32]=burst_data[source_lane*32 +: 32];
    end""")
s=s.replace(".wr_addr(received[7:0]),.wr_data(app_rd_data)", ".wr_addr(write_index),.wr_data(assembled_pack)")
begin=s.index("    always @(posedge ui_clk) begin")
s=s[:begin]+"""
    // One outstanding MIG read at a time; consume/repack each 32-bit sample pair.
    // This handles ring wrap and arbitrary trigger alignment inside a 256-bit burst.
    always @(posedge ui_clk) begin
        if (rst) begin
            state<=IDLE; next_offset<=0; index_q<=0; bytes_q<=0; last_q<=0;
            addr_q<=BASE_APP_ADDR; cmd_d<=0; desc_send<=0;
            read_accepted<=0; command_rejected<=0; stream_done<=0; protocol_error<=0;
            burst_data<=0; burst_loaded<=0; read_pending<=0;
            source_lane<=0; output_lane<=0; output_pack<=0;
            copied_pairs<=0; goal_pairs<=0; write_index<=0;
        end else begin
            cmd_d<=cmd_read_next; desc_send<=0; read_accepted<=0; command_rejected<=0;
            if (cmd_read_next && !cmd_d) command_rejected<=1;
            if (stream_clear && idle) begin
                next_offset<=0; index_q<=0; stream_done<=0;
            end
            case (state)
                IDLE: if (cmd_read_next && !cmd_d && read_ready) begin
                    bytes_q<=requested_bytes[13:0]; last_q<=remaining<=8192;
                    goal_pairs<=requested_bytes>>2; copied_pairs<=0;
                    source_lane<=physical_start[2:0]; output_lane<=0;
                    output_pack<=0; write_index<=0;
                    burst_loaded<=0; read_pending<=0;
                    addr_q<=BASE_APP_ADDR+((physical_start>>3)<<3);
                    state<=FILL; read_accepted<=1; command_rejected<=0;
                end
                FILL: begin
                    if (issue) read_pending<=1;
                    if (app_rd_data_valid && app_rd_data_end && response_expected) begin
                        burst_data<=app_rd_data;
                        burst_loaded<=1;
                        read_pending<=0;
                    end
                    if (copy_pair) begin
                        copied_pairs<=copied_pairs+1'b1;
                        if (store) begin
                            write_index<=write_index+1'b1;
                            output_lane<=0;
                            output_pack<=0;
                        end else begin
                            output_lane<=output_lane+1'b1;
                            output_pack<=assembled_pack;
                        end
                        if (source_lane==7) begin
                            source_lane<=0;
                            burst_loaded<=0;
                            if (addr_q==BASE_APP_ADDR+record_ring_samples-8)
                                addr_q<=BASE_APP_ADDR;
                            else addr_q<=addr_q+8;
                        end else source_lane<=source_lane+1'b1;
                        if (copied_pairs==goal_pairs-1) begin
                            burst_loaded<=0;
                            state<=PUBLISH;
                        end
                    end
                end
                PUBLISH: if (!desc_busy) begin
                    desc_send<=1;
                    state<=WAIT_ACK;
                end
                WAIT_ACK: if (ack_valid) begin
                    if (ack_dst==index_q) begin
                        next_offset<=next_offset+bytes_q;
                        index_q<=index_q+1;
                        stream_done<=last_q;
                        state<=IDLE;
                    end else begin
                        protocol_error<=1;
                        state<=FAULT;
                    end
                end
                FAULT: begin end
                default: begin protocol_error<=1; state<=FAULT; end
            endcase
            if ((app_rd_data_valid && (!response_expected || !app_rd_data_end)) ||
                consumer_fault_ui || (stream_clear && !idle)) begin
                protocol_error<=1;
                state<=FAULT;
            end
        end
    end
endmodule
`default_nettype wire
"""
(ROOT/"rtl/ddr_block_reader.v").write_text(s,encoding="utf-8")
# Race-safe cancel: a UI-accepted abort cancels a finishing capture even if ADC result is already in flight.
p=ROOT/"rtl/adc_capture_runtime.v"
s=p.read_text(encoding="utf-8")
s=s.replace("reg launch_settled;", "reg launch_settled;\n    reg abort_pending;")
s=s.replace("!control_busy && !control_send;", "!control_busy && !control_send && !geometry_busy && !geometry_start && !geometry_done;")
s=s.replace("launch_settled<=0; capture_aborted<=0;", "launch_settled<=0; capture_aborted<=0; abort_pending<=0;")
s=s.replace("capture_aborted<=0; trigger_reason<=0; record_start_sample<=0;", "capture_aborted<=0; abort_pending<=0; trigger_reason<=0; record_start_sample<=0;")
s=s.replace("control_send<=1; control_data<=2'b10; command_rejected<=0;", "control_send<=1; control_data<=2'b10; command_rejected<=0; abort_pending<=1;")
s=s.replace("capture_aborted<=result_q[67];", "capture_aborted<=result_q[67] || abort_pending || cmd_abort;")
s=s.replace("if (result_q[67]) begin", "if (result_q[67] || abort_pending || cmd_abort) begin")
p.write_text(s,encoding="utf-8")
print("Generated sample-aligned ring reader")

