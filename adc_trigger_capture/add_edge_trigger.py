from pathlib import Path
R=Path(__file__).parent
def edit(name, replacements):
    p=R/'rtl'/name;s=p.read_text(encoding='utf-8')
    for old,new in replacements:
        if old not in s:raise RuntimeError((name,old))
        s=s.replace(old,new)
    p.write_text(s,encoding='utf-8')
edit('ads62p24_pack_runtime.v',[
('    input wire auto_mode,','    input wire [1:0] trigger_type_a, // 0：电平超限；1：上升越阈；2：下降越阈。\n    input wire [1:0] trigger_type_b,\n    input wire auto_mode,'),
('    reg auto_q;','    reg [1:0] type_a_q;\n    reg [1:0] type_b_q;\n    reg previous_valid;\n    reg previous_above_a;\n    reg previous_above_b;\n    reg auto_q;'),
('    wire hit_a = enable_q[0] && adc_a_corrected >= threshold_a_q;\n    wire hit_b = enable_q[1] && adc_b_corrected >= threshold_b_q;',
'''    wire above_a = adc_a_corrected >= threshold_a_q;
    wire above_b = adc_b_corrected >= threshold_b_q;
    // 等于阈值归入高侧。边沿必须由本次 ARM 后的两个相邻样本构成。
    wire hit_a = enable_q[0] && (
        (type_a_q == 0 && above_a) ||
        (type_a_q == 1 && previous_valid && !previous_above_a && above_a) ||
        (type_a_q == 2 && previous_valid && previous_above_a && !above_a));
    wire hit_b = enable_q[1] && (
        (type_b_q == 0 && above_b) ||
        (type_b_q == 1 && previous_valid && !previous_above_b && above_b) ||
        (type_b_q == 2 && previous_valid && previous_above_b && !above_b));'''),
('            auto_q <= 0;','            type_a_q <= 0;\n            type_b_q <= 0;\n            previous_valid <= 0;\n            previous_above_a <= 0;\n            previous_above_b <= 0;\n            auto_q <= 0;'),
('                    auto_q <= auto_mode;','                    type_a_q <= trigger_type_a;\n                    type_b_q <= trigger_type_b;\n                    previous_valid <= 0;\n                    previous_above_a <= 0;\n                    previous_above_b <= 0;\n                    auto_q <= auto_mode;'),
('                CAPTURE: begin','                CAPTURE: begin\n                    previous_valid <= 1;\n                    previous_above_a <= above_a;\n                    previous_above_b <= above_b;')])
for name in ['adc_capture_runtime.v','adc_record_store.v']:
    edit(name,[('    input wire cfg_auto_mode,','    input wire [1:0] cfg_trigger_type_a,\n    input wire [1:0] cfg_trigger_type_b,\n    input wire cfg_auto_mode,')])
edit('adc_capture_runtime.v',[
('wire [123:0] config_adc;','wire [127:0] config_adc;'),
('    reg auto_q;','    reg [1:0] type_a_q;\n    reg [1:0] type_b_q;\n    reg auto_q;'),
('cdc_mailbox #(.WIDTH(124)) u_start_mail','cdc_mailbox #(.WIDTH(128)) u_start_mail'),
('.src_data({latched_samples,pre_q,ring_q,threshold_a_q,threshold_b_q,auto_q,trigger_enable_q,immediate_q})',
 '.src_data({type_a_q,type_b_q,latched_samples,pre_q,ring_q,threshold_a_q,threshold_b_q,auto_q,trigger_enable_q,immediate_q})'),
('        .auto_mode(config_adc[3])','        .trigger_type_a(config_adc[127:126]),\n        .trigger_type_b(config_adc[125:124]),\n        .auto_mode(config_adc[3])'),
('cfg_pre_percent<=100 && (!cfg_auto_mode','cfg_pre_percent<=100 && cfg_trigger_type_a<=2 && cfg_trigger_type_b<=2 && (!cfg_auto_mode'),
('            auto_q<=0; trigger_enable_q<=0; immediate_q<=0;','            auto_q<=0; trigger_enable_q<=0; immediate_q<=0; type_a_q<=0; type_b_q<=0;'),
('                    auto_q<=cfg_auto_mode;','                    type_a_q<=cfg_trigger_type_a; type_b_q<=cfg_trigger_type_b;\n                    auto_q<=cfg_auto_mode;')])
edit('adc_record_store.v',[
('        .cfg_pre_percent(cfg_pre_percent),',
 '        .cfg_trigger_type_a(cfg_trigger_type_a),\n        .cfg_trigger_type_b(cfg_trigger_type_b),\n        .cfg_pre_percent(cfg_pre_percent),')])
