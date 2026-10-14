`timescale 1ns/1ps
module tb_capture;
    localparam N=16403;
    localparam W=(N+7)/8;
    reg sys_clk=0, adc_clk=0, ui_clk=0;
    always #5 sys_clk=~sys_clk;
    initial begin #1.7; forever #5 adc_clk=~adc_clk; end
    initial begin #2.3; forever #4 ui_clk=~ui_clk; end // unrelated 125 MHz UI
    reg rst=1, start=0, calib=0;
    reg [11:0] adc_ramp=0;
    wire [11:0] adc_b=adc_ramp^12'ha53;
    always @(negedge adc_clk) adc_ramp <= adc_ramp+1;
    wire adc_reset, cs_n, sck, sdi;
    wire [2:0] ctrl;
    wire ready, cfg_done, cap_done, cap_busy, overflow, submitted;
    wire [28:0] addr;
    wire [2:0] cmd;
    wire en, wren, wend;
    wire [255:0] data;
    wire [31:0] mask;
    reg app_rdy=0, wdf_rdy=0;
    ads62p24_to_mig256 #(.CAPTURE_SAMPLES(N),.BASE_APP_ADDR(29'h100),
        .CFG_POWER_WAIT(20),.CFG_RESET_HIGH(20),.CFG_RESET_WAIT(20),.CFG_SETTLE(100)) dut (
        .i_sys_clk_100m(sys_clk),.i_sys_rst(rst),.i_adc_clk_out(adc_clk),
        .i_adc_da(adc_ramp),.i_adc_db(adc_b),.o_adc_reset(adc_reset),
        .o_adc_cs_n(cs_n),.o_adc_sck(sck),.o_adc_sdi(sdi),.o_adc_ctrl(ctrl),
        .i_ui_clk(ui_clk),.i_ui_rst(rst),.i_mig_calib_done(calib),.i_start_sys(start),
        .o_ready_sys(ready),.o_cfg_done_sys(cfg_done),.o_capture_done_sys(cap_done),
        .o_capture_busy_sys(cap_busy),.o_overflow_sys(overflow),.o_mig_submitted_sys(submitted),
        .app_addr(addr),.app_cmd(cmd),.app_en(en),.app_rdy(app_rdy),
        .app_wdf_data(data),.app_wdf_mask(mask),.app_wdf_wren(wren),
        .app_wdf_end(wend),.app_wdf_rdy(wdf_rdy)
    );
    reg [255:0] expected [0:W-1];
    integer captured=0, data_count=0, command_count=0, ticks=0;
    reg [11:0] previous_a=0, previous_b=0;
    reg [31:0] lfsr=32'h193d27a5;
    // Reference is taken from physical ADC inputs with the documented one-IOB latency.
    // No use of the packer's concatenation/counter implementation in the scoreboard.
    always @(posedge adc_clk) begin
        if (rst) begin
            captured=0;
            for (integer k=0;k<W;k=k+1) expected[k]=0;
        end else if (dut.u_front.cap_busy && captured<N) begin
            expected[captured/8][32*(captured%8)+:16]={4'b0,previous_a};
            expected[captured/8][32*(captured%8)+16+:16]={4'b0,previous_b};
            captured=captured+1;
        end
        previous_a=adc_ramp; previous_b=adc_b;
    end
    // Deliberately independent command/data stalls plus an 8 us initial pause.
    always @(negedge ui_clk) begin
        if (rst || !cap_busy && captured==0) begin
            ticks=0; app_rdy=0; wdf_rdy=0; lfsr=32'h193d27a5;
        end else begin
            ticks=ticks+1;
            lfsr={lfsr[30:0],lfsr[31]^lfsr[21]^lfsr[1]^lfsr[0]};
            app_rdy=(ticks>1000) && lfsr[0];
            wdf_rdy=(ticks>1000) && lfsr[3];
        end
    end
    reg held_wren=0, held_en=0;
    reg [255:0] held_data;
    reg [28:0] held_addr;
    always @(posedge ui_clk) begin
        if (rst) begin
            data_count=0; command_count=0; held_wren=0; held_en=0;
        end else begin
            if (held_wren && (!wren || data!==held_data || !wend))
                $fatal(1,"Write payload changed while MIG stalled");
            if (held_en && (!en || addr!==held_addr || cmd!==0))
                $fatal(1,"Command changed while MIG stalled");
            if (wren && wdf_rdy) begin
                if (data_count>=W || data!==expected[data_count])
                    $fatal(1,"Data mismatch at block %0d: got %h expected %h",data_count,data,expected[data_count]);
                if (!wend || mask!==0) $fatal(1,"Invalid write mask/end");
                data_count=data_count+1;
            end
            if (en && app_rdy) begin
                if (cmd!==0 || addr!==29'h100+command_count*8)
                    $fatal(1,"Command/address mismatch at %0d",command_count);
                command_count=command_count+1;
                if (command_count>data_count) $fatal(1,"Command accepted before its data");
            end
            held_wren=wren&&!wdf_rdy; held_data=data;
            held_en=en&&!app_rdy; held_addr=addr;
        end
    end
    integer serial_bits=0, serial_packets=0;
    reg [15:0] serial_word=0;
    realtime last_rising, last_falling;
    always @(posedge rst) begin serial_bits=0; serial_packets=0; serial_word=0; end
    always @(posedge sck) last_rising=$realtime;
    always @(negedge sck) if (!rst && !cs_n) begin
        if ($realtime-last_rising<25) $fatal(1,"SPI setup interval too short");
        serial_word={serial_word[14:0],sdi}; serial_bits=serial_bits+1;
        last_falling=$realtime;
    end
    always @(posedge cs_n) if (!rst && serial_bits!=0) begin
        if (serial_bits!=16 || $realtime-last_falling<25) $fatal(1,"SPI length/hold error");
        if (serial_word !== (serial_packets==0 ? 16'h1480 : 16'h1610))
            $fatal(1,"Wrong ADC config word %h",serial_word);
        serial_bits=0; serial_packets=serial_packets+1;
    end
    task begin_capture;
        begin
            wait(ready); @(negedge sys_clk); start=1;
            @(negedge sys_clk); start=0;
        end
    endtask
    initial begin
        #200; rst=0; #1000; calib=1;
        begin_capture();
        repeat(300) @(posedge adc_clk); // Interrupt an acquisition, reset the whole path.
        @(negedge sys_clk); rst=1; calib=0;
        #200; rst=0; #1000; calib=1;
        begin_capture();
        wait(submitted); #100;
        if (!cap_done || overflow || captured!=N || data_count!=W || command_count!=W || serial_packets!=2)
            $fatal(1,"Final counts/status failed");
        if (ready || cap_busy) $fatal(1,"One-shot status failed");
        // A second trigger must not silently overwrite the completed record.
        @(negedge sys_clk); start=1; @(negedge sys_clk); start=0;
        repeat(100) @(posedge ui_clk);
        if (command_count!=W) $fatal(1,"Unexpected automatic re-arm");
        $display("PASS tb_capture: %0d pairs, %0d blocks, tail padding, SPI, CDC, stalls, reset and one-shot",N,W);
        $finish;
    end
    initial begin #2000000; $fatal(1,"tb_capture timeout"); end
endmodule
