from pathlib import Path
import re
import json
import hashlib
import zipfile
import difflib

root=Path(__file__).resolve().parent
original=(root/'original_top.txt').read_text(encoding='utf-8-sig')
changed=(root/'rtl/adc_ddr_fbg484_top.v').read_text(encoding='utf-8')
for name in ['u_clocks','u_forward','u_debug_reset','u_store','u_mig']:
    pattern=rf'\b{name}\s*\([\s\S]*?\n\s*\);'
    before=re.search(pattern,original).group(0)
    after=re.search(pattern,changed).group(0)
    assert re.sub(r'\s+','',before)==re.sub(r'\s+','',after),name
(root/'reports/top_change.diff').write_text(''.join(difflib.unified_diff(original.splitlines(True),changed.splitlines(True),fromfile='original_top',tofile='fmc_top')),encoding='utf-8')

xdc=(root.parent/'fmc_pins_reviewed.xdc').read_text(encoding='utf-8')
xdc=xdc.replace('# SDCLK L21 is not a clock-capable pin. Clock architecture remains to be designed.',
'''# SDCLK L21 is sampled as data by ui_clk=100 MHz, never connected to BUFG.
# External SDCLK must be 1..5 MHz; see README for the MCU configuration.''')
xdc+=r'''
# Limit exceptions to the first oversampling registers. Internal stages remain timed.
# No create_clock on MCU_FMC_SDCLK and no blanket inter-clock false paths.
set fmc_meta [get_cells -quiet -hier -filter {NAME =~ *u_fmc_port/pins_meta_reg*}]
set fmc_clock_meta [get_cells -quiet -hier -regexp {.*u_fmc_port/clock_sync_reg\[0\]}]
if {[llength $fmc_meta] > 0} {
    set_false_path -from [get_ports {MCU_FMC_A[*] MCU_FMC_BA[*] MCU_FMC_NBL[*] MCU_FMC_D[*] MCU_FMC_SDCKE1 MCU_FMC_SDNE1 MCU_FMC_SDNRAS MCU_FMC_SDNCAS MCU_FMC_SDNWE}] -to [get_pins -of_objects $fmc_meta -filter {REF_PIN_NAME == D}]
}
if {[llength $fmc_clock_meta] > 0} {
    set_false_path -from [get_ports MCU_FMC_SDCLK] -to [get_pins -of_objects $fmc_clock_meta -filter {REF_PIN_NAME == D}]
}
# Bound the register-to-pin path, including tristate enable. This does not prove
# the MCU external setup/hold requirements; validate them during board bring-up.
set_max_delay -datapath_only 20.000 -to [get_ports {MCU_FMC_D[*]}]
'''
(root/'fmc_interface.xdc').write_text(xdc,encoding='utf-8')
pins=re.findall(r'^set_property PACKAGE_PIN (\S+) \[get_ports \{([^}]+)\}\]',xdc,re.M)
assert len(pins)==39 and len(set(p for p,n in pins))==39
existing=(root.parent/'integrated_adc_parallel/top_pins_integrated.xdc').read_text(encoding='utf-8')
existing_pins=set(re.findall(r'^set_property PACKAGE_PIN (\S+)',existing,re.M))
assert not existing_pins.intersection(p for p,n in pins)
(root/'text').mkdir(exist_ok=True)
for source in (root/'rtl').glob('*.v'):
    (root/'text'/f'{source.stem}.txt').write_text(source.read_text(encoding='utf-8'),encoding='utf-8')
(root/'text/fmc_interface.txt').write_text(xdc,encoding='utf-8')

details={
 'adc_ddr_fbg484_top': ('顶层静态所有权选择', 'FMC_CONTROL=1选择FMC，=0选择VIO；选择覆盖cfg/start/release/read_next/rd_en/rd_addr/ack。ADC及MIG实例逐字去空白比较未改变。'),
 'fmc_sdram_port': ('SDRAM引脚协议', 'ui_clk100MHz；三拍时钟同步、五拍总线历史，使用SDCLK上升沿前的总线样本。四个bank各保存13位row；BL1、CAS3、读DQM延迟2拍。总线回复必须下一SDCLK之前就绪。停钟2.55us释放DQ并丢弃在途读。'),
 'fmc_record_regs': ('采集寄存器及块缓存窗口', '与原记录模块同ui_clk，无新增内部CDC。命令单周期脉冲；合法duration1..200。窗口读启动两拍缓存读，在7计数超时时返回DEAD。块所有权始终由显式ACK释放。')
}
for name,(title,description) in details.items():
    src=(root/'rtl'/f'{name}.v').read_text(encoding='utf-8')
    interface=src[src.index('module '):src.index(');',src.index('module '))+2]
    wave={'signal':[{'name':'SDCLK','wave':'p......'},{'name':'command','wave':'=......','data':['READ']},{'name':'read_pipeline','wave':'.===...','data':['1','2','3']},{'name':'DQ','wave':'zzz=z..','data':['DATA']}], 'head':{'text':'CAS3：C0读命令，C3之后数据有效'}}
    document=f'''# {name}：{title}

## 接口
```verilog
{interface}
```

## 行为与复位
{description}
复位：新模块同步高有效rst，与现有debug_rst相连；DQ另外受rst组合控制立即高阻。顶层保留原reset_sync和MIG复位连接。

## 时序与边界
外部SDCLK=1..5MHz，高低各至少100ns，MCU命令/地址/写数据上升沿前稳定至少30ns。FPGA输出延迟需结合RPIPE=2及实现报告验证。
禁止未完成读的情况下进入CKE低电平；不支持普通SDRAM全地址存储或任意burst模式。读不会产生隐式ACK。
地址、寄存器、错误和软件交互见../README.md。新模块下游时序统一100MHz，现有ADC/MIG CDC不变。

## 时序图
```json
{json.dumps(wave,ensure_ascii=False,indent=2)}
```

## 验证
sim/tb_fmc_link.v检查CAS、连续BL1、地址映射、mask、非法命令、错误返回、复位和接口禁用。
reports保存实际工具输出；本说明不代表板级通过。完整顶层仅语法检查，ADC/MIG/IP沿用现有工程。
'''
    (root/'rtl'/f'{name}_spec.md').write_text(document,encoding='utf-8')

files=[]
for p in root.rglob('*'):
    if not p.is_file(): continue
    rel=p.relative_to(root)
    if any(part in ('.Xil','xsim.dir','__pycache__') for part in rel.parts): continue
    if p.suffix in ('.dcp','.pb','.jou','.wdb','.zip','.backup'): continue
    if p.name in ('package_delivery.py','build_top.py'): continue
    files.append(p)
manifest={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.name!='manifest.json'}
(root/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
with zipfile.ZipFile(root.parent/'adc_ddr_fmc_integration.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for p in files:
        archive.write(p,arcname='fmc_integration/'+str(p.relative_to(root)))
    if root/'manifest.json' not in files: archive.write(root/'manifest.json',arcname='fmc_integration/manifest.json')
print('Verified 39 unique pins, zero overlap; original ADC/MIG/store instance connections preserved.')
print('Wrote XDC, text copies, per-module specs, diff, manifest and delivery ZIP.')
