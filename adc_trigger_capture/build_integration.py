from pathlib import Path
import shutil
ROOT = Path(__file__).resolve().parent
SRC = Path(r"./local_inputs/rtl")
RTL = ROOT / "rtl"
RTL.mkdir(exist_ok=True)
def get(name):
    return (SRC / name).read_text(encoding="utf-8", errors="replace")
def put(name, text):
    (RTL / name).write_text(text, encoding="utf-8")
def replace(text, before, after):
    if before not in text:
        raise RuntimeError("Missing expected baseline fragment: " + before[:100])
    return text.replace(before, after)
# These support modules are references only; installation keeps the user's existing copies.
REF = ROOT / "reference"
REF.mkdir(exist_ok=True)
for name in ("cdc_mailbox.v", "level_sync.v", "reset_sync.v", "ram256x16_8k.v",
             "ads62p24_init.v", "readout_debug.v", "adc_clock_forward_7series.v"):
    (REF/name).write_text(get(name), encoding="utf-8")
# Circular writer: one MIG burst = eight 32-bit A/B pairs.
s=get("mig_write_runtime.v")
s=replace(s, "input wire clk, rst, clear, enable,", "input wire clk, rst, clear, enable,\n    input wire [31:0] ring_samples,")
s=replace(s, "addr_q<=addr_q+8;", "if (addr_q == BASE_APP_ADDR + ring_samples - 8) addr_q<=BASE_APP_ADDR;\n                else addr_q<=addr_q+8;")
put("mig_write_runtime.v", s)
# Capture manager: preserve existing initialization/FIFO/reset hierarchy.
s=get("adc_capture_runtime.v")
s=replace(s, "input wire [31:0] cfg_samples, input wire cmd_start, cmd_release,", """
    input wire [31:0] cfg_samples,
    input wire [6:0] cfg_pre_percent,
    input wire cfg_auto_mode,
    input wire [1:0] cfg_trigger_enable,
    input wire [11:0] cfg_threshold_a,
    input wire [11:0] cfg_threshold_b,
    input wire cmd_start,
    input wire cmd_arm,
    input wire cmd_force,
    input wire cmd_abort,
    input wire cmd_release,
    output wire trigger_armed,
    output wire history_ready,
    output wire trigger_seen,
    output reg capture_aborted,
    output reg [2:0] trigger_reason,
    output reg [31:0] record_start_sample,
    output wire [31:0] record_ring_samples,
    output wire [31:0] record_pre_samples,""")
s=replace(s, "wire [31:0] samples_adc;", """
    wire [123:0] config_adc;
    reg [11:0] threshold_a_q;
    reg [11:0] threshold_b_q;
    reg auto_q;
    reg [1:0] trigger_enable_q;
    reg immediate_q;
    reg [6:0] percent_q;
    reg geometry_start;
    wire geometry_busy;
    wire geometry_done;
    wire [31:0] pre_q;
    wire [31:0] ring_q;
    trigger_geometry u_geometry (
        .clk(ui_clk), .rst(rst), .start(geometry_start),
        .samples(latched_samples), .percent(percent_q),
        .busy(geometry_busy), .done(geometry_done),
        .pre_samples(pre_q), .ring_samples(ring_q)
    );
    assign record_ring_samples = ring_q;
    assign record_pre_samples = pre_q;
    reg control_send;
    reg [1:0] control_data;
    wire control_busy;
    wire control_valid;
    wire [1:0] control_adc;
    cdc_mailbox #(.WIDTH(2)) u_control_mail (
        .src_clk(ui_clk), .src_rst(rst), .src_send(control_send),
        .src_data(control_data), .src_busy(control_busy),
        .dst_clk(adc_clk), .dst_rst(adc_rst),
        .dst_valid(control_valid), .dst_data(control_adc)
    );""")
s=replace(s, "cdc_mailbox #(.WIDTH(32)) u_start_mail", "cdc_mailbox #(.WIDTH(124)) u_start_mail")
s=replace(s, ".src_data(latched_samples)", ".src_data({latched_samples,pre_q,ring_q,threshold_a_q,threshold_b_q,auto_q,trigger_enable_q,immediate_q})")
s=replace(s, ".dst_data(samples_adc)", ".dst_data(config_adc)")
s=replace(s, "wire [64:0] result_adc, result_ui;", "wire [68:0] result_adc, result_ui;")
s=replace(s, ".sample_limit(samples_adc),", """.sample_limit(config_adc[123:92]),
        .pre_samples(config_adc[91:60]), .ring_samples(config_adc[59:28]),
        .threshold_a(config_adc[27:16]), .threshold_b(config_adc[15:4]),
        .auto_mode(config_adc[3]), .trigger_enable(config_adc[2:1]), .immediate(config_adc[0]),
        .force_trigger(control_valid && control_adc[0]),
        .abort_capture(control_valid && control_adc[1]),
        .history_ready(history_adc), .triggered(triggered_adc),""")
