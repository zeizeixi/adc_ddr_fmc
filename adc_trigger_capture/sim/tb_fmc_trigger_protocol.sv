`timescale 1ns/1ps
module tb_fmc_trigger_protocol;
    reg ui_clk=0,fmc_clk=0,ui_rst=1,fmc_rst=1;
    always #5 ui_clk=~ui_clk;
    always #8.929 fmc_clk=~fmc_clk;
    reg bus_read=0,bus_write=0;
    reg [23:0] bus_addr=0;
    reg [15:0] bus_wdata=0;
    reg [1:0] bus_mask=0;
    wire [15:0] register_data;
    wire memory_selected,clear_error;
    reg reads_idle=1,mode_valid=1,protocol_error=0;
    wire [31:0] cfg_samples;
    wire [6:0] cfg_pre_percent;
    wire cfg_auto_mode;
    wire [2:0] cfg_trigger_type_a,cfg_trigger_type_b;
    wire [1:0] cfg_trigger_enable;
    wire [11:0] cfg_threshold_a,cfg_threshold_b;
    wire cmd_arm,cmd_force,cmd_abort,cmd_start,cmd_release,cmd_read_next,cmd_ack,rd_en;
    wire [11:0] rd_addr;
    reg trigger_armed=0,history_ready=0,trigger_seen=0,capture_aborted=0;
    reg [2:0] trigger_reason=0;
    reg [31:0] record_pre_samples=0;
    reg ready=1,busy=0,done=0,valid=0,overflow=0,cfg_done=1,calib=1;
    reg read_ready=0,read_idle=1,stream_done=0,read_error=0,block_ready=0,block_last=0;
    reg accepted=0,rejected=0,read_accepted=0,ack_accepted=0,ack_rejected=0,rd_rejected=0;
    reg [31:0] record_samples=0,record_bytes=0,blocks=0,block_index=0,block_offset=0;
    reg [13:0] block_bytes=0;
    fmc_record_link dut(.*);
    integer arms=0,forces=0,aborts=0,starts=0,reads=0,acks=0,releases=0;
    reg [31:0] arm_n=0;
    reg [6:0] arm_pct=0;
    always @(posedge ui_clk) begin
        accepted<=cmd_arm || cmd_start;
        if(cmd_arm) begin arms=arms+1;arm_n=cfg_samples;arm_pct=cfg_pre_percent;end
        if(cmd_force) forces=forces+1;
        if(cmd_abort) aborts=aborts+1;
        if(cmd_start) starts=starts+1;
        if(cmd_read_next) reads=reads+1;
        if(cmd_release) releases=releases+1;
    end
    always @(posedge fmc_clk) begin
        ack_accepted<=cmd_ack;
        if(cmd_ack) begin acks=acks+1;block_ready<=0;end
    end
    task wr(input [23:0] address,input [15:0] value);
        begin
            @(negedge fmc_clk);bus_addr=address;bus_wdata=value;bus_write=1;
            @(negedge fmc_clk);bus_write=0;
        end
    endtask
    task check_reg(input [23:0] address,input [15:0] value);
        begin
            @(negedge fmc_clk);bus_addr=address;#1;
            if(register_data!==value) $fatal(1,"Register %h actual=%h expected=%h",address,register_data,value);
        end
    endtask
    task settle;
        begin repeat(150) @(negedge fmc_clk); end
    endtask
    initial begin
        #200;ui_rst=0;fmc_rst=0;settle();
        check_reg(0,16'hadfc);check_reg(2,16'h0200);check_reg(4,16'h2061);
        check_reg('h3c,16'he100);check_reg('h3e,16'h05f5);
        check_reg('h42,0);check_reg('h44,0);
        wr('h42,1);wr('h44,2);settle();
        if(cfg_trigger_type_a!=1 || cfg_trigger_type_b!=2) $fatal(1,"Trigger type FIFO");
        check_reg('h42,1);check_reg('h44,2);
        wr('h42,5);settle();check_reg('h42,1);check_reg('h4,16'h3061);
        wr('ha,5);settle();
        // Ordered configuration immediately followed by ARM; no arbitrary delay.
        wr('h28,16'h1234);wr('h2a,0);wr('h2c,37);wr('h2e,1);
        wr('h30,2345);wr('h32,3456);wr('h34,3);wr('ha,6);settle();
        if(arms!=1 || arm_n!='h1234 || arm_pct!=37 || !cfg_auto_mode ||
           cfg_threshold_a!=2345 || cfg_threshold_b!=3456 || cfg_trigger_enable!=3) $fatal(1,"Configuration FIFO ordering");
        check_reg('h28,16'h1234);check_reg('h2a,0);check_reg('h2c,37);
        check_reg('h2e,1);check_reg('h30,2345);check_reg('h32,3456);check_reg('h34,3);
        check_reg('h40,1);check_reg('h8,0);check_reg('h6,1);
        // Clear events, change to time length, then back to arbitrary sample count.
        wr('ha,5);wr('h8,200);settle();
        if(cfg_samples!=20000000) $fatal(1,"Time to samples");
        check_reg('h8,200);check_reg('h40,0);check_reg('h6,0);
        wr('h28,17);wr('h2a,0);settle();
        if(cfg_samples!=17) $fatal(1,"Point mode override");
        // Reject invalid config and partial write without changing its shadow.
        wr('h2c,101);wr('h30,4096);settle();
        check_reg('h2c,37);check_reg('h30,2345);check_reg('h4,16'h3061);
        wr('ha,5);settle();check_reg('h4,16'h2061);
        bus_mask=1;wr('h2c,20);bus_mask=0;settle();check_reg('h2c,37);
        wr('ha,5);settle();
        // FORCE requires armed/history ready; actual manual-mode check is in capture manager.
        wr('ha,7);settle();if(forces!=0) $fatal(1,"Early force passed");
        wr('ha,5);trigger_armed=1;history_ready=1;busy=1;ready=0;
        wr('ha,7);settle();if(forces!=1) $fatal(1,"Force missing");
        wr('ha,8);settle();if(aborts!=1) $fatal(1,"Abort missing");
        trigger_armed=0;history_ready=0;busy=0;ready=1;
        capture_aborted=1;settle();check_reg('h36,16'h0010);
        // Metadata, status and trigger reason cross as coherent snapshots.
        capture_aborted=0;trigger_seen=1;trigger_reason=3;record_pre_samples=32'h12345;
        ready=0;done=1;valid=1;read_ready=1;record_samples=4099;record_bytes=16396;blocks=1033;
        settle();check_reg('h36,16'h0064);check_reg('h38,16'h2345);check_reg('h3a,1);
        check_reg('h10,4099);check_reg('h14,16396);check_reg('h4,16'h20ec);
        wr('ha,2);settle();if(reads!=1) $fatal(1,"READ_NEXT mapping");
        block_ready=1;block_bytes=12;block_index=2;block_offset=16384;block_last=1;
        @(negedge fmc_clk);bus_addr='h200a;bus_read=1;#1;
        if(!memory_selected || !rd_en || rd_addr!=5) $fatal(1,"Window address");
        @(negedge fmc_clk);bus_read=0;bus_addr='h200c;#1;
        if(memory_selected) $fatal(1,"Window overrun");
        check_reg('h24,12);check_reg('h1c,2);
        wr('ha,3);settle();if(acks!=1) $fatal(1,"ACK mapping");
        wr('ha,4);settle();if(releases!=1) $fatal(1,"RELEASE mapping");
        done=0;valid=0;read_ready=0;ready=1;trigger_seen=0;trigger_reason=0;
        wr('h2c,0);wr('h2e,0);wr('ha,5);wr('ha,1);settle();
        if(starts!=1) $fatal(1,"Legacy START");
        $display("ALL FMC TRIGGER PROTOCOL TESTS PASSED");$finish;
    end
    initial begin #1000000;$fatal(1,"Timeout");end
endmodule
