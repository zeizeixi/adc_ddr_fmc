from pathlib import Path
ROOT=Path(__file__).resolve().parent
SRC=Path(r"./local_inputs/rtl")
s=(SRC/"fmc_record_link.v").read_text(encoding="utf-8")
def sub(a,b):
    global s
    if a not in s: raise RuntimeError(a[:80])
    s=s.replace(a,b)
sub("output wire [31:0] cfg_samples,", """output wire [31:0] cfg_samples,
    output reg [6:0] cfg_pre_percent,
    output reg cfg_auto_mode,
    output reg [1:0] cfg_trigger_enable,
    output reg [11:0] cfg_threshold_a,
    output reg [11:0] cfg_threshold_b,
    output reg cmd_arm,
    output reg cmd_force,
    output reg cmd_abort,
    input wire trigger_armed,
    input wire history_ready,
    input wire trigger_seen,
    input wire capture_aborted,
    input wire [2:0] trigger_reason,
    input wire [31:0] record_pre_samples,""")
sub("reg [15:0] duration_ui;", """reg [31:0] samples_ui;
    reg [31:0] samples_fmc;
    reg [6:0] percent_fmc;
    reg auto_fmc;
    reg [1:0] enable_fmc;
    reg [11:0] threshold_a_fmc;
    reg [11:0] threshold_b_fmc;
    reg length_mode_fmc;""")
sub("bus_wdata <= 5", "bus_wdata <= 8")
sub("wire enqueue = bus_write && (duration_write || queued_command);", """
    wire extension_address = bus_addr>=24'h000028 && bus_addr<=24'h000034 && !bus_addr[0];
    wire extension_value_ok =
        (bus_addr==24'h000028 || bus_addr==24'h00002a) ||
        (bus_addr==24'h00002c && bus_wdata<=100) ||
        (bus_addr==24'h00002e && bus_wdata<=1) ||
        ((bus_addr==24'h000030 || bus_addr==24'h000032) && bus_wdata<=4095) ||
        (bus_addr==24'h000034 && bus_wdata<=3);
    wire extension_write=extension_address && bus_mask==0 && extension_value_ok;
    wire enqueue = bus_write && (duration_write || queued_command || extension_write);""")
sub("wire [127:0] snapshot_data;", "wire [255:0] snapshot_data;")
sub("wire [127:0] snapshot_source = {11'b0,", """wire [15:0] trigger_flags={8'b0,trigger_reason,capture_aborted,
        (busy && trigger_seen),trigger_seen,history_ready,trigger_armed};
    wire [255:0] snapshot_source = {64'b0,record_pre_samples,trigger_flags,16'b0,11'b0,""")
sub("assign cfg_samples = duration_ui * 32'd100000;", "assign cfg_samples = samples_ui;")
sub("cdc_mailbox #(.WIDTH(128)) u_status_mail", "cdc_mailbox #(.WIDTH(256)) u_status_mail")
sub("16'h0100", "16'h0200")
sub("24'h000026: register_data = scratch;", """24'h000026: register_data = scratch;
                24'h000028: register_data = samples_fmc[15:0];
                24'h00002a: register_data = samples_fmc[31:16];
                24'h00002c: register_data = {9'b0,percent_fmc};
                24'h00002e: register_data = {15'b0,auto_fmc};
                24'h000030: register_data = {4'b0,threshold_a_fmc};
                24'h000032: register_data = {4'b0,threshold_b_fmc};
                24'h000034: register_data = {14'b0,enable_fmc};
                24'h000036: register_data = snapshot_data[159:144];
                24'h000038: register_data = snapshot_data[175:160];
                24'h00003a: register_data = snapshot_data[191:176];
                24'h00003c: register_data = 16'he100; // 100000000 Hz low
                24'h00003e: register_data = 16'h05f5; // 100000000 Hz high
                24'h000040: register_data = {15'b0,length_mode_fmc};""")
sub("duration_fmc <= 1;", """duration_fmc <= 1;
            samples_fmc <= 100000;
            percent_fmc <= 0;
            auto_fmc <= 0;
            enable_fmc <= 3;
            threshold_a_fmc <= 4095;
            threshold_b_fmc <= 4095;
            length_mode_fmc <= 0;""")
sub("if (duration_write && enqueue_ready) duration_fmc <= bus_wdata;", """if (duration_write && enqueue_ready) begin
                        duration_fmc <= bus_wdata;
                        samples_fmc <= bus_wdata * 32'd100000;
                        length_mode_fmc <= 0;
                    end""")
sub("end else if (command_address) begin", """end else if (extension_address) begin
                    if (extension_write && enqueue_ready) begin
                        case(bus_addr)
                            24'h000028: begin samples_fmc[15:0]<=bus_wdata; length_mode_fmc<=1; duration_fmc<=0; end
                            24'h00002a: begin samples_fmc[31:16]<=bus_wdata; length_mode_fmc<=1; duration_fmc<=0; end
                            24'h00002c: percent_fmc<=bus_wdata[6:0];
                            24'h00002e: auto_fmc<=bus_wdata[0];
                            24'h000030: threshold_a_fmc<=bus_wdata[11:0];
                            24'h000032: threshold_b_fmc<=bus_wdata[11:0];
                            24'h000034: enable_fmc<=bus_wdata[1:0];
                        endcase
                    end else local_error_fmc<=1;
                end else if (command_address) begin""")
