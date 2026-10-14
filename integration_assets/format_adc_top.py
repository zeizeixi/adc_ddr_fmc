from pathlib import Path
import re, hashlib, json

root = Path(__file__).parent / 'adc_top_chinese'
root.mkdir(exist_ok=True)
source = Path('./local_inputs/pasted-text.txt')
original = source.read_text(encoding='utf-8-sig')
(root / 'adc_ddr_fbg484_top.original.v.txt').write_bytes(source.read_bytes())
code = re.sub(r'//[^\n]*', '', original)
notes = {
'sys_clk':'板载系统时钟；沿用参考工程的 50 MHz 输入配置',
'ADC_CLK_OUT_P':'ADC 返回的数据时钟；以此时钟接收 A、B 两路数据',
'ADC_DA':'两路 ADC 有效数据总线，保留原理图的 [13:2] 编号，每路 12 位',
'ADC_CLK_IN_P':'FPGA 送给 ADC 的差分采样时钟；P/N 物理对应及电气标准需单独核对',
'ADC_RESET':'ADC 复位及串行配置输出；本版只写配置，不提供 ADC_SDO 读回',
'ADC_CTRL':'ADC 控制引脚；数组下标 0、1、2 对应原理图 CTRL1、CTRL2、CTRL3',
'ddr3_dq':'两颗 x16 DDR 组成的 32 位双向数据总线',
'ddr3_dqs_n':'四组差分数据选通，每组对应一个数据字节',
'ddr3_addr':'DDR 行列复用地址，具体含义由 MIG 命令时序决定',
'ddr3_ba':'DDR 内部存储体地址',
'ddr3_ras_n':'DDR 命令及复位信号，后缀 _n 表示低有效',
'ddr3_ck_p':'DDR 差分时钟、时钟使能、片选和片内终端控制',
'ddr3_dm':'四个字节的数据掩码',
'clk_200m':'时钟与状态：200 MHz 供 MIG，100 MHz 供采样时钟转发；ui_clk 由 MIG 输出',
'app_addr':'MIG 原生接口地址；位宽及地址步进由存储模块与 MIG 配置共同约定',
'app_cmd':'MIG 命令码：写命令 000，读命令 001',
'app_en':'MIG 命令握手与写数据握手；两组就绪信号独立',
'app_wdf_data':'MIG 单拍写数据，256 位可容纳 8 组 A/B 样本',
'app_wdf_mask':'写数据的逐字节掩码，1 表示对应字节不写入',
'cfg_samples':'采集长度、记录统计及锁存长度；cfg_samples 单位为样本对，不是毫秒',
'start':'采集命令与状态；done 表示记录提交完成，valid 表示记录有效',
'app_rd_data':'MIG 返回的 256 位读数据',
'app_rd_data_valid':'MIG 返回数据的有效标志和突发结束标志',
'read_next':'DDR 分块读取命令及读取状态',
'read_word':'调试读字命令、实际读脉冲、块确认命令和调试清除命令',
'rd_addr':'8 KiB 块缓存的 16 位字地址，范围 0～4095',
'rd_data':'缓存返回数据、调试状态及供 VIO 显示的最近一次有效数据',
'rd_valid':'缓存与块所有权状态，以及确认/读字命令的接收或拒绝标志',
'block_index':'当前块序号、记录内字节偏移，以及调试累计计数',
'block_bytes':'当前块有效字节数；完整块为 8192，最后一块可能不足',
'debug_rst':'ui_clk 域调试复位，高有效，由 reset_sync 同步释放',
}
sections = {
'u_clocks':('时钟生成', 'Clocking Wizard 生成 200 MHz 和 100 MHz；locked 表示输出时钟已锁定。'),
'u_forward':('ADC 采样时钟转发', '将 100 MHz 时钟经专用输出逻辑送至 ADC；本次保留原有连接，不修改 P/N。'),
'u_debug_reset':('调试复位同步', '外部复位、时钟失锁或 MIG 用户复位均使调试逻辑复位；在 ui_clk 域同步释放。'),
'u_store':('采集、DDR 写入与分块读回', '内部完成 ADC 初始化、跨时钟缓存、定长采集和 MIG 读写调度。\n// 记录完成后按命令读入块缓存；消费者读取后确认，才能复用该块缓存。\n// 本版读回消费者使用 ui_clk，尚未接入 STM32 FMC。'),
'u_read_debug':('读回调试适配', '将 read_word 上升沿变为一次读脉冲，并保存返回数据、事件标志及计数。\n// debug_status[5:0]：读就绪、读空闲、块就绪、末块、流完成、读错误。\n// debug_status[12:6]：读数据有效、读命令接受、块确认接受、命令拒绝、\n//                      块确认拒绝、读字拒绝、采集启动接受；这些事件保持到清除。'),
'u_read_vio':('读回 VIO 面板', '通过 Hardware Manager 手动请求数据块、选择字地址、读取并确认数据块。'),
'u_vio':('采集 VIO 面板', '设置采样对数并启动采集；例如 100 MSPS 下，200 ms 对应 20000000 对。\n// 目前未实现毫秒到采样对数的顶层换算，也未实现 FMC 寄存器接口。'),
'u_mig':('DDR3 MIG 控制器', '保持厂家 IP 及端口连接；当前配置的 sys_rst 为低有效。\n// app_* 为用户侧原生接口，ddr3_* 为外部存储器接口。\n// 手动自刷新、刷新和 ZQ 请求置零；正常刷新由 MIG 自身管理。'),
}
probe_notes = {
'u_read_vio': ['综合读回状态','当前块序号','当前块在记录中的字节偏移','当前块有效字节数','最近一次读出的 16 位数据','累计有效读字次数','累计成功确认块次数','累计接受读块请求次数'],
'u_vio': ['可接受采集启动','采集忙','记录完成','记录有效','采集溢出','记录实际样本对数','记录有效字节数','已提交写块数','ADC 初始化完成'],
}
out_notes = {'u_read_vio':['请求下一块','块内 16 位字地址','读一个字，上升沿有效','确认当前块已消费','清除调试事件与计数'], 'u_vio':['目标样本对数','启动采集命令','释放当前记录命令']}

