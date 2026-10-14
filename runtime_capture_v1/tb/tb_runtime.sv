`timescale 1ns/1ps
module tb_runtime;
    reg ui_clk=0, adc_clk=0;
    always #5 ui_clk=~ui_clk;
    initial begin #1.3; forever #4.9 adc_clk=~adc_clk; end
    reg rst=1,ui_rst=1,calib=0,start=0,release_record=0;
    reg [31:0] cfg_samples=0;
    reg [11:0] da=0,db=12'h800;
    always @(negedge adc_clk) begin da<=da+1; db<=db+3; end
    wire ready,busy,done,valid,capture_finished,overflow,accepted,rejected,cfg_done;
    wire [31:0] samples,bytes_count,latched,blocks;
    wire [27:0] addr;
    wire [2:0] cmd;
    wire en,wren,wdf_end;
    wire [255:0] data;
    wire [31:0] mask;
    reg app_rdy=0,wdf_rdy=0,stall=0,random_stalls=1;
    reg [31:0] rng=32'h98231657;
    adc_capture_runtime #(.CFG_POWER_WAIT(5),.CFG_RESET_HIGH(3),.CFG_RESET_WAIT(3),.CFG_SETTLE(5)) dut(
        .ui_clk(ui_clk),.ui_rst(ui_rst),.global_rst(rst),.init_calib_complete(calib),
        .adc_clk_out(adc_clk),.adc_da(da),.adc_db(db),
        .adc_reset(),.adc_cs_n(),.adc_sck(),.adc_sdi(),.adc_ctrl(),
        .cfg_samples(cfg_samples),.cmd_start(start),.cmd_release(release_record),
        .ready(ready),.busy(busy),.cfg_done(cfg_done),.start_accepted(accepted),.command_rejected(rejected),
        .record_done(done),.record_valid(valid),.capture_finished(capture_finished),.overflow(overflow),
        .record_samples(samples),.record_bytes(bytes_count),.latched_samples(latched),.submitted_blocks(blocks),
        .app_addr(addr),.app_cmd(cmd),.app_en(en),.app_rdy(app_rdy),
        .app_wdf_data(data),.app_wdf_mask(mask),.app_wdf_wren(wren),.app_wdf_end(wdf_end),.app_wdf_rdy(wdf_rdy));
    always @(negedge ui_clk) begin
        rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
        app_rdy=!stall && (!random_stalls || rng[0] || rng[4]);
        wdf_rdy=!stall && (!random_stalls || rng[1] || rng[6]);
    end
    // Independent sample reference: external ADC pins delayed one input register.
    reg [31:0] previous_pair=0;
    reg [11:0] first_a=0,first_b=0,expected_a,expected_b;
    integer expected_n=0, source_count=0;
    reg collecting=0,compare_data=1;
    always @(posedge adc_clk) begin
        if(rst || ui_rst) begin collecting=0; source_count=0; end
        else begin
            if(collecting && source_count<expected_n) begin
                if(source_count==0) begin first_a=previous_pair[11:0];first_b=previous_pair[27:16];end
                source_count=source_count+1;
                if(source_count==expected_n) collecting=0;
            end
            if(dut.start_adc) begin source_count=0; collecting=1; end
        end
        previous_pair={4'b0,db,4'b0,da};
    end
    integer commands=0,reset_model=0,k,idx;
    reg pending_data=0;
    reg [255:0] held_data;
    reg old_data_stall=0,old_cmd_stall=0;
    reg [255:0] old_data;
    reg [27:0] old_addr;
    always @(posedge ui_clk) begin
        if(rst || ui_rst || reset_model) begin
            commands=0; pending_data=0; old_data_stall=0; old_cmd_stall=0;
        end else begin
            if(old_data_stall && (!wren || data!==old_data)) $fatal(1,"write data changed during stall");
            if(old_cmd_stall && (!en || addr!==old_addr)) $fatal(1,"command changed during stall");
            if(wren && wdf_rdy) begin
                if(pending_data) $fatal(1,"second data beat before previous command");
                if(mask!==0 || wdf_end!==1) $fatal(1,"invalid mask/end");
                held_data=data; pending_data=1;
            end
            if(en && app_rdy) begin
                if(!pending_data || cmd!==0 || addr!==commands*8) $fatal(1,"invalid command/order/address");
                if(compare_data) begin
                    for(k=0;k<8;k=k+1) begin
                        idx=commands*8+k;
                        if(idx<expected_n) begin
                            if(idx>=source_count) $fatal(1,"write precedes sample capture");
                            expected_a=first_a+idx; expected_b=first_b+idx*3;
                            if(held_data[k*32+:32]!=={4'b0,expected_b,4'b0,expected_a})
                                $fatal(1,"data mismatch sample=%0d got=%h",idx,held_data[k*32+:32]);
                        end else if(held_data[k*32+:32]!==0) $fatal(1,"nonzero tail");
                    end
                end
                pending_data=0; commands=commands+1;
            end
            old_data_stall=wren && !wdf_rdy; old_data=data;
            old_cmd_stall=en && !app_rdy; old_addr=addr;
        end
    end
    task automatic wait_ready;
        integer timeout;
        begin
            timeout=0;
            while(!ready) begin @(negedge ui_clk); timeout++; if(timeout>20000)$fatal(1,"ready timeout"); end
        end
    endtask
    task automatic launch(input integer n);
        begin
            wait_ready();
            @(negedge ui_clk); expected_n=n; reset_model=1; cfg_samples=n;
            @(negedge ui_clk); reset_model=0; start=1;
            @(negedge ui_clk); if(!accepted)$fatal(1,"start not accepted n=%0d t=%0t ready=%b rst=%b state=%d cfg=%b wrbusy=%b rdbusy=%b full=%b empty=%b idle=%b mail=%b clear=%b start_d=%b rejected=%b",n,$time,ready,dut.rst,dut.state,cfg_done,dut.wr_busy_ui,dut.rd_rst_busy,dut.full_ui,dut.empty,dut.pack_idle_ui,dut.start_mail_busy,dut.writer_clear,dut.start_d,rejected); start=0;
        end
    endtask
    task automatic wait_done;
        integer timeout;
        begin
            timeout=0;
            while(!done) begin @(negedge ui_clk); timeout++; if(timeout>expected_n+100000)$fatal(1,"record completion timeout"); end
        end
    endtask
    task automatic release_it;
        begin
            @(negedge ui_clk); release_record=1;
            @(negedge ui_clk); if(rejected)$fatal(1,"release rejected"); release_record=0;
            wait_ready();
        end
    endtask
    task automatic reject_start(input integer n);
        begin
            @(negedge ui_clk); cfg_samples=n; start=1;
            @(negedge ui_clk); if(!rejected || accepted)$fatal(1,"invalid start accepted"); start=0;
        end
    endtask
    task automatic good_record(input integer n);
        integer keep_commands;
        begin
            launch(n);
            // Configuration changes immediately after acceptance must be ignored.
            cfg_samples=3;
            wait_done();
            if(!valid || overflow || samples!=n || bytes_count!=n*4 || blocks!=(n+7)/8 || commands!=(n+7)/8 || latched!=n)
                $fatal(1,"record metadata mismatch n=%0d samples=%0d blocks=%0d",n,samples,blocks);
            keep_commands=commands;
            reject_start(12);
            repeat(10) @(negedge ui_clk);
            if(commands!=keep_commands || !done || !valid)$fatal(1,"record overwritten before release");
            $display("PASS record: %0d pairs, %0d blocks, cfg held, tail and contents",n,commands);
            release_it();
        end
    endtask
    initial begin
        #1000; @(negedge ui_clk); rst=0;ui_rst=0;calib=1;
        wait_ready(); reject_start(0); reject_start(20000001);
        good_record(1); good_record(2); good_record(3); good_record(4);
        good_record(5); good_record(6); good_record(7); good_record(8);
        good_record(9); good_record(15); good_record(16); good_record(16403);
        // Stop consumption long enough to finish sampling, but not overflow.
        stall=1; launch(101);
        reject_start(50);
        @(negedge ui_clk);release_record=1;
        @(negedge ui_clk);if(!rejected)$fatal(1,"release during RUN accepted");release_record=0;
        wait(capture_finished); repeat(30) @(negedge ui_clk);
        if(done || blocks!=0)$fatal(1,"capture-finished incorrectly treated as DDR completion");
        stall=0;wait_done();
        if(!valid || samples!=101 || commands!=13)$fatal(1,"drain completion failed");
        release_it();
        $display("PASS drain: no early record_done; busy commands rejected");
        // Real vendor FIFO full, then finish pending transactions and release.
        compare_data=0;stall=1;launch(10000);
        wait(overflow);repeat(20) @(negedge ui_clk);
        if(done)$fatal(1,"overflow record declared complete before drain");
        stall=0;wait_done();
        if(valid || !overflow || bytes_count!=0 || commands!=blocks)$fatal(1,"overflow not reported/drained");
        $display("PASS overflow: sampled=%0d, drained blocks=%0d, invalid record",samples,blocks);
        release_it();compare_data=1;good_record(17);
        // Coordinated reset discards both DUT and MIG handshake model state.
        launch(1000);wait(commands>5);
        @(negedge ui_clk);rst=1;ui_rst=1;calib=0;
        repeat(30) @(negedge ui_clk);
        rst=0;ui_rst=0;calib=1;
        good_record(33);
        if($test$plusargs("FULL_LENGTH")) begin
            $display("Running full 20,000,000-pair test...");
            good_record(20000000);
        end
        $display("PASS tb_runtime: ALL TESTS (actual FIFO, CDC mailbox, runtime sizes, stalls, tail, release, overflow recovery, coordinated reset)");
        $finish;
    end
    initial begin
        if($test$plusargs("FULL_LENGTH")) #600000000;
        else #5000000;
        $fatal(1,"global timeout");
    end
endmodule
