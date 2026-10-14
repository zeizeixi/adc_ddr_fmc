from pathlib import Path
import re
import json

root = Path(r'./local_inputs/01a0891e-55d3-71c0-a828-6e9adbd46e79')
src = Path(r'./local_inputs/pasted-text.txt').read_text(encoding='utf-8-sig')
data = (root / 'adc_data_pins_checked.xdc').read_text(encoding='utf-8-sig')
mapping = {}
for m in re.finditer(r'^set_property PACKAGE_PIN (\w+) \[get_ports \{(ADC_D[AB]\[\d+\])\}\] ; # (.+)$', data, re.M):
    mapping[m[2]] = (m[1], m[3])
assert len(mapping) == 24
lines = src.splitlines()
changes=[]
for i,line in enumerate(lines):
    m = re.fullmatch(r'set_property PACKAGE_PIN (\w+) \[get_ports \{(ADC_D[AB]\[\d+\])\}\]',line)
    if m:
        ball,note=mapping[m[2]]
        if ball!=m[1]: changes.append([m[2],m[1],ball])
        lines[i]=f'set_property PACKAGE_PIN {ball} [get_ports {{{m[2]}}}] ; # {note}'
    elif line.startswith('# 合并引脚约束：'):
        lines[i]='# 合并引脚约束：XC7A200T-FBG484-2，自研底板，无 LED；ADC 配置线使用已确认跳线。'
    elif line.startswith('# 状态：'):
        lines[i]='# 数据映射按连接器及 Bank15/16 原理图逐根核对；不代表整板电气或时序已完成验证。'
    elif line.startswith('# DDR PACKAGE_PIN'):
        lines[i]='# DDR PACKAGE_PIN/IOSTANDARD 保留附件原值；MIG 内部时序、终端等仍由 MIG 自带 XDC 管理。'
    elif line.startswith('# ===== ADC：'):
        lines[i]='# ===== ADC：两路各 12 位，端口 [2] 对应 D0，[13] 对应 D11；NC 不使用 ====='
    elif line.startswith('set_property PACKAGE_PIN G18 [get_ports ADC_CLK_OUT_P]'):
        lines[i]=line+' ; # J1-4 -> B15_L4_N；ADC 返回时钟输入'
    elif line.startswith('set_property PACKAGE_PIN V8 [get_ports {ADC_CLK_IN_P}]'):
        lines[i]='set_property PACKAGE_PIN V8 [get_ports {ADC_CLK_IN_P}] ; # ADC 时钟输出；FPGA 物理 N'
    elif line.startswith('set_property PACKAGE_PIN V9 [get_ports {ADC_CLK_IN_N}]'):
        lines[i]='set_property PACKAGE_PIN V9 [get_ports {ADC_CLK_IN_N}] ; # ADC 时钟输出；FPGA 物理 P'
    elif line.startswith('# ADC_CLK_IN_P='):
        lines[i]='# 配套 RTL 保持 OBUFDS .O(ADC_CLK_IN_N)、.OB(ADC_CLK_IN_P)；输出电平兼容性仍需板级确认。'
    elif line.startswith('# ADC 输入时钟、'):
        lines[i]='# ADC 返回时钟在文件末尾约束为 100 MHz；数据 input_delay 尚未补齐。'
    elif line.startswith('set_property PACKAGE_PIN T16 [get_ports ADC_CS]'):
        lines[i]='# 并行配置需在 RTL 中固定 RESET=1、SEN=1、SCLK=0、SDI=0、CTRL=000。\n# XDC 只定义引脚和电平标准，不产生固定逻辑电平；以下配置端口继续保留。\n'+line+' ; # 实物跳线，ADC SEN（并行模式为高电平）'
    elif line.startswith('set_property PACKAGE_PIN W14 [get_ports ADC_SDI]'):
        lines[i]=line+' ; # 实物跳线，ADC SDATA'
    elif line.startswith('set_property PACKAGE_PIN V15 [get_ports ADC_SCK]'):
        lines[i]=line+' ; # 实物跳线，ADC SCLK（并行模式为低电平）'
    elif line.startswith('set_property PACKAGE_PIN AA9 [get_ports ADC_RESET]'):
        lines[i]=line+' ; # 实物跳线，ADC RESET（并行模式保持高电平）'
out='\n'.join(lines)+'\n'
out=re.sub(r'\n{3,}', '\n\n', out)
ddr=lambda s:[x for x in s.splitlines() if x.startswith('set_property ') and 'get_ports' in x and 'ddr3_' in x]
assert ddr(src)==ddr(out), 'DDR constraints changed'
assert len(changes)==12
pins={};ports={}
for line in out.splitlines():
    if not line.startswith('set_property PACKAGE_PIN '): continue
    m=re.match(r'set_property PACKAGE_PIN (\w+) \[get_ports (.+)\](?:\s*;.*)?$',line)
    assert m, line
    ball,port=m[1],m[2].strip('{}')
    assert ball not in pins, (ball,pins.get(ball),port)
    assert port not in ports,port
    pins[ball]=port;ports[port]=ball
assert out.count('create_clock -name adc_capture_clk')==1
for name in ['ADC_CS','ADC_RESET','ADC_SCK','ADC_SDI']:
    assert out.count(f'set_property IOSTANDARD LVCMOS33 [get_ports {name}]')==1
folder=root/'integrated_adc_parallel';folder.mkdir(exist_ok=True)
for ext in ['xdc','txt']:
    (folder/f'top_pins_integrated.{ext}').write_text(out,encoding='utf-8-sig')
print(json.dumps({'changed_data_pins':changes,'active_unique_pins':len(pins),'unchanged_DDR_constraint_lines':len(ddr(out)),'outputs':[str(folder/'top_pins_integrated.xdc'),str(folder/'top_pins_integrated.txt')]},ensure_ascii=False))