result = ['// ============================================================================',
'// 模块：adc_ddr_fbg484_top —— 双通道 ADC 采集与 DDR3 存储调试顶层',
'// 底稿：用户本次粘贴的无 LED、带读回 VIO 顶层代码。',
'// 数据路径：ADC -> 采集/打包 -> 异步 FIFO -> MIG -> DDR3 -> 块缓存 -> VIO。',
'// 本文件仅调整空白排版并增加中文说明，保留全部端口、参数和实例连接。',
'// 引脚电气兼容性、时钟 P/N 与输入时序约束仍须独立核对；注释不代替验证。',
'// ============================================================================', '']
instance = None
for raw in code.splitlines():
    line = raw.strip()
    if not line:
        continue
    hit = next((n for n in sections if re.search(r'\b'+n+r'\s*\(', line)), None)
    if hit:
        instance = hit
        title, desc = sections[hit]
        result += ['', '    // ------------------------------------------------------------------------', '    // '+title, '    // '+desc.replace('\n//','\n    //'), '    // ------------------------------------------------------------------------']
        pos = re.search(r'\b'+hit+r'\s*\(', line).end()
        result.append('    '+line[:pos])
        line = line[pos:]
    elif line.startswith(('input wire','output wire','inout wire','wire ')):
        key = next((k for k in notes if re.search(r'\b'+k+r'\b',line)),None)
        if key:
            result += ['', '    // '+notes[key]]
        # Keep declarations and their token order unchanged; normalize spaces only.
        line = re.sub(r',\s*', ', ',line)
        result.append('    '+line)
        continue
    if instance and line:
        # All existing instance connections are named and have no nested parentheses.
        matches = list(re.finditer(r'\.(\w+)\(([^()]*)\)',line))
        if matches:
            for m in matches:
                name, value = m.groups()
                tail = line[m.end():]
                comma = ',' if tail.lstrip().startswith(',') else ''
                note = ''
                if instance in probe_notes and name.startswith('probe_in'):
                    note = probe_notes[instance][int(name[8:])]
                if instance in out_notes and name.startswith('probe_out'):
                    note = out_notes[instance][int(name[9:])]
                result.append('        .'+name.ljust(22)+'('+value+')'+comma+(' // '+note if note else ''))
            if line.endswith(');'):
                result.append('    );')
                instance = None
            continue
    result.append(line)

text = '\n'.join(result)+'\n'
def tokens(s):
    s = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '',s)
    return re.findall(r"`[A-Za-z_][\w$]*|[A-Za-z_][\w$]*|\d+'[sS]?[bBoOdDhH][0-9a-fA-F_xXzZ?]+|\d+|&&|\|\||!=|==|<=|>=|[^\s]",s)
assert tokens(original) == tokens(text), 'RTL token sequence changed'
(root/'adc_ddr_fbg484_top.v').write_text(text,encoding='utf-8')
(root/'adc_ddr_fbg484_top.txt').write_text(text,encoding='utf-8-sig')
(root/'verification.json').write_text(json.dumps({'baseline':str(source),'baseline_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'rtl_tokens_unchanged':True,'tokens':len(tokens(text)),'note':'Whitespace/comments only; no simulation or synthesis rerun.'},ensure_ascii=False,indent=2),encoding='utf-8')
print(root)
print('PASS: RTL token sequence unchanged; UTF-8 .v and UTF-8 BOM .txt written.')
