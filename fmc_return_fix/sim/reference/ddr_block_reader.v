`timescale 1ns/1ps
`default_nettype none
// Sequential, explicitly requested 8 KiB blocks. Entire block capacity is
// reserved before issuing reads; MIG read data has no backpressure.
// Record metadata stays stable until record release. Both clocks reset together.
module ddr_block_reader #(
    parameter APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0
)(
    input wire ui_clk,rst,init_calib_complete,stream_clear,
    input wire record_done,record_valid,input wire [31:0] record_bytes,
    input wire cmd_read_next,
    output wire idle,read_ready,
    output reg read_accepted,command_rejected,stream_done,protocol_error,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire app_en,input wire app_rdy,
    input wire [255:0] app_rd_data,input wire app_rd_data_valid,app_rd_data_end,
    input wire rd_clk,rd_rst,rd_en,input wire [11:0] rd_addr,
    output wire [15:0] rd_data,output wire rd_valid,
    output reg block_ready,
    output reg [31:0] block_index,block_offset,
    output reg [13:0] block_bytes,output reg block_last,
    input wire cmd_block_ack,
    output reg ack_accepted,ack_rejected,rd_rejected
);
    localparam IDLE=0,FILL=1,PUBLISH=2,WAIT_ACK=3,FAULT=4;
    reg [2:0] state;
    reg [31:0] next_offset,index_q;
    reg [13:0] bytes_q;
    reg last_q;
    reg [8:0] goal,issued,received;
    reg [APP_ADDR_WIDTH-1:0] addr_q;
    reg cmd_d,desc_send;
    wire desc_busy,desc_valid;
    wire [78:0] desc_src={index_q,next_offset,bytes_q,last_q};
    wire [78:0] desc_dst;
    cdc_mailbox #(.WIDTH(79)) u_block_mail(
        .src_clk(ui_clk),.src_rst(rst),.src_send(desc_send),.src_data(desc_src),.src_busy(desc_busy),
        .dst_clk(rd_clk),.dst_rst(rd_rst),.dst_valid(desc_valid),.dst_data(desc_dst));
    reg ack_send;
    reg [31:0] ack_index;
    wire ack_busy,ack_valid;
    wire [31:0] ack_dst;
    cdc_mailbox #(.WIDTH(32)) u_ack_mail(
        .src_clk(rd_clk),.src_rst(rd_rst),.src_send(ack_send),.src_data(ack_index),.src_busy(ack_busy),
        .dst_clk(ui_clk),.dst_rst(rst),.dst_valid(ack_valid),.dst_data(ack_dst));
    wire ack_busy_ui,block_ready_ui,consumer_fault_ui;
    reg consumer_fault;
    level_sync u_ack_busy(.clk(ui_clk),.rst(rst),.async_in(ack_busy),.sync_out(ack_busy_ui));
    level_sync u_block_ready(.clk(ui_clk),.rst(rst),.async_in(block_ready),.sync_out(block_ready_ui));
    level_sync u_consumer_fault(.clk(ui_clk),.rst(rst),.async_in(consumer_fault),.sync_out(consumer_fault_ui));
    assign idle=state==IDLE && !desc_busy && !ack_busy_ui && !block_ready_ui && !protocol_error && !rst;
    assign read_ready=idle && !stream_clear && init_calib_complete && record_done && record_valid &&
        record_bytes>0 && record_bytes<=80000000 && record_bytes[1:0]==0 && next_offset<record_bytes && !stream_done;
    assign app_addr=addr_q;
    assign app_en=state==FILL && issued<goal && init_calib_complete && !protocol_error && !rst;
    wire issue=app_en && app_rdy;
    wire response_expected=state==FILL && received<goal && (received<issued || issue);
    wire store=app_rd_data_valid && app_rd_data_end && response_expected && !protocol_error && !rst;
    wire [31:0] remaining=record_bytes-next_offset;
    wire [31:0] requested_bytes=(remaining>8192)?32'd8192:remaining;
    reg ack_d;
    reg [1:0] read_pipe;
    wire ack_edge=cmd_block_ack && !ack_d;
    wire read_fire=rd_en && block_ready && !ack_edge && !ack_send && !ack_busy &&
        ({1'b0,rd_addr} < (block_bytes>>1)) && !rd_rst;
    assign rd_valid=read_pipe[1];
    ram256x16_8k u_buffer(.wr_clk(ui_clk),.wr_en(store),.wr_addr(received[7:0]),.wr_data(app_rd_data),
        .rd_clk(rd_clk),.rd_rst(rd_rst),.rd_en(read_fire),.rd_addr(rd_addr),.rd_data(rd_data));
    always @(posedge rd_clk) begin
        if(rd_rst) begin
            block_ready<=0;block_index<=0;block_offset<=0;block_bytes<=0;block_last<=0;
            ack_d<=0;ack_send<=0;ack_index<=0;ack_accepted<=0;ack_rejected<=0;
            rd_rejected<=0;read_pipe<=0;consumer_fault<=0;
        end else begin
            ack_d<=cmd_block_ack;ack_send<=0;ack_accepted<=0;ack_rejected<=0;
            rd_rejected<=rd_en && !read_fire;
            read_pipe<={read_pipe[0],read_fire};
            if(desc_valid) begin
                if(block_ready || |read_pipe) consumer_fault<=1;
                else begin
                    block_index<=desc_dst[78:47];block_offset<=desc_dst[46:15];
                    block_bytes<=desc_dst[14:1];block_last<=desc_dst[0];block_ready<=1;
                end
            end
            // ACK is explicit. Reading the last address never releases a block.
            // Refuse ACK while a two-cycle RAM response is still in flight.
            if(ack_edge) begin
                if(block_ready && !rd_en && read_pipe==0 && !ack_busy && !ack_send) begin
                    ack_index<=block_index;ack_send<=1;block_ready<=0;ack_accepted<=1;
                end else ack_rejected<=1;
            end
        end
    end
    always @(posedge ui_clk) begin
        if(rst) begin
            state<=IDLE;next_offset<=0;index_q<=0;bytes_q<=0;last_q<=0;
            goal<=0;issued<=0;received<=0;addr_q<=BASE_APP_ADDR;cmd_d<=0;
            desc_send<=0;read_accepted<=0;command_rejected<=0;stream_done<=0;protocol_error<=0;
        end else begin
            cmd_d<=cmd_read_next;desc_send<=0;read_accepted<=0;command_rejected<=0;
            if(cmd_read_next && !cmd_d) command_rejected<=1;
            if(stream_clear && idle) begin
                next_offset<=0;index_q<=0;stream_done<=0;
            end
            case(state)
                IDLE: if(cmd_read_next && !cmd_d && read_ready) begin
                    bytes_q<=requested_bytes[13:0];last_q<=remaining<=8192;
                    goal<=(requested_bytes+31)>>5;issued<=0;received<=0;
                    addr_q<=BASE_APP_ADDR+(next_offset>>2);state<=FILL;
                    read_accepted<=1;command_rejected<=0;
                end
                FILL: begin
                    if(issue) begin issued<=issued+1'b1;addr_q<=addr_q+8;end
                    if(store) begin
                        received<=received+1'b1;
                        if(received==goal-1) state<=PUBLISH;
                    end
                end
                PUBLISH: if(!desc_busy) begin desc_send<=1;state<=WAIT_ACK;end
                WAIT_ACK: if(ack_valid) begin
                    if(ack_dst==index_q) begin
                        next_offset<=next_offset+bytes_q;index_q<=index_q+1;
                        stream_done<=last_q;state<=IDLE;
                    end else begin protocol_error<=1;state<=FAULT;end
                end
                FAULT: begin end
                default: begin protocol_error<=1;state<=FAULT;end
            endcase
            if((app_rd_data_valid && (!response_expected || !app_rd_data_end)) || consumer_fault_ui ||
                (stream_clear && !idle)) begin
                protocol_error<=1;state<=FAULT;
            end
        end
    end
endmodule
`default_nettype wire
