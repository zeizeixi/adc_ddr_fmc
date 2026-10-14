`timescale 1ns/1ps
module tb_trigger_capture;
    reg ui_clk=0, adc_clk_out=0, rd_clk=0;
    always #5 ui_clk=~ui_clk;
    initial begin #2; forever #5 adc_clk_out=~adc_clk_out; end
    always #8.929 rd_clk=~rd_clk;
    reg ui_rst=1,global_rst=1,init_calib_complete=0;
    reg [13:2] adc_da=12'hfff,adc_db=12'hfff;
    wire adc_reset,adc_cs_n,adc_sck,adc_sdi;
    wire [2:0] adc_ctrl;
    reg [31:0] cfg_samples=17;
    reg [6:0] cfg_pre_percent=50;
    reg cfg_auto_mode=0;
    reg [2:0] cfg_trigger_type_a=0,cfg_trigger_type_b=0;
    reg [1:0] cfg_trigger_enable=3;
    reg [11:0] cfg_threshold_a=3500,cfg_threshold_b=3500;
    reg cmd_arm=0,cmd_force=0,cmd_abort=0,cmd_start=0,cmd_release=0,cmd_read_next=0;
    wire trigger_armed,history_ready,trigger_seen,capture_aborted;
    wire [2:0] trigger_reason;
    wire [31:0] record_pre_samples;
    wire ready,busy,cfg_done,start_accepted,command_rejected,record_done,record_valid,capture_finished,overflow;
    wire [31:0] record_samples,record_bytes,latched_samples,submitted_blocks;
    wire read_ready,read_accepted,read_idle,stream_done,read_error;
    wire [27:0] app_addr;
    wire [2:0] app_cmd;
    wire app_en;
    reg app_rdy=0;
    wire [255:0] app_wdf_data;
    wire [31:0] app_wdf_mask;
    wire app_wdf_wren,app_wdf_end;
    reg app_wdf_rdy=0;
    reg [255:0] app_rd_data=0;
    reg app_rd_data_valid=0,app_rd_data_end=0;
    reg rd_en=0;
    reg [11:0] rd_addr=0;
    wire [15:0] rd_data;
    wire rd_valid,block_ready;
    wire [31:0] block_index,block_offset;
    wire [13:0] block_bytes;
    wire block_last;
    reg cmd_block_ack=0;
    wire ack_accepted,ack_rejected,rd_rejected;
    adc_record_store #(.CFG_POWER_WAIT(4),.CFG_RESET_HIGH(4),.CFG_RESET_WAIT(4),.CFG_SETTLE(4)) dut (.*);

    // Ordered MIG model: command and write-data backpressure are independent.
    reg [255:0] memory [0:16383];
    reg [255:0] wdf_buffer;
    reg wdf_pending=0;
    integer cycles=0, read_delay=0, read_index=0;
    reg stall_write=0;
    always @(negedge ui_clk) begin
        app_rdy=init_calib_complete && (cycles%5!=0) && !stall_write;
        app_wdf_rdy=init_calib_complete && (cycles%7!=0) && !stall_write;
    end
    always @(posedge ui_clk) begin
        cycles<=cycles+1;
        app_rd_data_valid<=0; app_rd_data_end<=0;
        if (app_wdf_wren && app_wdf_rdy) begin
            if (wdf_pending || !app_wdf_end || app_wdf_mask!=0) $fatal(1,"WDF protocol");
            wdf_buffer<=app_wdf_data; wdf_pending<=1;
        end
        if (app_en && app_rdy) begin
            if (app_addr[2:0]!=0 || app_addr/8>=16384) $fatal(1,"DDR address %h",app_addr);
            if (app_cmd==0) begin
                if (!wdf_pending) $fatal(1,"Missing WDF");
                memory[app_addr/8]<=wdf_buffer; wdf_pending<=0;
            end else if (app_cmd==1) begin
                if (read_delay!=0) $fatal(1,"Multiple read requests");
                read_index<=app_addr/8; read_delay<=3+cycles%4;
            end else $fatal(1,"Bad MIG command");
        end
        if (read_delay>0) begin
            read_delay<=read_delay-1;
            if (read_delay==1) begin
                app_rd_data<=memory[read_index];
                app_rd_data_valid<=1; app_rd_data_end<=1;
            end
        end
        if (read_error) $fatal(1,"Reader fault");
    end

    // Independent sample history models the input flip-flops, not DDR layout.
    reg [31:0] history [0:999999];
    reg [11:0] sampled_a=0,sampled_b=0;
    reg fixed_input=0;
    reg [11:0] fixed_code=3500;
    reg eligible_a,eligible_b;
    integer ticks=0, trigger_tick=-1, hit_kind=0, arm_tick=0;
    integer reject_count=0, accepted_count=0;
    always @(posedge ui_clk) begin
        if (command_rejected) reject_count=reject_count+1;
        if (start_accepted) accepted_count=accepted_count+1;
    end
    always @(negedge adc_clk_out) begin
        adc_da=~(12'(ticks%1000+100));
        adc_db=~(12'((ticks*7)%1000+1200));
        if (hit_kind==1 || hit_kind==3) adc_da=~12'd3500;
        if (hit_kind==2 || hit_kind==3) adc_db=~12'd3500;
        if (fixed_input) begin adc_da=~fixed_code;adc_db=~fixed_code;end
    end
    always @(posedge adc_clk_out) begin
        history[ticks]={4'b0,sampled_b,4'b0,sampled_a};
        if (dut.u_capture.start_adc) arm_tick=ticks+1;
        if (dut.u_capture.u_pack.trigger_now) begin
            trigger_tick=ticks;
            if (ticks-arm_tick<record_pre_samples) $fatal(1,"Insufficient prehistory");
            eligible_a=(cfg_trigger_type_a==0 && sampled_a>=3500) ||
                (cfg_trigger_type_a==1 && sampled_a>3500) ||
                (cfg_trigger_type_a==2 && sampled_a==3500) ||
                (cfg_trigger_type_a==3 && sampled_a<=3500) ||
                (cfg_trigger_type_a==4 && sampled_a<3500);
            eligible_b=(cfg_trigger_type_b==0 && sampled_b>=3500) ||
                (cfg_trigger_type_b==1 && sampled_b>3500) ||
                (cfg_trigger_type_b==2 && sampled_b==3500) ||
                (cfg_trigger_type_b==3 && sampled_b<=3500) ||
                (cfg_trigger_type_b==4 && sampled_b<3500);
            if (cfg_auto_mode && !((cfg_trigger_enable[0] && eligible_a) ||
                                  (cfg_trigger_enable[1] && eligible_b)))
                $fatal(1,"Invalid auto_test trigger");
        end
        sampled_a=~adc_da; sampled_b=~adc_db;
        ticks=ticks+1;
    end

    task wait_ready;
        integer timeout;
        begin
            timeout=0;
            while (!ready) begin @(negedge ui_clk); timeout=timeout+1;
                if (timeout>30000) $fatal(1,"READY timeout state=%d",dut.u_capture.state);
            end
        end
    endtask
    task pulse_command(input integer code);
        begin
            @(negedge ui_clk);
            case(code)
                1:cmd_start=1; 2:cmd_read_next=1; 4:cmd_release=1;
                6:cmd_arm=1; 7:cmd_force=1; 8:cmd_abort=1;
            endcase
            @(negedge ui_clk);
            cmd_start=0;cmd_read_next=0;cmd_release=0;cmd_arm=0;cmd_force=0;cmd_abort=0;
        end
    endtask
    task wait_history;
        integer timeout;
        begin
            timeout=0;
            while (!history_ready) begin @(negedge ui_clk); timeout=timeout+1;
                if(timeout>150000) $fatal(1,"History timeout");
            end
        end
    endtask
    task wait_done;
        integer timeout;
        begin
            timeout=0;
            while (!record_done) begin @(negedge ui_clk); timeout=timeout+1;
                if(timeout>200000) $fatal(1,"DONE timeout state=%d result=%h written=%d",dut.u_capture.state,dut.u_capture.result_q,submitted_blocks);
            end
        end
    endtask
    task read_record(input integer n,input integer pre,input integer expected_reason);
        integer offset,j,total,timeout,first,expected_len,blockno;
        reg [15:0] expected;
        begin
            wait_done();
            if (!record_valid || overflow || record_samples!=n || record_bytes!=n*4 || record_pre_samples!=pre)
                $fatal(1,"Metadata N=%d actual=%d pre=%d expected=%d valid=%b overflow=%b",n,record_samples,record_pre_samples,pre,record_valid,overflow);
            if (trigger_reason!=expected_reason) $fatal(1,"Reason actual=%d expected=%d",trigger_reason,expected_reason);
            if(trigger_tick<0) $fatal(1,"No trigger");
            first=trigger_tick-pre; offset=0; blockno=0;
            while(offset<n*4) begin
                timeout=0;
                while(!read_ready) begin @(negedge ui_clk); timeout=timeout+1;
                    if(timeout>500) $fatal(1,"READ_READY timeout"); end
                pulse_command(2);
                timeout=0;
                while(!block_ready) begin @(negedge rd_clk); timeout=timeout+1;
                    if(timeout>20000) $fatal(1,"BLOCK_READY timeout"); end
                expected_len=(n*4-offset>8192)?8192:n*4-offset;
                if(block_bytes!=expected_len || block_offset!=offset || block_index!=blockno ||
                   block_last!=(offset+expected_len==n*4)) $fatal(1,"Block metadata");
                for(j=0;j<expected_len/2;j=j+1) begin
                    @(negedge rd_clk); rd_addr=j; rd_en=1;
                    @(negedge rd_clk); rd_en=0;
                    timeout=0;
                    while(!rd_valid) begin @(negedge rd_clk); timeout=timeout+1;
                        if(timeout>5) $fatal(1,"RAM response timeout"); end
                    total=offset/2+j;
                    expected=history[first+total/2] >> ((total%2)*16);
                    if(rd_data!==expected) $fatal(1,"Sample mismatch N=%d pre=%d word=%d actual=%h expected=%h trigger=%d start=%d",n,pre,total,rd_data,expected,trigger_tick,dut.record_start_sample);
                end
                repeat(3) @(negedge rd_clk);
                cmd_block_ack=1;
                @(negedge rd_clk);
                if(!ack_accepted) $fatal(1,"ACK rejected");
                cmd_block_ack=0;
                offset=offset+expected_len;blockno=blockno+1;
            end
            timeout=0;
            while(!stream_done || !read_idle) begin @(negedge ui_clk); timeout=timeout+1;
                if(timeout>500) $fatal(1,"Last ACK timeout"); end
            pulse_command(4); wait_ready();
            if(record_valid || record_done) $fatal(1,"RELEASE did not clear");
            $display("PASS record N=%0d pre=%0d reason=%0d blocks=%0d",n,pre,expected_reason,blockno);
        end
    endtask
    task run_case(input integer n,input integer pct,input integer auto_test,input integer mask,input integer hit);
        integer pre;
        begin
            wait_ready();
            cfg_samples=n;cfg_pre_percent=pct;cfg_auto_mode=auto_test;cfg_trigger_enable=mask;
            cfg_trigger_type_a=0;cfg_trigger_type_b=0;
            hit_kind=0;trigger_tick=-1;pre=(n*pct)/100;
            pulse_command(6);wait_history();
            // Multiple complete physical ring wraps before the trigger.
            repeat(3*(n+16)+11) @(negedge adc_clk_out);
            if(record_done || trigger_seen) $fatal(1,"Spurious trigger");
            if(auto_test) hit_kind=hit; else pulse_command(7);
            read_record(n,pre,auto_test?hit:4);
            hit_kind=0;
        end
    endtask

    // Truth tables use bit 0/1/2 for threshold-1 / threshold / threshold+1.
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

    integer k,old_reject;
    initial begin
        #200;ui_rst=0;global_rst=0;init_calib_complete=1;
        wait_ready();
        run_case(1,0,0,3,0);
        run_case(1,100,0,3,0);
        run_case(8,50,0,3,0);
        run_case(17,1,0,3,0);
        run_case(17,33,0,3,0);
        run_case(17,50,0,3,0);
        run_case(17,99,0,3,0);
        run_case(17,100,0,3,0);
        run_case(4099,17,0,3,0);
        run_case(43,25,1,1,1);
        run_case(43,75,1,2,2);
        run_case(43,50,1,3,3);
        // Already above threshold when ARM begins: no edge required.
        cfg_samples=31;cfg_pre_percent=50;cfg_auto_mode=1;cfg_trigger_enable=1;
        hit_kind=1;trigger_tick=-1;
        pulse_command(6);read_record(31,15,1);hit_kind=0;
        // Legacy command still records immediately, with zero prehistory.
        cfg_samples=19;cfg_pre_percent=0;cfg_auto_mode=0;trigger_tick=-1;
        pulse_command(1);read_record(19,0,4);
        // Invalid count and incompatible legacy START must be rejected.
        old_reject=reject_count;cfg_samples=0;pulse_command(6);repeat(10) @(negedge ui_clk);
        if(reject_count==old_reject || busy) $fatal(1,"Invalid count accepted");
        cfg_samples=17;cfg_pre_percent=50;old_reject=reject_count;pulse_command(1);repeat(10) @(negedge ui_clk);
        if(reject_count==old_reject || busy) $fatal(1,"Legacy pretrigger accepted");
        // Cancel preparation before launching ADC.
        pulse_command(6);pulse_command(8);wait_ready();
        if(!capture_aborted || record_valid) $fatal(1,"PREP abort");
        // Cancel indefinite auto_test wait, then successfully acquire again.
        cfg_auto_mode=1;pulse_command(6);wait_history();repeat(100) @(negedge ui_clk);
        pulse_command(8);wait_ready();
        if(!capture_aborted || record_valid) $fatal(1,"Waiting abort");
        // ABORT during start-mailbox crossing must not be lost.
        pulse_command(6);
        wait(dut.u_capture.state==1);
        pulse_command(8);wait_ready();
        if(!capture_aborted || record_valid) $fatal(1,"Launch abort");
        // Manual force too early is rejected; staged changes do not alter active N.
        cfg_auto_mode=0;cfg_samples=2000;cfg_pre_percent=90;
        pulse_command(6);wait(trigger_armed);old_reject=reject_count;
        pulse_command(7);repeat(5) @(negedge ui_clk);
        if(reject_count==old_reject) $fatal(1,"Force before prefill accepted");
        cfg_samples=21;cfg_pre_percent=0;
        wait_history();pulse_command(7);read_record(2000,1800,4);
        // Abort post-trigger capture while the FORCE mailbox is returning.
        cfg_samples=10000;cfg_pre_percent=0;cfg_auto_mode=0;
        pulse_command(6);wait_history();pulse_command(7);pulse_command(8);wait_ready();
        if(!capture_aborted || record_valid) $fatal(1,"Post-trigger abort");
        // Disabled A threshold must not trigger a B-only capture.
        cfg_samples=37;cfg_pre_percent=50;cfg_auto_mode=1;cfg_trigger_enable=2;
        hit_kind=1;trigger_tick=-1;pulse_command(6);wait_history();
        repeat(200) @(negedge ui_clk);
        if(trigger_seen || record_done) $fatal(1,"Disabled channel triggered");
        hit_kind=2;read_record(37,18,2);hit_kind=0;
        run_case(29,90,0,3,0);
        // FIFO overflow must invalidate the entire record, then recover on RELEASE.
        cfg_samples=10000;cfg_pre_percent=0;cfg_auto_mode=1;stall_write=1;
        pulse_command(6);repeat(6000) @(negedge adc_clk_out);stall_write=0;wait_done();
        if(!overflow || record_valid || record_bytes!=0) $fatal(1,"Overflow not reported");
        pulse_command(4);wait_ready();
        run_case(23,100,0,3,0);
        run_comparison(1,0,3'b110);run_comparison(2,0,3'b110);
        run_comparison(1,1,3'b100);run_comparison(2,1,3'b100);
        run_comparison(1,2,3'b010);run_comparison(2,2,3'b010);
        run_comparison(1,3,3'b011);run_comparison(2,3,3'b011);
        run_comparison(1,4,3'b001);run_comparison(2,4,3'b001);
        // Independently configured A < threshold OR B == threshold.
        cfg_samples=45;cfg_pre_percent=40;cfg_auto_mode=1;cfg_trigger_enable=3;
        cfg_trigger_type_a=4;cfg_trigger_type_b=2;hit_kind=3;trigger_tick=-1;
        pulse_command(6);read_record(45,18,2);hit_kind=0;
        $display("ALL TRIGGER CAPTURE TESTS PASSED");$finish;
    end
    initial begin #20000000; $fatal(1,"Global timeout"); end
endmodule
