from pathlib import Path
ROOT=Path(__file__).parent
# Explicit interface specifications; this script does not parse Verilog.
specs={
'adc_capture_runtime':[
('input wire','ui_clk ui_rst global_rst init_calib_complete adc_clk_out'),
('input wire [13:2]','adc_da adc_db'),('output wire','adc_reset adc_cs_n adc_sck adc_sdi'),('output wire [2:0]','adc_ctrl'),
('input wire [31:0]','cfg_samples'),('input wire [6:0]','cfg_pre_percent'),('input wire','cfg_auto_mode'),
('input wire [1:0]','cfg_trigger_enable'),('input wire [11:0]','cfg_threshold_a cfg_threshold_b'),
('input wire','cmd_start cmd_arm cmd_force cmd_abort cmd_release'),('output wire','trigger_armed history_ready trigger_seen'),
('output reg','capture_aborted'),('output reg [2:0]','trigger_reason'),('output reg [31:0]','record_start_sample'),
('output wire [31:0]','record_ring_samples record_pre_samples'),('output wire','ready busy cfg_done'),
('output reg','start_accepted command_rejected record_done record_valid'),('output wire','capture_finished overflow'),
('output reg [31:0]','record_samples record_bytes latched_samples'),('output wire [31:0]','submitted_blocks'),
('output wire [APP_ADDR_WIDTH-1:0]','app_addr'),('output wire [2:0]','app_cmd'),('output wire','app_en'),('input wire','app_rdy'),
('output wire [255:0]','app_wdf_data'),('output wire [31:0]','app_wdf_mask'),('output wire','app_wdf_wren app_wdf_end'),('input wire','app_wdf_rdy')],
'adc_record_store':[
('input wire','ui_clk ui_rst global_rst init_calib_complete adc_clk_out'),('input wire [13:2]','adc_da adc_db'),
('output wire','adc_reset adc_cs_n adc_sck adc_sdi'),('output wire [2:0]','adc_ctrl'),('input wire [31:0]','cfg_samples'),
('input wire [6:0]','cfg_pre_percent'),('input wire','cfg_auto_mode'),('input wire [1:0]','cfg_trigger_enable'),
('input wire [11:0]','cfg_threshold_a cfg_threshold_b'),('input wire','cmd_arm cmd_force cmd_abort'),
('output wire','trigger_armed history_ready trigger_seen capture_aborted'),('output wire [2:0]','trigger_reason'),
('output wire [31:0]','record_pre_samples'),('input wire','cmd_start cmd_release cmd_read_next'),
('output wire','ready busy cfg_done start_accepted command_rejected record_done record_valid capture_finished overflow'),
('output wire [31:0]','record_samples record_bytes latched_samples submitted_blocks'),
('output wire','read_ready read_accepted read_idle stream_done read_error'),('output wire [APP_ADDR_WIDTH-1:0]','app_addr'),
('output wire [2:0]','app_cmd'),('output wire','app_en'),('input wire','app_rdy'),('output wire [255:0]','app_wdf_data'),
('output wire [31:0]','app_wdf_mask'),('output wire','app_wdf_wren app_wdf_end'),('input wire','app_wdf_rdy'),
('input wire [255:0]','app_rd_data'),('input wire','app_rd_data_valid app_rd_data_end rd_clk rd_en'),('input wire [11:0]','rd_addr'),
('output wire [15:0]','rd_data'),('output wire','rd_valid block_ready'),('output wire [31:0]','block_index block_offset'),
('output wire [13:0]','block_bytes'),('output wire','block_last'),('input wire','cmd_block_ack'),('output wire','ack_accepted ack_rejected rd_rejected')],
'ddr_block_reader':[
('input wire','ui_clk rst init_calib_complete stream_clear record_done record_valid'),('input wire [31:0]','record_bytes record_start_sample record_ring_samples'),
('input wire','cmd_read_next'),('output wire','idle read_ready'),('output reg','read_accepted command_rejected stream_done protocol_error'),
('output wire [APP_ADDR_WIDTH-1:0]','app_addr'),('output wire','app_en'),('input wire','app_rdy'),('input wire [255:0]','app_rd_data'),
('input wire','app_rd_data_valid app_rd_data_end rd_clk rd_rst rd_en'),('input wire [11:0]','rd_addr'),('output wire [15:0]','rd_data'),
('output wire','rd_valid'),('output reg','block_ready'),('output reg [31:0]','block_index block_offset'),('output reg [13:0]','block_bytes'),
('output reg','block_last'),('input wire','cmd_block_ack'),('output reg','ack_accepted ack_rejected rd_rejected')],
'mig_write_runtime':[
('input wire','clk rst clear enable'),('input wire [31:0]','ring_samples'),('input wire [255:0]','s_data'),('input wire','s_valid'),
('output wire','s_ready'),('output wire [APP_ADDR_WIDTH-1:0]','app_addr'),('output wire [2:0]','app_cmd'),('output wire','app_en'),
('input wire','app_rdy'),('output wire [255:0]','app_wdf_data'),('output wire [31:0]','app_wdf_mask'),
('output wire','app_wdf_wren app_wdf_end'),('input wire','app_wdf_rdy'),('output wire','idle'),('output reg [31:0]','submitted_blocks')],
'adc_ddr_fbg484_top':[
('input wire','MCU_FMC_SDCLK MCU_FMC_SDCKE1 MCU_FMC_SDNE1 MCU_FMC_SDNRAS MCU_FMC_SDNCAS MCU_FMC_SDNWE'),
('input wire [12:0]','MCU_FMC_A'),('input wire [1:0]','MCU_FMC_BA MCU_FMC_NBL'),('inout wire [15:0]','MCU_FMC_D'),
('input wire','sys_clk sys_rst_n ADC_CLK_OUT_P'),('input wire [13:2]','ADC_DA ADC_DB'),
('output wire','ADC_CLK_IN_P ADC_CLK_IN_N ADC_RESET ADC_CS ADC_SCK ADC_SDI'),('output wire [2:0]','ADC_CTRL'),
('inout wire [31:0]','ddr3_dq'),('inout wire [3:0]','ddr3_dqs_n ddr3_dqs_p'),('output wire [13:0]','ddr3_addr'),
('output wire [2:0]','ddr3_ba'),('output wire','ddr3_ras_n ddr3_cas_n ddr3_we_n ddr3_reset_n'),
('output wire [0:0]','ddr3_ck_p ddr3_ck_n ddr3_cke ddr3_cs_n ddr3_odt'),('output wire [3:0]','ddr3_dm')]
}
for module,groups in specs.items():
    p=ROOT/'rtl'/f'{module}.v';s=p.read_text(encoding='utf-8')
    start=s.index('    input wire')
    end=s.index(');',start)
    ports=[f'    {typ} {name}' for typ,names in groups for name in names.split()]
    s=s[:start]+',\n'.join(ports)+'\n'+s[end:]
    p.write_text(s,encoding='utf-8')

# Recover the original Chinese comments from the plaintext GB18030 snapshot.
source=Path(r'./local_inputs/adc_ddr_fbg484_top.v').read_bytes()
bad=source.decode('utf-8',errors='replace').splitlines()
good=source.decode('gb18030').splitlines()
p=ROOT/'rtl/adc_ddr_fbg484_top.v';s=p.read_text(encoding='utf-8')
for a,b in zip(bad,good):
    if '//' in a and a!=b:s=s.replace(a[a.index('//'):],b[b.index('//'):])
s=s.replace('FMC_CONTROL ? 0 : rd_data',"FMC_CONTROL ? 16'd0 : rd_data")
s=s.replace('FMC_CONTROL ? 0 : block_bytes',"FMC_CONTROL ? 14'd0 : block_bytes")
s=s.replace('FMC_CONTROL ? 0 : block_index',"FMC_CONTROL ? 32'd0 : block_index")
s=s.replace('FMC_CONTROL ? 0 : block_offset',"FMC_CONTROL ? 32'd0 : block_offset")
p.write_text(s,encoding='utf-8')
print('Explicit ports split; original Chinese top comments recovered.')