edit('fmc_record_link.v',[
('    output reg cfg_auto_mode,','    output reg [1:0] cfg_trigger_type_a,\n    output reg [1:0] cfg_trigger_type_b,\n    output reg cfg_auto_mode,'),
('    reg auto_fmc;','    reg [1:0] type_a_fmc;\n    reg [1:0] type_b_fmc;\n    reg auto_fmc;'),
("wire extension_address = bus_addr>=24'h000028 && bus_addr<=24'h000034 && !bus_addr[0];",
 "wire extension_address = (bus_addr>=24'h000028 && bus_addr<=24'h000034 && !bus_addr[0]) ||\n                             bus_addr==24'h000042 || bus_addr==24'h000044;"),
("(bus_addr==24'h000034 && bus_wdata<=3);", "(bus_addr==24'h000034 && bus_wdata<=3) ||\n        ((bus_addr==24'h000042 || bus_addr==24'h000044) && bus_wdata<=2);"),
("                24'h000040: register_data = {15'b0,length_mode_fmc};", "                24'h000040: register_data = {15'b0,length_mode_fmc};\n                24'h000042: register_data = {14'b0,type_a_fmc};\n                24'h000044: register_data = {14'b0,type_b_fmc};"),
('            auto_fmc <= 0;', '            auto_fmc <= 0;\n            type_a_fmc <= 0;\n            type_b_fmc <= 0;'),
("                            24'h000034: enable_fmc<=bus_wdata[1:0];", "                            24'h000034: enable_fmc<=bus_wdata[1:0];\n                            24'h000042: type_a_fmc<=bus_wdata[1:0];\n                            24'h000044: type_b_fmc<=bus_wdata[1:0];"),
('            cfg_auto_mode <= 0;', '            cfg_auto_mode <= 0;\n            cfg_trigger_type_a <= 0;\n            cfg_trigger_type_b <= 0;'),
("                else if (queued_addr==24'h000034) cfg_trigger_enable<=queued_data[1:0];", "                else if (queued_addr==24'h000034) cfg_trigger_enable<=queued_data[1:0];\n                else if (queued_addr==24'h000042) cfg_trigger_type_a<=queued_data[1:0];\n                else if (queued_addr==24'h000044) cfg_trigger_type_b<=queued_data[1:0];")])
edit('adc_ddr_fbg484_top.v',[
('    wire [1:0] fmc_trigger_enable;', '    wire [1:0] fmc_trigger_enable;\n    wire [1:0] fmc_trigger_type_a;\n    wire [1:0] fmc_trigger_type_b;'),
('        .cfg_pre_percent(FMC_CONTROL ?', '        .cfg_trigger_type_a(FMC_CONTROL ? fmc_trigger_type_a : 2\'d0),\n        .cfg_trigger_type_b(FMC_CONTROL ? fmc_trigger_type_b : 2\'d0),\n        .cfg_pre_percent(FMC_CONTROL ?'),
('        .cfg_pre_percent(fmc_pre_percent),', '        .cfg_trigger_type_a(fmc_trigger_type_a),\n        .cfg_trigger_type_b(fmc_trigger_type_b),\n        .cfg_pre_percent(fmc_pre_percent),')])
print('Added independent level/rising/falling trigger types to both channels.')
