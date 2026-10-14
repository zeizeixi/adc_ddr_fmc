from pathlib import Path
import re

root = Path(__file__).resolve().parent
source = (root / 'original_top.txt').read_text(encoding='utf-8-sig')
source = source.replace('module adc_ddr_fbg484_top(', '''module adc_ddr_fbg484_top #(
    // 1: FMC owns commands/read port; 0: original VIO owns them.
    parameter FMC_CONTROL = 1
)(
    input wire MCU_FMC_SDCLK, MCU_FMC_SDCKE1, MCU_FMC_SDNE1,
    input wire MCU_FMC_SDNRAS, MCU_FMC_SDNCAS, MCU_FMC_SDNWE,
    input wire [12:0] MCU_FMC_A,
    input wire [1:0] MCU_FMC_BA, MCU_FMC_NBL,
    inout wire [15:0] MCU_FMC_D,''')
source = source.replace('// 本文件仅调整空白排版并增加中文说明，保留全部端口、参数和实例连接。', '// 新增低速 FMC SDRAM 协议接口；ADC/MIG/存储模块保持原实例连接。')
source = source.replace('// 本版读回使用 ui_clk，尚未接入 STM32 FMC。', '// 本版读回仍使用 ui_clk，FMC 与 VIO 在顶层进行静态选择。')
source = source.replace('// 目前未实现毫秒到采样对数的顶层换算，也未实现 FMC 寄存器接口。', '// FMC_CONTROL=0 时 VIO 控制采样对数；=1 时由 FMC 设置 1..200 ms。')
source = source.replace('// ADC 复位及串行配置输出；本版只写配置，不提供 ADC_SDO 读回', '// ADC 配置引脚；电平/初始化行为保留在现有采集模块内')

def change_instance(match):
    part = match.group(0)
    mapping = {'cfg_samples':'vio_cfg_samples','start':'vio_start',
               'release_record':'vio_release','read_next':'vio_read_next',
               'rd_addr':'vio_rd_addr','block_ack':'vio_ack'}
    for name, replacement in mapping.items():
        part = re.sub(r'(\.probe_out\d+\s*\()\s*'+name+r'\s*(\))', r'\g<1>'+replacement+r'\2', part)
    return part

source = re.sub(r'(?:readout_vio u_read_vio|capture_vio u_vio)\([\s\S]*?\n    \);', change_instance, source)
# The debug edge detector must not drive the shared read enable directly.
debug_start = source.index('readout_debug u_read_debug(')
debug_end = source.index('\n    );', debug_start)
debug_section = source[debug_start:debug_end].replace('(rd_en)', '(vio_rd_en)')
source = source[:debug_start] + debug_section + source[debug_end:]

integration = '''
    // FMC endpoint runs entirely in ui_clk; external SDCLK is oversampled.
    // Static ownership prevents VIO and MCU commands from colliding.
    wire [31:0] vio_cfg_samples, fmc_cfg_samples;
    wire vio_start, vio_release, vio_read_next, vio_ack, vio_rd_en;
    wire [11:0] vio_rd_addr, fmc_rd_addr;
    wire fmc_start, fmc_release, fmc_read_next, fmc_ack, fmc_rd_en;
    wire fmc_bus_read, fmc_bus_write, fmc_reply_valid;
    wire [23:0] fmc_bus_addr;
    wire [15:0] fmc_bus_wdata, fmc_reply_data;
    wire [1:0] fmc_bus_mask;
    wire fmc_mode_valid, fmc_protocol_error, fmc_clear_error;

    assign cfg_samples = FMC_CONTROL ? fmc_cfg_samples : vio_cfg_samples;
    assign start = FMC_CONTROL ? fmc_start : vio_start;
    assign release_record = FMC_CONTROL ? fmc_release : vio_release;
    assign read_next = FMC_CONTROL ? fmc_read_next : vio_read_next;
    assign block_ack = FMC_CONTROL ? fmc_ack : vio_ack;
    assign rd_en = FMC_CONTROL ? fmc_rd_en : vio_rd_en;
    assign rd_addr = FMC_CONTROL ? fmc_rd_addr : vio_rd_addr;

    fmc_sdram_port u_fmc_port (
        .clk(ui_clk), .rst(debug_rst), .enabled(FMC_CONTROL != 0),
        .clear_error(fmc_clear_error),
        .sdclk(MCU_FMC_SDCLK), .cke(MCU_FMC_SDCKE1), .cs_n(MCU_FMC_SDNE1),
        .ras_n(MCU_FMC_SDNRAS), .cas_n(MCU_FMC_SDNCAS), .we_n(MCU_FMC_SDNWE),
        .addr(MCU_FMC_A), .bank(MCU_FMC_BA), .dqm(MCU_FMC_NBL), .dq(MCU_FMC_D),
        .bus_read(fmc_bus_read), .bus_write(fmc_bus_write), .bus_addr(fmc_bus_addr),
        .bus_wdata(fmc_bus_wdata), .bus_mask(fmc_bus_mask),
        .reply_valid(fmc_reply_valid), .reply_data(fmc_reply_data),
        .mode_valid(fmc_mode_valid), .protocol_error(fmc_protocol_error)
    );

    fmc_record_regs u_fmc_regs (
        .clk(ui_clk), .rst(debug_rst),
        .bus_read(fmc_bus_read), .bus_write(fmc_bus_write), .bus_addr(fmc_bus_addr),
        .bus_wdata(fmc_bus_wdata), .bus_mask(fmc_bus_mask),
        .reply_valid(fmc_reply_valid), .reply_data(fmc_reply_data),
        .mode_valid(fmc_mode_valid), .protocol_error(fmc_protocol_error), .clear_error(fmc_clear_error),
        .cfg_samples(fmc_cfg_samples), .cmd_start(fmc_start), .cmd_release(fmc_release),
        .cmd_read_next(fmc_read_next), .cmd_ack(fmc_ack), .rd_en(fmc_rd_en), .rd_addr(fmc_rd_addr),
        .rd_data(rd_data), .rd_valid(rd_valid),
        .ready(ready), .busy(busy), .done(done), .valid(valid), .overflow(overflow),
        .cfg_done(cfg_done), .calib(calib), .read_ready(read_ready), .read_idle(read_idle),
        .stream_done(stream_done), .read_error(read_error), .block_ready(block_ready), .block_last(block_last),
        .accepted(accepted), .rejected(rejected), .read_accepted(read_accepted),
        .ack_accepted(ack_accepted), .ack_rejected(ack_rejected), .rd_rejected(rd_rejected),
        .record_samples(record_samples), .record_bytes(record_bytes), .blocks(blocks),
        .block_index(block_index), .block_offset(block_offset), .block_bytes(block_bytes)
    );

'''
source = source.replace('    // ------------------------------------------------------------------------\n    // DDR3 MIG 控制器', integration+'    // ------------------------------------------------------------------------\n    // DDR3 MIG 控制器')
assert source.count('fmc_sdram_port u_fmc_port') == 1
assert '.probe_out0            (vio_cfg_samples)' in source
assert '.rd_en                 (vio_rd_en)' in source
(root/'rtl/adc_ddr_fbg484_top.v').write_text(source, encoding='utf-8')
(root/'adc_ddr_fbg484_top.txt').write_text(source, encoding='utf-8')
print('Top generated from supplied source; static FMC/VIO ownership added.')
