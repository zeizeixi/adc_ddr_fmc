from pathlib import Path
root = Path(__file__).parent / 'adc_ila_debug'
root.mkdir(exist_ok=True)
src = Path('./local_inputs/ads62p24_pack_runtime.v').read_text(encoding='utf-8-sig')
old = "next_pack[pack_index*32 +: 32]={4'b0,adc_b_q,4'b0,adc_a_q};"
assert src.count(old) == 1
src = src.replace(old, "// 两路反相修正后的直二进制码写入 DDR；高四位保持补零。\n        next_pack[pack_index*32 +: 32]={4'b0,adc_b_corrected,4'b0,adc_a_corrected};")
anchor = '    localparam IDLE=0'
assert src.count(anchor) == 1
ila = '''    // 在输入寄存器之后观察数据，保留原来的 IOB 采样寄存器。
    // 这里取反一次，ILA 与 DDR 使用完全相同的修正码。
    wire [11:0] adc_a_corrected;
    wire [11:0] adc_b_corrected;
    assign adc_a_corrected = ~adc_a_q;
    assign adc_b_corrected = ~adc_b_q;

    // ILA 直接使用 ADC 返回时钟；不依赖 DDR 开始采集命令。
    // 同一个 ILA 采样点中，原始码与修正码对应同一份输入寄存器数据。
    adc_raw_ila u_adc_raw_ila (
        .clk    (adc_clk),
        .probe0 (adc_a_q),          // A 原始码，12 位无符号
        .probe1 (adc_b_q),          // B 原始码，12 位无符号
        .probe2 (adc_a_corrected),  // A 修正码 = 4095 - A 原始码
        .probe3 (adc_b_corrected),  // B 修正码 = 4095 - B 原始码
        .probe4 (rst),              // ADC 域逻辑复位，高有效
        .probe5 (start)             // ADC 域采集启动脉冲，仅用于观察或触发
    );

'''
src = src.replace(anchor, ila+anchor)
(root/'ads62p24_pack_runtime.v').write_text(src,encoding='utf-8')
(root/'ads62p24_pack_runtime.txt').write_text(src,encoding='utf-8-sig')
print(root)