sub("duration_ui <= 1;", """samples_ui <= 100000;
            cfg_pre_percent <= 0;
            cfg_auto_mode <= 0;
            cfg_trigger_enable <= 3;
            cfg_threshold_a <= 4095;
            cfg_threshold_b <= 4095;
            cmd_arm <= 0;
            cmd_force <= 0;
            cmd_abort <= 0;""")
# Default command pulses each cycle, including reset.
sub("cmd_read_next_o <= 0;", "cmd_read_next_o <= 0;\n            cmd_arm <= 0; cmd_force <= 0; cmd_abort <= 0;")
sub("if (queued_addr == 24'h000008) duration_ui <= queued_data;", """if (queued_addr == 24'h000008) samples_ui <= queued_data * 32'd100000;
                else if (queued_addr==24'h000028) samples_ui[15:0]<=queued_data;
                else if (queued_addr==24'h00002a) samples_ui[31:16]<=queued_data;
                else if (queued_addr==24'h00002c) cfg_pre_percent<=queued_data[6:0];
                else if (queued_addr==24'h00002e) cfg_auto_mode<=queued_data[0];
                else if (queued_addr==24'h000030) cfg_threshold_a<=queued_data[11:0];
                else if (queued_addr==24'h000032) cfg_threshold_b<=queued_data[11:0];
                else if (queued_addr==24'h000034) cfg_trigger_enable<=queued_data[1:0];""")
sub("if (ready && read_idle) cmd_start_o <= 1;", "if (ready && read_idle && !cfg_auto_mode && cfg_pre_percent==0) cmd_start_o <= 1;")
sub("default: local_error_ui <= 1;", """16'd6: begin
                            if (ready && read_idle) cmd_arm<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        16'd7: begin
                            if (trigger_armed && history_ready) cmd_force<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        16'd8: begin
                            if (busy) cmd_abort<=1;
                            else begin local_error_ui<=1; events_ui[1]<=1; end
                        end
                        default: local_error_ui <= 1;""")
(ROOT/"rtl/fmc_record_link.v").write_text(s,encoding="utf-8")

# Board top is a reference integration built from the prior delivered source.
s=(SRC/"adc_ddr_fbg484_top.v").read_text(encoding="utf-8",errors="replace")
def sub(a,b):
    global s
    if a not in s: raise RuntimeError(a[:80])
    s=s.replace(a,b)
sub("wire [31:0] vio_cfg_samples, fmc_cfg_samples;", """wire [6:0] fmc_pre_percent;
    wire fmc_auto_mode;
    wire [1:0] fmc_trigger_enable;
    wire [11:0] fmc_threshold_a;
    wire [11:0] fmc_threshold_b;
    wire fmc_arm;
    wire fmc_force;
    wire fmc_abort;
    wire trigger_armed;
    wire history_ready;
    wire trigger_seen;
    wire capture_aborted;
    wire [2:0] trigger_reason;
    wire [31:0] record_pre_samples;
    wire [31:0] vio_cfg_samples, fmc_cfg_samples;""")
# Insert into store instance by exact cfg_samples connection.
import re
matches=list(re.finditer(r'\.cfg_samples\s*\(cfg_samples\s*\),',s))
if len(matches)!=1: raise RuntimeError("top store cfg_samples not unique")
m=matches[0]
s=s[:m.end()]+"""
        .cfg_pre_percent(FMC_CONTROL ? fmc_pre_percent : 7'd0),
        .cfg_auto_mode(FMC_CONTROL ? fmc_auto_mode : 1'b0),
        .cfg_trigger_enable(FMC_CONTROL ? fmc_trigger_enable : 2'b00),
        .cfg_threshold_a(fmc_threshold_a),
        .cfg_threshold_b(fmc_threshold_b),
        .cmd_arm(FMC_CONTROL && fmc_arm),
        .cmd_force(FMC_CONTROL && fmc_force),
        .cmd_abort(FMC_CONTROL && fmc_abort),
        .trigger_armed(trigger_armed),
        .history_ready(history_ready),
        .trigger_seen(trigger_seen),
        .capture_aborted(capture_aborted),
        .trigger_reason(trigger_reason),
        .record_pre_samples(record_pre_samples),
""" + s[m.end():]
sub(".cfg_samples(fmc_cfg_samples),", """.cfg_samples(fmc_cfg_samples),
        .cfg_pre_percent(fmc_pre_percent),
        .cfg_auto_mode(fmc_auto_mode),
        .cfg_trigger_enable(fmc_trigger_enable),
        .cfg_threshold_a(fmc_threshold_a),
        .cfg_threshold_b(fmc_threshold_b),
        .cmd_arm(fmc_arm),
        .cmd_force(fmc_force),
        .cmd_abort(fmc_abort),
        .trigger_armed(trigger_armed),
        .history_ready(history_ready),
        .trigger_seen(trigger_seen),
        .capture_aborted(capture_aborted),
        .trigger_reason(trigger_reason),
        .record_pre_samples(record_pre_samples),""")
(ROOT/"rtl/adc_ddr_fbg484_top.v").write_text(s,encoding="utf-8")
print("Generated FMC register extension and board top")