s=replace(s, "wire pack_idle, pack_error, result_send, result_busy, result_valid;", """
    wire pack_idle, pack_error, result_send, result_busy, result_valid;
    wire history_adc, triggered_adc, history_ui, triggered_ui;
    level_sync u_history(.clk(ui_clk),.rst(rst),.async_in(history_adc),.sync_out(history_ui));
    level_sync u_trigger(.clk(ui_clk),.rst(rst),.async_in(triggered_adc),.sync_out(triggered_ui));""")
s=replace(s, "cdc_mailbox #(.WIDTH(65)) u_result_mail", "cdc_mailbox #(.WIDTH(69)) u_result_mail")
s=replace(s, "localparam IDLE=0, RUN=1, HOLD=2;", "localparam IDLE=0, RUN=1, HOLD=2, PREP=3;")
s=replace(s, "reg [64:0] result_q;", "reg [68:0] result_q;")
s=replace(s, "reg start_d,release_d,writer_clear,have_result;", "reg start_d,arm_d,release_d,writer_clear,have_result;")
s=replace(s, "wire release_edge=cmd_release && !release_d;", """
    wire release_edge=cmd_release && !release_d;
    wire arm_edge=cmd_arm && !arm_d;
    wire options_valid=cfg_samples>=1 && cfg_samples<=MAX_SAMPLES &&
        cfg_pre_percent<=100 && (!cfg_auto_mode || cfg_trigger_enable!=0);
    reg launch_settled;
    assign trigger_armed=state==RUN && launch_settled && !triggered_ui;
    assign history_ready=trigger_armed && history_ui && !pack_idle_ui && !control_busy && !control_send;
    assign trigger_seen=state!=IDLE && launch_settled && triggered_ui;
""")
s=replace(s, "!pack_idle_ui && !start_mail_busy", "!pack_idle_ui && !start_mail_busy")
s=replace(s, "!start_mail_busy && !writer_clear;", "!start_mail_busy && !writer_clear && !control_busy && !control_send && !result_busy;")
# result_busy is ADC domain: avoid direct crossing in ready cone, pack_idle guarantees report handshake completion.
s=s.replace(" && !result_busy;", ";")
s=replace(s, "assign busy=state==RUN;", "assign busy=state==RUN || state==PREP;")
s=replace(s, ".clk(ui_clk),.rst(rst),.clear(writer_clear),.enable(state==RUN && init_calib_complete),", ".clk(ui_clk),.rst(rst),.clear(writer_clear),.enable(state==RUN && init_calib_complete),\n        .ring_samples(ring_q),")
# Replace the manager process only, keeping ready guard process.
begin=s.index("    always @(posedge ui_clk) begin\n        if(rst) begin\n            state")
end=s.index("    // synthesis translate_off",begin)
s=s[:begin]+"""
    always @(posedge ui_clk) begin
        if (rst) begin
            state<=IDLE;
            start_d<=0; arm_d<=0; release_d<=0;
            send_start<=0; writer_clear<=0; geometry_start<=0;
            start_accepted<=0; command_rejected<=0;
            record_done<=0; record_valid<=0;
            have_result<=0; result_q<=0; overflow_latched<=0;
            latched_samples<=0; record_samples<=0; record_bytes<=0;
            percent_q<=0; threshold_a_q<=0; threshold_b_q<=0;
            auto_q<=0; trigger_enable_q<=0; immediate_q<=0;
            control_send<=0; control_data<=0;
            launch_settled<=0; capture_aborted<=0;
            trigger_reason<=0; record_start_sample<=0;
        end else begin
            start_d<=cmd_start; arm_d<=cmd_arm; release_d<=cmd_release;
            send_start<=0; writer_clear<=0; geometry_start<=0; control_send<=0;
            start_accepted<=0; command_rejected<=0;
            if (start_edge || arm_edge || release_edge || cmd_force || cmd_abort)
                command_rejected<=1;
            case (state)
                IDLE: if ((start_edge ^ arm_edge) && !release_edge && !cmd_force &&
                          !cmd_abort && ready && options_valid &&
                          (!start_edge || (!cfg_auto_mode && cfg_pre_percent==0))) begin
                    latched_samples<=cfg_samples; percent_q<=cfg_pre_percent;
                    threshold_a_q<=cfg_threshold_a; threshold_b_q<=cfg_threshold_b;
                    auto_q<=cfg_auto_mode; trigger_enable_q<=cfg_trigger_enable;
                    immediate_q<=start_edge;
                    geometry_start<=1; writer_clear<=1;
                    have_result<=0; overflow_latched<=0; launch_settled<=0;
                    record_done<=0; record_valid<=0; record_samples<=0; record_bytes<=0;
                    capture_aborted<=0; trigger_reason<=0; record_start_sample<=0;
                    state<=PREP; start_accepted<=1; command_rejected<=0;
                end
                PREP: begin
                    if (cmd_abort && !cmd_force) begin
                        capture_aborted<=1;
                        command_rejected<=0;
                        state<=IDLE;
                    end else if (geometry_done) begin
                        send_start<=1;
                        state<=RUN;
                    end
                end
                RUN: begin
                    if (!start_mail_busy && !pack_idle_ui) launch_settled<=1;
                    if (!pack_idle_ui && launch_settled && error_ui) overflow_latched<=1;
                    if (!control_busy && !control_send && launch_settled && !pack_idle_ui) begin
                        if (cmd_abort && !cmd_force) begin
                            control_send<=1; control_data<=2'b10; command_rejected<=0;
                        end else if (cmd_force && !cmd_abort && !auto_q && history_ready) begin
                            control_send<=1; control_data<=2'b01; command_rejected<=0;
                        end
                    end
                    if (result_valid) begin
                        result_q<=result_ui; have_result<=1;
                        overflow_latched<=result_ui[68];
                    end
                    if (have_result && submitted_blocks==result_q[31:0] && writer_idle && empty) begin
                        capture_aborted<=result_q[67];
                        trigger_reason<=result_q[66:64];
                        record_start_sample<=result_q[63:32];
                        if (result_q[67]) begin
                            state<=IDLE;
                            writer_clear<=1;
                        end else begin
                            record_done<=1;
                            record_valid<=!result_q[68];
                            record_samples<=result_q[68] ? 0 : latched_samples;
                            record_bytes<=result_q[68] ? 0 : (latched_samples<<2);
                            state<=HOLD;
                        end
                    end
                end
                HOLD: if (release_edge && !start_edge && !arm_edge) begin
                    state<=IDLE; writer_clear<=1; record_done<=0; record_valid<=0;
                    have_result<=0; record_samples<=0; record_bytes<=0; overflow_latched<=0;
                    launch_settled<=0; command_rejected<=0;
                end
                default: state<=IDLE;
            endcase
        end
    end
""" +s[end:]
put("adc_capture_runtime.v",s)
# Wrapper ports and routing, retaining the established hierarchy.
s=get("adc_record_store.v")
s=replace(s,"input wire [31:0] cfg_samples,input wire cmd_start,cmd_release,cmd_read_next,", """
    input wire [31:0] cfg_samples,
    input wire [6:0] cfg_pre_percent,
    input wire cfg_auto_mode,
    input wire [1:0] cfg_trigger_enable,
    input wire [11:0] cfg_threshold_a,
    input wire [11:0] cfg_threshold_b,
    input wire cmd_arm,cmd_force,cmd_abort,
    output wire trigger_armed,history_ready,trigger_seen,capture_aborted,
    output wire [2:0] trigger_reason,
    output wire [31:0] record_pre_samples,
    input wire cmd_start,cmd_release,cmd_read_next,""")
