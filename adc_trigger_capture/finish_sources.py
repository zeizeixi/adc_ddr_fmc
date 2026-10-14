from pathlib import Path
R=Path(__file__).parent
descriptions={
'adc_ddr_fbg484_top':'板级集成参考：ADC→环形 DDR→触发冻结→8 KiB 缓存→FMC；保留原 MIG、时钟和 ADC 初始化模块。',
'adc_record_store':'集成采集管理器与分块读出器；UI 域控制采集，读时钟域消费缓存，读写按记录状态互斥。',
'adc_capture_runtime':'锁存配置，建立前触发历史，接收触发/取消，排空 FIFO 和 MIG 写命令后发布记录。',
'ads62p24_pack_runtime':'ADC 域打包及当前码值比较；每个 32 位样本对低半字 A、高半字 B；没有边沿触发判断。',
'ddr_block_reader':'从环形 DDR 起点重新对齐样本，每次发布最多 8192 字节；显式 ACK 后才复用缓存。',
'mig_write_runtime':'MIG DQ32/BL8/4:1 写端：每拍 256 位、地址步进 8；提交到环形区末尾后回到基址。',
'fmc_record_link':'FMC V2 寄存器及跨域命令桥；配置/采集命令有序进入 UI 域，ACK 留在缓存读时钟域。',
'trigger_geometry':'计算 P=floor(N×前触发百分比/100)，32 周期迭代除法；环形区额外保留一拍补零空间。'
}
comments={
'cfg_samples':'下一次记录的 A/B 总对数；不是单通道半字数。',
'cfg_pre_percent':'前触发比例 0～100；ARM/START 接受时锁存。',
'cfg_auto_mode':'0 手动 FORCE；1 自动等待比较条件，不设超时。',
'cfg_trigger_type_a':'A 路比较：0 >=、1 >、2 ==、3 <=、4 <。',
'cfg_trigger_type_b':'B 路比较：0 >=、1 >、2 ==、3 <=、4 <。',
'cfg_trigger_enable':'bit0 电压 A，bit1 电流 B；已使能条件按 OR 组合。',
'cfg_threshold_a':'A 路校正后 ADC 阈值码，0～4095。',
'cfg_threshold_b':'B 路校正后 ADC 阈值码，0～4095。',
'cmd_arm':'锁存配置并建立前触发历史。',
'cmd_force':'手动触发命令；前触发历史就绪后才能接受。',
'cmd_abort':'取消准备、等待或采集；排空已提交数据后回到 READY。',
'trigger_armed':'ADC 已进入本次采样且尚未触发。',
'history_ready':'前触发历史已足够，手动模式可发送 FORCE。',
'trigger_seen':'本次触发已发生；不等于 DDR 写入已排空。',
'capture_aborted':'本次已取消；下次接受采集时清除。',
'trigger_reason':'DONE 后有效：bit0 电压、bit1 电流、bit2 手动。',
'record_pre_samples':'本次前触发样本对数；100% 前触发时等于 N。',
'record_ring_samples':'物理环形容量，8 对对齐并额外保留 8 对。',
'record_start_sample':'有效记录第一对样本的物理环形索引。',
'record_bytes':'有效记录字节数；每对 A/B 占 4 字节。',
'submitted_blocks':'MIG 已接受的 32 字节写突发次数，含环形覆盖，32 位回绕。',
'block_bytes':'当前读块有效字节数，最大 8192。',
'block_index':'当前读块序号，从 0 开始。',
'block_offset':'当前块在逻辑记录中的字节偏移。',
'block_last':'仅 BLOCK_READY 时解释为当前块是否末块。',
'record_done':'本条采集收尾完成，所有待写数据和命令已被 MIG 接受。',
'record_valid':'本条记录有效；溢出或取消时不能读为有效记录。',
'read_ready':'可请求下一块；没有当前块占用且还有剩余记录。',
'stream_done':'最后一块 ACK 已返回 UI 域。',
'rd_addr':'8 KiB 缓存的 16 位字地址，0～4095。',
'rd_valid':'本拍 rd_data 为有效返回；缓存读延迟为两拍。',
'reads_idle':'FMC 返回流水线为空；ACK 必须等待读操作结束。'
}
for p in (R/'rtl').glob('*.v'):
    s=p.read_text(encoding='utf-8')
    # Replace the original file-level description; retain executable directives.
    i=s.index('module ')
    s='`timescale 1ns/1ps\n`default_nettype none\n// '+descriptions[p.stem]+'\n// 接口协议与边界条件见同目录 '+p.stem+'_spec.md。\n'+s[i:]
    s=s.replace('记录有效�ֽ���','记录有效字节数')
    s=s.replace('已提交写块数','已提交的 32 字节 DDR 写突发数')
    s=s.replace('cfg_samples 单位为样本对，不是毫秒','cfg_samples 单位为 A/B 样本对，不是毫秒')
    # Literal layout substitutions only; no new Verilog parser or semantic rewrite.
    s=s.replace('),.', '),\n        .').replace('), .', '),\n        .')
    lines=[]
    for line in s.splitlines():
        stripped=line.strip()
        if stripped.startswith(('input wire ','output wire ','output reg ')) and '//' not in line:
            name=stripped.rstrip(',').split()[-1]
            if name in comments:line+=' // '+comments[name]
        lines.append(line.rstrip())
    p.write_text('\n'.join(lines)+'\n',encoding='utf-8')
    spec=f'''# {p.stem} 模块说明

{descriptions[p.stem]}

## 合同

- 本包版本：0x0200；时间单位 ns，Verilog-2001。
- 采样率固定 100 MSPS；N=1～20000000 对，时间设置 1～200 ms；两者最后一次设置生效。
- 前触发 P=floor(N×percent/100)，触发样本属于后触发；P=N 时触发样本不在返回记录内。
- 电压 A、电流 B 使用校正后的无符号 12 位码，比较码 0 >=、1 >、2 ==、3 <=、4 <；仅当前值比较。
- 两个有效通道条件按 OR 组合。手动模式忽略比较结果；自动模式无限等待，允许 ABORT。
- 每次 ARM/START 锁存配置；触发后冻结一条记录，读完 ACK/RELEASE 后再开始下一条。
- 地址范围、寄存器和命令完整定义见 ../docs/STM32对接协议.md。

## 时钟与复位

- ADC 接收/触发使用 ADC 返回时钟；采集控制与 MIG 使用 ui_clk；FMC/块消费使用 fmc_clk/rd_clk。
- 端口所属域以本模块连接为准：pack 全在 ADC 域，geometry/writer 全在 UI 域，reader/link 是跨域边界。
- 同一 mailbox 的两端一起复位，复位释放在各域同步；在记录有效期间不得单独复位一端。
- 沿用现有 CDC 约束，并添加 ../constraints/trigger_cdc_additions.xdc；禁止用整片时钟异步 false path 掩盖 mailbox 总线约束。

## 验证与限制

- 仿真入口：../sim/tb_trigger_capture.sv、tb_fmc_trigger_protocol.sv、tb_trigger_geometry.sv。
- 使用真实 XPM FIFO/RAM 模型；MIG 外部存储器由有背压、有读延迟的行为模型代替。
- 板级 IP、电气时序与布局布线验证不能由功能仿真替代；当前验证状态见 ../docs/验证说明.md。
'''
    (p.parent/(p.stem+'_spec.md')).write_text(spec,encoding='utf-8')
print('Updated Chinese semantic comments and module contracts; interfaces preserved.')
