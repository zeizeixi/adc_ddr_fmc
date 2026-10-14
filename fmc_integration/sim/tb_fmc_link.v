`timescale 1ns/1ps
`default_nettype none
module tb_fmc_link;
    reg clk=0;
    always #5 clk=~clk;
    reg sdclk=0;
    integer half_period=110;
    initial begin #3; forever begin #(half_period) sdclk=~sdclk; end end
    reg rst=1, enabled=1;
    reg cke=1, cs_n=1;
    reg [2:0] command=3'b111;
    reg [12:0] addr=0;
    reg [1:0] bank=0, mask=0;
    reg master_drive=0;
    reg [15:0] master_data=0;
    wire [15:0] dq;
    assign dq=master_drive?master_data:16'bz;
    wire bus_read,bus_write,reply_valid,mode_valid,protocol_error,clear_error;
    wire [23:0] bus_addr;
    wire [15:0] bus_wdata,reply_data;
    wire [1:0] bus_mask;
    wire [31:0] cfg_samples;
    wire cmd_start,cmd_release,cmd_read_next,cmd_ack,rd_en;
    wire [11:0] rd_addr;
    reg [15:0] rd_data=0, ram_first=0;
    reg [1:0] rd_pipe=0;
    reg ram_enable=1;
    wire rd_valid=rd_pipe[1] && ram_enable;
    reg ready=1,busy=0,done=1,valid=1,overflow=0,cfg_done=1,calib=1;
    reg read_ready=1,read_idle=1,stream_done=0,read_error=0,block_ready=1,block_last=0;
    reg accepted=0,rejected=0,read_accepted=0,ack_accepted=0,ack_rejected=0,rd_rejected=0;
    reg [31:0] record_samples=10,record_bytes=40,blocks=2,block_index=0,block_offset=0;
    reg [13:0] block_bytes=40;
    integer starts=0,reads=0,acks=0,releases=0,errors=0,checks=0;
    integer idx;
    integer send_idx;
    integer row_test;
    reg [15:0] got;

    fmc_sdram_port u_port (
        .clk(clk),.rst(rst),.enabled(enabled),.clear_error(clear_error),
        .sdclk(sdclk),.cke(cke),.cs_n(cs_n),.ras_n(command[2]),.cas_n(command[1]),.we_n(command[0]),
        .addr(addr),.bank(bank),.dqm(mask),.dq(dq),
        .bus_read(bus_read),.bus_write(bus_write),.bus_addr(bus_addr),.bus_wdata(bus_wdata),.bus_mask(bus_mask),
        .reply_valid(reply_valid),.reply_data(reply_data),.mode_valid(mode_valid),.protocol_error(protocol_error)
    );
    fmc_record_regs u_regs (
        .clk(clk),.rst(rst),.bus_read(bus_read),.bus_write(bus_write),.bus_addr(bus_addr),.bus_wdata(bus_wdata),.bus_mask(bus_mask),
        .reply_valid(reply_valid),.reply_data(reply_data),.mode_valid(mode_valid),.protocol_error(protocol_error),.clear_error(clear_error),
        .cfg_samples(cfg_samples),.cmd_start(cmd_start),.cmd_release(cmd_release),.cmd_read_next(cmd_read_next),.cmd_ack(cmd_ack),
        .rd_en(rd_en),.rd_addr(rd_addr),.rd_data(rd_data),.rd_valid(rd_valid),
        .ready(ready),.busy(busy),.done(done),.valid(valid),.overflow(overflow),.cfg_done(cfg_done),.calib(calib),
        .read_ready(read_ready),.read_idle(read_idle),.stream_done(stream_done),.read_error(read_error),.block_ready(block_ready),.block_last(block_last),
        .accepted(accepted),.rejected(rejected),.read_accepted(read_accepted),.ack_accepted(ack_accepted),.ack_rejected(ack_rejected),.rd_rejected(rd_rejected),
        .record_samples(record_samples),.record_bytes(record_bytes),.blocks(blocks),.block_index(block_index),.block_offset(block_offset),.block_bytes(block_bytes)
    );

    // Two-cycle consumer-memory model, matching the existing reader contract.
    always @(posedge clk) begin
        if(rst) rd_pipe<=0;
        else begin
            rd_pipe<={rd_pipe[0],rd_en};
            if(rd_en) ram_first <= 16'ha500 ^ {4'b0,rd_addr};
            rd_data <= ram_first;
            if(cmd_start) starts=starts+1;
            if(cmd_read_next) reads=reads+1;
            if(cmd_ack) acks=acks+1;
            if(cmd_release) releases=releases+1;
        end
    end

    task cycle;
        input [2:0] op;
        input [1:0] ba;
        input [12:0] address;
        input drive;
        input [15:0] data;
        input [1:0] masks;
        begin
            @(negedge sdclk);
            cs_n=0;command=op;bank=ba;addr=address;
            master_drive=drive;master_data=data;mask=masks;
            @(posedge sdclk); #7;
            // Remove the command soon after the edge: the receiver must use
            // its pre-edge history, not a late sample of the next command.
            cs_n=1; command=3'b111; addr=0; bank=0; mask=0; master_drive=0;
        end
    endtask
    task idle_cycles;
        input integer count;
        integer i;
        begin for(i=0;i<count;i=i+1) cycle(3'b111,0,0,0,0,0); end
    endtask
    task write_reg;
        input [7:0] column;
        input [15:0] data;
        input [1:0] masks;
        begin cycle(3'b100,0,{5'b0,column},1,data,masks);idle_cycles(2);end
    endtask
    task check_read;
        input [1:0] ba;
        input [7:0] column;
        input [15:0] expected;
        begin
            cycle(3'b101,ba,{5'b0,column},0,0,0);
            idle_cycles(3);
            // Sample after CAS3 + two HCLK periods (SDCLK=HCLK/3).
            #(half_period*4/3-1);
            checks=checks+1;
            if(dq!==expected) begin
                $display("FAIL column=%h expected=%h got=%h time=%t",column,expected,dq,$time);
                errors=errors+1;
            end
            idle_cycles(2);
        end
    endtask

    initial begin
        #81;rst=0;
        idle_cycles(3);
        cycle(3'b010,0,13'h400,0,0,0); // all-bank precharge
        cycle(3'b001,0,0,0,0,0); // refresh
        cycle(3'b000,0,13'h230,0,0,0); // expected mode
        idle_cycles(2);
        if(!mode_valid || protocol_error) $fatal(1,"Initialization failed");
        cycle(3'b011,0,0,0,0,0); // row zero
        check_read(0,0,16'hadfc);
        check_read(0,1,16'h0100);
        check_read(0,8,16'd10);
        check_read(0,10,16'd40);
        write_reg(8'h13,16'h55aa,0);
        check_read(0,8'h13,16'h55aa);
        write_reg(8'h13,16'h003c,2'b10);
        check_read(0,8'h13,16'h553c);
        write_reg(8'h13,16'hc300,2'b01);
        check_read(0,8'h13,16'hc33c);
        write_reg(8'h13,16'hffff,2'b11);
        check_read(0,8'h13,16'hc33c);
        write_reg(4,16'd200,0);
        if(cfg_samples!=20000000) $fatal(1,"Duration conversion");
        write_reg(4,16'd0,0);
        check_read(0,4,16'd200);
        write_reg(5,16'd5,0); // clear invalid-duration diagnostic
        write_reg(5,16'd1,0);
        if(starts!=1) $fatal(1,"START missing or duplicated");
        ready=0;
        write_reg(5,16'd1,0);
        if(starts!=1) $fatal(1,"Rejected START executed");
        ready=1;
        write_reg(5,16'd2,0);
        if(reads!=1) $fatal(1,"READ_NEXT failed");
        write_reg(5,16'd3,0);
        if(acks!=1) $fatal(1,"ACK failed");
        write_reg(5,16'd4,0);
        if(releases!=1) $fatal(1,"RELEASE failed");
        write_reg(5,16'd1,2'b10);
        if(starts!=1) $fatal(1,"Partial command executed");

        cycle(3'b011,0,13'd16,0,0,0);
        check_read(0,0,16'ha500);
        check_read(0,19,16'ha513);
        check_read(0,20,16'hdead); // beyond short block
        if(acks!=1) $fatal(1,"Read must never implicitly ACK");
        block_bytes=8192;
        // Fully pipelined consecutive BL1 reads, including the first four replies.
        fork
            begin
                for(send_idx=0;send_idx<12;send_idx=send_idx+1) begin
                    if(send_idx<8) cycle(3'b101,0,send_idx,0,0,0);
                    else cycle(3'b111,0,0,0,0,0);
                end
            end
            begin
                @(negedge sdclk);
                for(idx=0;idx<12;idx=idx+1) begin
                    @(posedge sdclk);
                    #(half_period*4/3);
                    if(idx>=3 && idx<11) begin
                        checks=checks+1;
                        if(dq !== (16'ha500 ^ (idx-3))) begin
                            errors=errors+1;$display("FAIL pipelined read idx=%d dq=%h",idx,dq);
                        end
                    end
                end
            end
        join
        idle_cycles(3);
        cycle(3'b011,0,13'd17,0,0,0);
        check_read(0,0,16'ha400); // row changes the word address by 256
        cycle(3'b011,0,13'd31,0,0,0);
        check_read(0,255,16'haaff);
        // Delayed read DQM: C1 mask controls the response driven after C3.
        cycle(3'b011,0,0,0,0,0);
        cycle(3'b101,0,0,0,0,0);
        cycle(3'b111,0,0,0,0,2'b10);
        idle_cycles(2);
        #(half_period*4/3-1);
        if(dq !== {8'hzz,8'hfc}) $fatal(1,"Read DQM latency/byte lanes incorrect");
        idle_cycles(3);
        // Last word of a row followed by the first word of the next row.
        cycle(3'b011,0,13'd16,0,0,0);
        check_read(0,255,16'ha5ff);
        cycle(3'b011,0,13'd17,0,0,0);
        check_read(0,0,16'ha400);
        cycle(3'b011,1,0,0,0,0);
        check_read(1,0,16'hffff); // bank cannot alias ID register

        cycle(3'b011,0,13'd16,0,0,0);
        ram_enable=0;
        check_read(0,0,16'hdead);
        ram_enable=1;
        cycle(3'b010,0,13'h400,0,0,0);
        check_read(0,0,16'hdead); // closed row
        cycle(3'b000,0,13'h220,0,0,0);
        idle_cycles(2);
        if(mode_valid) $fatal(1,"Unsupported CAS mode accepted");
        rst=1;#1;
        if(dq!==16'hzzzz) $fatal(1,"Reset must release DQ");
        #50;rst=0;
        idle_cycles(3);
        cycle(3'b000,0,13'h230,0,0,0);
        cycle(3'b011,0,0,0,0,0);
        // Phase/frequency changes remain below the documented maximum.
        half_period=137;
        check_read(0,0,16'hadfc);
        half_period=100;
        check_read(0,0,16'hadfc);
        half_period=500;
        check_read(0,0,16'hadfc);
        half_period=103;
        // Exhaustive 8 KiB window: every halfword, all sixteen SDRAM rows.
        for(row_test=0;row_test<16;row_test=row_test+1) begin
            cycle(3'b011,0,16+row_test,0,0,0);
            fork
                begin
                    for(send_idx=0;send_idx<260;send_idx=send_idx+1) begin
                        if(send_idx<256) cycle(3'b101,0,send_idx,0,0,0);
                        else cycle(3'b111,0,0,0,0,0);
                    end
                end
                begin
                    @(negedge sdclk);
                    for(idx=0;idx<260;idx=idx+1) begin
                        @(posedge sdclk);
                        #(half_period*4/3);
                        if(idx>=3 && idx<259) begin
                            checks=checks+1;
                            if(dq !== (16'ha500 ^ (row_test*256+idx-3))) begin
                                errors=errors+1;
                                $display("FAIL full-window row=%d col=%d dq=%h",row_test,idx-3,dq);
                            end
                        end
                    end
                end
            join
        end
        if(acks!=1) $fatal(1,"Full-window read implicitly released block");
        enabled=0;#20;
        if(dq!==16'hzzzz) $fatal(1,"VIO ownership must disable FMC drive");
        if(errors) $fatal(1,"FAIL %0d / %0d checks",errors,checks);
        $display("PASS: %0d read checks, command/mask/row/bank/timeout/reset/ownership checks",checks);
        $finish;
    end
    initial begin #2000000; $fatal(1,"Testbench watchdog"); end
endmodule
`default_nettype wire