s=replace(s,"wire rst,rd_rst;", """wire rst,rd_rst;
    wire [31:0] record_start_sample;
    wire [31:0] record_ring_samples;""")
s=replace(s,".cfg_samples(cfg_samples),", """.cfg_samples(cfg_samples),
        .cfg_pre_percent(cfg_pre_percent),.cfg_auto_mode(cfg_auto_mode),
        .cfg_trigger_enable(cfg_trigger_enable),.cfg_threshold_a(cfg_threshold_a),.cfg_threshold_b(cfg_threshold_b),
        .cmd_arm(cmd_arm && read_idle),.cmd_force(cmd_force),.cmd_abort(cmd_abort),
        .trigger_armed(trigger_armed),.history_ready(history_ready),.trigger_seen(trigger_seen),
        .capture_aborted(capture_aborted),.trigger_reason(trigger_reason),
        .record_start_sample(record_start_sample),.record_ring_samples(record_ring_samples),
        .record_pre_samples(record_pre_samples),""")
s=replace(s,".record_bytes(record_bytes),.cmd_read_next(read_forward),", """.record_bytes(record_bytes),.cmd_read_next(read_forward),
        .record_start_sample(record_start_sample),.record_ring_samples(record_ring_samples),""")
put("adc_record_store.v",s)
print("Generated writer, manager and wrapper")

