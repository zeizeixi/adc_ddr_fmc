from pathlib import Path
R=Path(__file__).parent
for p in (R/'rtl').glob('*.v'):
    s=p.read_text(encoding='utf-8')
    for name in ['trigger_type_a','trigger_type_b','cfg_trigger_type_a','cfg_trigger_type_b','fmc_trigger_type_a','fmc_trigger_type_b','type_a_q','type_b_q','type_a_fmc','type_b_fmc']:
        s=s.replace('[1:0] '+name,'[2:0] '+name)
    s=s.replace('0：电平超限；1：上升越阈；2：下降越阈。','0：>=；1：>；2：==；3：<=；4：<。')
    if p.name=='ads62p24_pack_runtime.v':
        for name in ['previous_valid','previous_above_a','previous_above_b']:
            s='\n'.join(line for line in s.splitlines() if not (line.strip().startswith('reg '+name) or line.strip().startswith(name+' <=')))+'\n'
        start=s.index('    wire above_a =')
        end=s.index('    wire manual_hit',start)
        s=s[:start]+'''    // 只比较当前校正码值，不检查前一个采样点，也不要求产生跳变。
    function level_matches;
        input [11:0] sample_code;
        input [11:0] threshold_code;
        input [2:0] comparison;
        begin
            case (comparison)
                3'd0: level_matches = sample_code >= threshold_code;
                3'd1: level_matches = sample_code >  threshold_code;
                3'd2: level_matches = sample_code == threshold_code;
                3'd3: level_matches = sample_code <= threshold_code;
                3'd4: level_matches = sample_code <  threshold_code;
                default: level_matches = 1'b0; // 保留编码不触发；UI 同时拒绝非法配置。
            endcase
        end
    endfunction
    wire hit_a = enable_q[0] && level_matches(adc_a_corrected, threshold_a_q, type_a_q);
    wire hit_b = enable_q[1] && level_matches(adc_b_corrected, threshold_b_q, type_b_q);
'''+s[end:]
    if p.name=='adc_capture_runtime.v':
        s=s.replace('[127:0] config_adc','[129:0] config_adc').replace('WIDTH(128)) u_start_mail','WIDTH(130)) u_start_mail')
        s=s.replace('config_adc[127:126]','config_adc[129:127]').replace('config_adc[125:124]','config_adc[126:124]')
        s=s.replace('cfg_trigger_type_a<=2 && cfg_trigger_type_b<=2','cfg_trigger_type_a<=4 && cfg_trigger_type_b<=4')
    if p.name=='fmc_record_link.v':
        s=s.replace("bus_addr==24'h000044) && bus_wdata<=2)","bus_addr==24'h000044) && bus_wdata<=4)")
        s=s.replace("{14'b0,type_a_fmc}","{13'b0,type_a_fmc}").replace("{14'b0,type_b_fmc}","{13'b0,type_b_fmc}")
        for name in ['type_a_fmc','type_b_fmc']:
            s=s.replace(name+'<=bus_wdata[1:0]',name+'<=bus_wdata[2:0]')
        for name in ['cfg_trigger_type_a','cfg_trigger_type_b']:
            s=s.replace(name+'<=queued_data[1:0]',name+'<=queued_data[2:0]')
    if p.name=='adc_ddr_fbg484_top.v':
        s=s.replace("fmc_trigger_type_a : 2'd0","fmc_trigger_type_a : 3'd0").replace("fmc_trigger_type_b : 2'd0","fmc_trigger_type_b : 3'd0")
    p.write_text(s,encoding='utf-8')

