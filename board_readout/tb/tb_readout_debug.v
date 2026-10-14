`timescale 1ns/1ps
module tb_readout_debug;
    reg clk=0,rst=1,read_word=0,clear_debug=0;
    always #5 clk=~clk;
    reg read_ready=0,read_idle=0,block_ready=0,block_last=0,stream_done=0,read_error=0;
    reg rd_valid=0,read_accepted=0,ack_accepted=0,command_rejected=0;
    reg ack_rejected=0,rd_rejected=0,start_accepted=0;
    reg [15:0] rd_data=0;
    wire rd_en;wire [15:0] status,last_data;
    wire [31:0] word_count,ack_count,request_count;
    integer reads=0;
    readout_debug dut(.clk(clk),.rst(rst),.read_word(read_word),.clear_debug(clear_debug),.rd_en(rd_en),
        .read_ready(read_ready),.read_idle(read_idle),.block_ready(block_ready),.block_last(block_last),
        .stream_done(stream_done),.read_error(read_error),.rd_valid(rd_valid),.rd_data(rd_data),
        .read_accepted(read_accepted),.ack_accepted(ack_accepted),.command_rejected(command_rejected),
        .ack_rejected(ack_rejected),.rd_rejected(rd_rejected),.start_accepted(start_accepted),
        .status(status),.last_data(last_data),.word_count(word_count),.ack_count(ack_count),.request_count(request_count));
    always @(posedge clk) if(rd_en) reads=reads+1;
    initial begin
        repeat(3) @(negedge clk);rst=0;read_word=1;
        repeat(7) @(negedge clk);
        if(reads!=1) $fatal(1,"Held read command generated repeated pulses");
        read_word=0;@(negedge clk);read_word=1;@(negedge clk);
        if(reads!=2) $fatal(1,"Second read edge lost");
        read_word=0;rd_valid=1;rd_data=16'h1234;read_accepted=1;ack_accepted=1;
        command_rejected=1;ack_rejected=1;rd_rejected=1;start_accepted=1;
        read_ready=1;read_idle=1;block_ready=1;block_last=1;stream_done=1;read_error=1;
        @(negedge clk);
        rd_valid=0;rd_data=16'hffff;read_accepted=0;ack_accepted=0;
        command_rejected=0;ack_rejected=0;rd_rejected=0;start_accepted=0;
        repeat(4) @(negedge clk);
        if(status!==16'h1fff || last_data!==16'h1234 || word_count!=1 || ack_count!=1 || request_count!=1)
            $fatal(1,"VIO event/data retention or status map incorrect");
        clear_debug=1;rd_valid=1;rd_data=16'h5678;
        @(negedge clk);rd_valid=0;
        repeat(3) @(negedge clk);
        if(status!==16'h007f || last_data!==16'h5678 || word_count!=1 || ack_count!=0 || request_count!=0)
            $fatal(1,"Clear lost simultaneous event, or held clear kept clearing");
        clear_debug=0;@(negedge clk);clear_debug=1;@(negedge clk);
        if(status!==16'h003f || last_data!=0 || word_count!=0) $fatal(1,"Explicit clear failed");
        rst=1;read_word=1;@(negedge clk);
        if(rd_en || status[12:6]!=0 || word_count!=0) $fatal(1,"Reset did not clear debug state");
        $display("PASS tb_readout_debug: command edges, sticky events, data hold, counters, clear collision, reset");
        $finish;
    end
    initial begin #10000;$fatal(1,"Timeout");end
endmodule
