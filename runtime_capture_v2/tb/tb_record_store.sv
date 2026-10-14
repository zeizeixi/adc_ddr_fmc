`timescale 1ns/1ps
module tb_record_store;
    reg ui_clk=0,adc_clk=0,rd_clk=0;
    always #5 ui_clk=~ui_clk;
    initial begin #1.3;forever #4.9 adc_clk=~adc_clk;end
    initial begin #2.7;forever #6.7 rd_clk=~rd_clk;end
    reg rst=1,ui_rst=1,calib=0,start=0,release_record=0,next_block=0;
    reg [31:0] cfg=0;
    reg [11:0] da=0,db=12'h345;
    always @(negedge adc_clk) begin da<=da+1;db<=db+3;end
    reg rd_en=0,ack=0;reg [11:0] rd_addr=0;
    wire [15:0] rd_data;wire rd_valid,block_ready,block_last,ack_ok,ack_bad,rd_bad;
    wire [31:0] block_idx,block_offset;wire [13:0] block_bytes;
    wire ready,busy,done,valid,accepted,rejected,read_ready,read_accepted,read_idle,stream_done,read_error;
    wire [31:0] samples,bytes_count,submitted;
    wire [27:0] addr;wire [2:0] cmd;wire en,wren,wdf_end;
    wire [255:0] wdata;wire [31:0] mask;
    reg app_rdy=0,wdf_rdy=0,rvalid=0,rend=0;
    reg [255:0] rdata=0;
    reg stall_cmd=0,stall_response=0,bad_end_once=0,inject_unsolicited=0;
    localparam BASE=128;
    adc_record_store #(.BASE_APP_ADDR(BASE),.CFG_POWER_WAIT(5),.CFG_RESET_HIGH(3),.CFG_RESET_WAIT(3),.CFG_SETTLE(5)) dut(
        .ui_clk(ui_clk),.ui_rst(ui_rst),.global_rst(rst),.init_calib_complete(calib),
        .adc_clk_out(adc_clk),.adc_da(da),.adc_db(db),.adc_reset(),.adc_cs_n(),.adc_sck(),.adc_sdi(),.adc_ctrl(),
        .cfg_samples(cfg),.cmd_start(start),.cmd_release(release_record),.cmd_read_next(next_block),
        .ready(ready),.busy(busy),.cfg_done(),.start_accepted(accepted),.command_rejected(rejected),
        .record_done(done),.record_valid(valid),.capture_finished(),.overflow(),
        .record_samples(samples),.record_bytes(bytes_count),.latched_samples(),.submitted_blocks(submitted),
        .read_ready(read_ready),.read_accepted(read_accepted),.read_idle(read_idle),.stream_done(stream_done),.read_error(read_error),
        .app_addr(addr),.app_cmd(cmd),.app_en(en),.app_rdy(app_rdy),
        .app_wdf_data(wdata),.app_wdf_mask(mask),.app_wdf_wren(wren),.app_wdf_end(wdf_end),.app_wdf_rdy(wdf_rdy),
        .app_rd_data(rdata),.app_rd_data_valid(rvalid),.app_rd_data_end(rend),
        .rd_clk(rd_clk),.rd_en(rd_en),.rd_addr(rd_addr),.rd_data(rd_data),.rd_valid(rd_valid),
        .block_ready(block_ready),.block_index(block_idx),.block_offset(block_offset),.block_bytes(block_bytes),.block_last(block_last),
        .cmd_block_ack(ack),.ack_accepted(ack_ok),.ack_rejected(ack_bad),.rd_rejected(rd_bad));
    // Independent memory model: accept WDF, commit on command, queue read replies.
    reg [255:0] memory [0:8191];
    integer read_queue[0:8191];integer qhead=0,qtail=0;
    integer write_count=0,read_count=0,reply_count=0,model_clear=0;
    reg pending=0;reg [255:0] pending_data;
    reg prev_stall=0;reg [27:0] prev_addr;reg [2:0] prev_cmd;
    reg [31:0] rng=32'h689af124;
    always @(negedge ui_clk) begin
        rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
        app_rdy=!stall_cmd && (rng[0] || rng[4]);wdf_rdy=rng[1] || rng[6];
        rvalid=0;rend=0;
        if(rst || ui_rst || model_clear) begin qhead=0;reply_count=0;end
        else if(inject_unsolicited) begin rvalid=1;rend=1;rdata=0;inject_unsolicited=0;end
        else if(!stall_response && qhead<qtail && (rng[3] || rng[7])) begin
            rdata=memory[read_queue[qhead]];rvalid=1;rend=!bad_end_once;
            bad_end_once=0;qhead=qhead+1;reply_count=reply_count+1;
        end
    end
    always @(posedge ui_clk) begin
        if(rst || ui_rst || model_clear) begin qtail=0;write_count=0;read_count=0;pending=0;prev_stall=0;end
        else begin
            if(prev_stall && (!en || addr!==prev_addr || cmd!==prev_cmd))$fatal(1,"MIG stalled command changed");
            if(wren && wdf_rdy) begin
                if(pending || mask!==0 || !wdf_end)$fatal(1,"bad write-data handshake");
                pending=1;pending_data=wdata;
            end
            if(en && app_rdy) begin
                if(cmd==0) begin
                    if(!pending || addr!=BASE+write_count*8 || done)$fatal(1,"bad write command/ownership");
                    memory[addr>>3]=pending_data;pending=0;write_count=write_count+1;
                end else if(cmd==1) begin
                    if(!done || !valid || addr!=BASE+read_count*8 || read_count>=write_count)
                        $fatal(1,"bad read range/order/ownership addr=%0d count=%0d",addr,read_count);
                    read_queue[qtail]=addr>>3;qtail=qtail+1;read_count=read_count+1;
                    if(qtail-qhead>256)$fatal(1,"unreserved responses exceed 8 KiB capacity");
                end else $fatal(1,"unexpected MIG command");
            end
            prev_stall=en && !app_rdy;prev_addr=addr;prev_cmd=cmd;
            if(dut.u_reader.store && block_ready)$fatal(1,"buffer overwritten while consumer owns it");
        end
    end
    reg [31:0] previous_pair=0;reg collecting=0;integer source_count=0,expected_n=0;
    reg [11:0] first_a=0,first_b=0;
    always @(posedge adc_clk) begin
        if(rst || ui_rst) begin collecting=0;source_count=0;end
        else begin
            if(collecting && source_count<expected_n) begin
                if(source_count==0)begin first_a=previous_pair[11:0];first_b=previous_pair[27:16];end
                source_count=source_count+1;if(source_count==expected_n)collecting=0;
            end
            if(dut.u_capture.start_adc)begin collecting=1;source_count=0;end
        end
        previous_pair={4'b0,db,4'b0,da};
    end
    function automatic [15:0] expected_half(input integer word_index);
        reg [11:0] v;
        begin
            if(word_index%2==0)v=first_a+word_index/2;
            else v=first_b+(word_index/2)*3;
            expected_half={4'b0,v};
        end
    endfunction
    task automatic wait_idle_ready;
        integer t;
        begin t=0;while(!ready)begin @(negedge ui_clk);t++;if(t>20000)$fatal(1,"ready timeout");end end
    endtask
    task automatic launch(input integer n);
        integer t;
        begin
            wait_idle_ready();@(negedge ui_clk);model_clear=1;expected_n=n;cfg=n;
            repeat(2)@(negedge ui_clk);model_clear=0;start=1;
            @(negedge ui_clk);if(!accepted)$fatal(1,"start rejected");start=0;cfg=1;
            t=0;while(!done)begin @(negedge ui_clk);t++;if(t>50000)$fatal(1,"capture timeout");end
            if(!valid || samples!=n || bytes_count!=n*4 || submitted!=(n+7)/8)$fatal(1,"bad record metadata");
        end
    endtask
    task automatic request_block;
        begin
            @(negedge ui_clk);next_block=1;
            @(negedge ui_clk);if(!read_accepted)$fatal(1,"read request rejected");next_block=0;
        end
    endtask
    task automatic wait_block;
        integer t;
        begin t=0;while(!block_ready)begin @(negedge rd_clk);t++;if(t>10000)$fatal(1,"block timeout");end end
    endtask
    task automatic read_word(input integer a);
        begin
            @(negedge rd_clk);rd_addr=a;rd_en=1;
            @(negedge rd_clk);rd_en=0;
            @(negedge rd_clk);
            if(!rd_valid || rd_data!==expected_half((block_offset>>1)+a))
                $fatal(1,"RAM read mismatch offset=%0d a=%0d got=%h expected=%h valid=%b",block_offset,a,rd_data,expected_half((block_offset>>1)+a),rd_valid);
            @(negedge rd_clk);
        end
    endtask
    task automatic ack_block(input integer keep_high);
        integer t;
        begin
            @(negedge rd_clk);ack=1;
            @(negedge rd_clk);if(!ack_ok || block_ready)$fatal(1,"ACK failed");
            if(!keep_high)ack=0;
            t=0;while(!read_idle)begin @(negedge ui_clk);t++;if(t>1000)$fatal(1,"ACK handshake timeout");end
        end
    endtask
    task automatic release_it;
        begin
            @(negedge ui_clk);release_record=1;
            @(negedge ui_clk);if(rejected || done)$fatal(1,"record release failed");release_record=0;
            wait_idle_ready();
        end
    endtask
    task automatic reject_ui_commands;
        begin
            @(negedge ui_clk);next_block=1;
            @(negedge ui_clk);if(!rejected)$fatal(1,"next block allowed while buffer owned");next_block=0;
            @(negedge ui_clk);release_record=1;
            @(negedge ui_clk);if(!rejected || !done)$fatal(1,"release allowed while reader busy");release_record=0;
            @(negedge ui_clk);start=1;
            @(negedge ui_clk);if(!rejected || accepted)$fatal(1,"capture allowed while reader busy");start=0;
        end
    endtask
    task automatic complete_record(input integer n,input integer test_stalls);
        integer b,a,len,count_before;
        begin
            launch(n);b=0;
            while(!stream_done)begin
                if(test_stalls && b==0)begin stall_response=1;stall_cmd=1;end
                request_block();
                if(test_stalls && b==0)begin
                    repeat(20)@(negedge ui_clk);if(block_ready)$fatal(1,"block published without commands");
                    stall_cmd=0;repeat(350)@(negedge ui_clk);
                    if(block_ready)$fatal(1,"block published before replies");stall_response=0;
                end
                wait_block();len=((n*4-b*8192)>8192)?8192:(n*4-b*8192);
                if(block_idx!=b || block_offset!=b*8192 || block_bytes!=len || block_last!=(b*8192+len==n*4))
                    $fatal(1,"block descriptor mismatch");
                // Holding the previous ACK high must not release the new block.
                if(ack)begin repeat(10)@(negedge rd_clk);if(!block_ready)$fatal(1,"held ACK consumed next block");ack=0;end
                reject_ui_commands();count_before=read_count;
                for(a=0;a<len/2;a++)read_word(a);
                read_word(len/2-1);read_word(0);
                repeat(8)@(negedge rd_clk);
                if(!block_ready || read_count!=count_before)$fatal(1,"last address automatically released/refilled block");
                if(len<8192)begin
                    @(negedge rd_clk);rd_addr=len/2;rd_en=1;
                    @(negedge rd_clk);if(!rd_bad)$fatal(1,"out-of-range read accepted");rd_en=0;
                    repeat(3)@(negedge rd_clk);if(rd_valid)$fatal(1,"invalid read produced valid data");
                end
                // ACK while the RAM pipeline is occupied must be rejected.
                @(negedge rd_clk);rd_addr=0;rd_en=1;
                @(negedge rd_clk);rd_en=0;ack=1;
                @(negedge rd_clk);if(!ack_bad || !block_ready)$fatal(1,"ACK lost in-flight read");ack=0;
                repeat(3)@(negedge rd_clk);
                ack_block(test_stalls && b==0 && !block_last);b++;
            end
            if(read_count!=(n+7)/8 || reply_count!=read_count || read_error)$fatal(1,"read stream totals mismatch");
            @(negedge ui_clk);next_block=1;
            @(negedge ui_clk);if(!rejected)$fatal(1,"read beyond end accepted");next_block=0;
            $display("PASS record roundtrip: %0d pairs, %0d blocks of <=8 KiB, %0d DDR bursts",n,b,read_count);
            release_it();
        end
    endtask
    task automatic coordinated_reset;
        begin
            @(negedge ui_clk);rst=1;ui_rst=1;calib=0;start=0;release_record=0;next_block=0;ack=0;rd_en=0;
            stall_cmd=0;stall_response=0;bad_end_once=0;
            repeat(40)@(negedge ui_clk);rst=0;ui_rst=0;calib=1;wait_idle_ready();
        end
    endtask
    initial begin
        #1000;coordinated_reset();
        @(negedge ui_clk);next_block=1;
        @(negedge ui_clk);if(!rejected)$fatal(1,"read accepted before a valid record");next_block=0;
        complete_record(1,0);complete_record(7,0);complete_record(8,0);complete_record(9,0);
        complete_record(2048,0);complete_record(2053,1);complete_record(16403,0);complete_record(3,0);
        // Reset with read responses pending, then ensure no stale block is exposed.
        launch(2053);stall_response=1;request_block();repeat(30)@(negedge ui_clk);
        coordinated_reset();if(block_ready || rd_valid)$fatal(1,"stale buffer after reset");complete_record(17,0);
        // Malformed burst end is a sticky protocol fault until coordinated reset.
        launch(9);bad_end_once=1;request_block();wait(read_error);repeat(20)@(negedge ui_clk);
        if(block_ready || read_idle)$fatal(1,"malformed read accepted");coordinated_reset();
        // Unsolicited response is also detected, never written into an owned buffer.
        @(posedge ui_clk);inject_unsolicited=1;wait(read_error);coordinated_reset();complete_record(33,0);
        $display("PASS tb_record_store: ALL TESTS (actual FIFO/XPM RAM, full ADC-DDR-RAM roundtrip, CDC, tail, ACK ownership, stalls, invalid commands, reset, read faults)");
        $finish;
    end
    initial begin #15000000;$fatal(1,"global timeout");end
endmodule