p=R/'sim/tb_trigger_capture.sv';s=p.read_text(encoding='utf-8')
s=s.replace('reg [1:0] cfg_trigger_type_a','reg [2:0] cfg_trigger_type_a')
s=s.replace('    reg [11:0] older_a=0,older_b=0;','    reg fixed_input=0;\n    reg [11:0] fixed_code=3500;')
s=s.replace('        if (hit_kind==2 || hit_kind==3) adc_db=~12\'d3500;',"        if (hit_kind==2 || hit_kind==3) adc_db=~12'd3500;\n        if (fixed_input) begin adc_da=~fixed_code;adc_db=~fixed_code;end")
start=s.index('            eligible_a=')
end=s.index('            if (cfg_auto_mode',start)
s=s[:start]+'''            eligible_a=(cfg_trigger_type_a==0 && sampled_a>=3500) ||
                (cfg_trigger_type_a==1 && sampled_a>3500) ||
                (cfg_trigger_type_a==2 && sampled_a==3500) ||
                (cfg_trigger_type_a==3 && sampled_a<=3500) ||
                (cfg_trigger_type_a==4 && sampled_a<3500);
            eligible_b=(cfg_trigger_type_b==0 && sampled_b>=3500) ||
                (cfg_trigger_type_b==1 && sampled_b>3500) ||
                (cfg_trigger_type_b==2 && sampled_b==3500) ||
                (cfg_trigger_type_b==3 && sampled_b<=3500) ||
                (cfg_trigger_type_b==4 && sampled_b<3500);
'''+s[end:]
s=s.replace('        older_a=sampled_a;older_b=sampled_b;\n','')
start=s.index('    task run_edge(');end=s.index('    integer k,old_reject;',start)
s=s[:start]+'''    // Truth tables use bit 0/1/2 for threshold-1 / threshold / threshold+1.
    task run_comparison(input integer channel,input integer op,input [2:0] truth);
        integer q;
        begin
            for(q=0;q<3;q=q+1) begin
                wait_ready();cfg_samples=37;cfg_pre_percent=50;cfg_auto_mode=1;
                cfg_trigger_enable=channel;cfg_trigger_type_a=op;cfg_trigger_type_b=op;
                fixed_input=1;fixed_code=3499+q;hit_kind=0;trigger_tick=-1;
                repeat(4) @(negedge adc_clk_out);
                pulse_command(6);
                if(truth[q]) read_record(37,18,channel);
                else begin
                    wait_history();repeat(200) @(negedge ui_clk);
                    if(trigger_seen || record_done) $fatal(1,"Comparison false positive op=%d sample=%d",op,fixed_code);
                    pulse_command(8);wait_ready();
                    if(!capture_aborted) $fatal(1,"Comparison cancel");
                end
                fixed_input=0;
            end
            $display("PASS comparator channel=%0d op=%0d boundary cases",channel,op);
        end
    endtask

'''+s[end:]
start=s.index('        run_edge(');end=s.index('        $display("ALL TRIGGER',start)
s=s[:start]+'''        run_comparison(1,0,3'b110);run_comparison(2,0,3'b110);
        run_comparison(1,1,3'b100);run_comparison(2,1,3'b100);
        run_comparison(1,2,3'b010);run_comparison(2,2,3'b010);
        run_comparison(1,3,3'b011);run_comparison(2,3,3'b011);
        run_comparison(1,4,3'b001);run_comparison(2,4,3'b001);
        // Independently configured A < threshold OR B == threshold.
        cfg_samples=45;cfg_pre_percent=40;cfg_auto_mode=1;cfg_trigger_enable=3;
        cfg_trigger_type_a=4;cfg_trigger_type_b=2;hit_kind=3;trigger_tick=-1;
        pulse_command(6);read_record(45,18,2);hit_kind=0;
'''+s[end:]
p.write_text(s,encoding='utf-8')
p=R/'sim/tb_fmc_trigger_protocol.sv';s=p.read_text(encoding='utf-8')
s=s.replace('wire [1:0] cfg_trigger_type_a','wire [2:0] cfg_trigger_type_a')
s=s.replace("wr('h42,3)","wr('h42,5)")
p.write_text(s,encoding='utf-8')
print('Final protocol: unsigned current-sample comparisons >=, >, ==, <=, <. No edge detectors.')
