`timescale 1ns/1ps
module tb_trigger_geometry;
    reg clk=0,rst=1,start=0;
    always #5 clk=~clk;
    reg [31:0] samples=0;
    reg [6:0] percent=0;
    wire busy,done;
    wire [31:0] pre_samples,ring_samples;
    trigger_geometry dut(.*);
    integer n,p,k;
    task check(input integer points,input integer pct);
        begin
            @(negedge clk);samples=points;percent=pct;start=1;
            @(negedge clk);start=0;
            k=0;
            while(!done) begin @(negedge clk); k=k+1;if(k>34)$fatal(1,"Timeout");end
            if(pre_samples!=(64'(points)*pct)/100 || ring_samples!=((points+7)/8+1)*8)
                $fatal(1,"Geometry N=%d pct=%d pre=%d ring=%d",points,pct,pre_samples,ring_samples);
        end
    endtask
    initial begin
        #30;rst=0;
        for(n=1;n<=33;n=n+1) for(p=0;p<=100;p=p+1) check(n,p);
        for(p=0;p<=100;p=p+1) begin check(20000000,p);check(19999999,p);end
        $display("ALL 3535 GEOMETRY TESTS PASSED");$finish;
    end
endmodule
