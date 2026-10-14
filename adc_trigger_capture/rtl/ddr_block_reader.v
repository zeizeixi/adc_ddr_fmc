`timescale 1ns/1ps
`default_nettype none
// 从环形 DDR 起点重新对齐样本，每次发布最多 8192 字节；显式 ACK 后才复用缓存。
// 接口协议与边界条件见同目录 ddr_block_reader_spec.md。
module ddr_block_reader #(
    parameter APP_ADDR_WIDTH=28,
    parameter [APP_ADDR_WIDTH-1:0] BASE_APP_ADDR=0
)(
    input wire ui_clk,
    input wire rst,
    input wire init_calib_complete,
    input wire stream_clear,
    input wire record_done, // 本条采集收尾完成，所有待写数据和命令已被 MIG 接受。
    input wire record_valid, // 本条记录有效；溢出或取消时不能读为有效记录。
    input wire [31:0] record_bytes, // 有效记录字节数；每对 A/B 占 4 字节。
    input wire [31:0] record_start_sample, // 有效记录第一对样本的物理环形索引。
    input wire [31:0] record_ring_samples, // 物理环形容量，8 对对齐并额外保留 8 对。
    input wire cmd_read_next,
    output wire idle,
    output wire read_ready, // 可请求下一块；没有当前块占用且还有剩余记录。
    output reg read_accepted,
    output reg command_rejected,
    output reg stream_done, // 最后一块 ACK 已返回 UI 域。
    output reg protocol_error,
    output wire [APP_ADDR_WIDTH-1:0] app_addr,
    output wire app_en,
    input wire app_rdy,
    input wire [255:0] app_rd_data,
    input wire app_rd_data_valid,
    input wire app_rd_data_end,
    input wire rd_clk,
    input wire rd_rst,
    input wire rd_en,
    input wire [11:0] rd_addr, // 8 KiB 缓存的 16 位字地址，0～4095。
    output wire [15:0] rd_data,
    output wire rd_valid, // 本拍 rd_data 为有效返回；缓存读延迟为两拍。
    output reg block_ready,
    output reg [31:0] block_index, // 当前读块序号，从 0 开始。
    output reg [31:0] block_offset, // 当前块在逻辑记录中的字节偏移。
    output reg [13:0] block_bytes, // 当前读块有效字节数，最大 8192。
    output reg block_last, // 仅 BLOCK_READY 时解释为当前块是否末块。
    input wire cmd_block_ack,
    output reg ack_accepted,
    output reg ack_rejected,
    output reg rd_rejected
);
    localparam IDLE=0,FILL=1,PUBLISH=2,WAIT_ACK=3,FAULT=4;
    reg [2:0] state;
    reg [31:0] next_offset,index_q;
    reg [13:0] bytes_q;
    reg last_q;

    reg [255:0] burst_data;
    reg burst_loaded;
    reg read_pending;
    reg [2:0] source_lane;
    reg [2:0] output_lane;
    reg [255:0] output_pack;
    reg [255:0] assembled_pack;
    reg [11:0] copied_pairs;
    reg [11:0] goal_pairs;
    reg [7:0] write_index;
    wire [31:0] logical_start=record_start_sample+(next_offset>>2);
    wire [31:0] physical_start=logical_start>=record_ring_samples ?
                                  logical_start-record_ring_samples : logical_start;
    reg [APP_ADDR_WIDTH-1:0] addr_q;
    reg cmd_d,desc_send;
    wire desc_busy,desc_valid;
    wire [78:0] desc_src={index_q,next_offset,bytes_q,last_q};
    wire [78:0] desc_dst;
    cdc_mailbox #(.WIDTH(79)) u_block_mail(
        .src_clk(ui_clk),
        .src_rst(rst),
        .src_send(desc_send),
        .src_data(desc_src),
        .src_busy(desc_busy),
        .dst_clk(rd_clk),
        .dst_rst(rd_rst),
        .dst_valid(desc_valid),
        .dst_data(desc_dst));
    reg ack_send;
    reg [31:0] ack_index;
    wire ack_busy,ack_valid;
    wire [31:0] ack_dst;
    cdc_mailbox #(.WIDTH(32)) u_ack_mail(
        .src_clk(rd_clk),
        .src_rst(rd_rst),
        .src_send(ack_send),
        .src_data(ack_index),
        .src_busy(ack_busy),
        .dst_clk(ui_clk),
        .dst_rst(rst),
        .dst_valid(ack_valid),
        .dst_data(ack_dst));
    wire ack_busy_ui,block_ready_ui,consumer_fault_ui;
    reg consumer_fault;
    level_sync u_ack_busy(.clk(ui_clk),
        .rst(rst),
        .async_in(ack_busy),
        .sync_out(ack_busy_ui));
    level_sync u_block_ready(.clk(ui_clk),
        .rst(rst),
        .async_in(block_ready),
        .sync_out(block_ready_ui));
    level_sync u_consumer_fault(.clk(ui_clk),
        .rst(rst),
        .async_in(consumer_fault),
        .sync_out(consumer_fault_ui));
    assign idle=state==IDLE && !desc_busy && !ack_busy_ui && !block_ready_ui && !protocol_error && !rst;
    assign read_ready=idle && !stream_clear && init_calib_complete && record_done && record_valid &&
        record_bytes>0 && record_bytes<=80000000 && record_bytes[1:0]==0 && next_offset<record_bytes && !stream_done;
    assign app_addr=addr_q;
    assign app_en=state==FILL && !burst_loaded && !read_pending &&
        copied_pairs<goal_pairs && init_calib_complete && !protocol_error && !rst;
    wire issue=app_en && app_rdy;
    wire response_expected=state==FILL && !burst_loaded && (read_pending || issue);

    wire copy_pair=state==FILL && burst_loaded && !protocol_error && !rst;
    wire store=copy_pair && (output_lane==7 || copied_pairs==goal_pairs-1);
    always @(*) begin
        assembled_pack=output_pack;
        assembled_pack[output_lane*32 +: 32]=burst_data[source_lane*32 +: 32];
    end
    wire [31:0] remaining=record_bytes-next_offset;
    wire [31:0] requested_bytes=(remaining>8192)?32'd8192:remaining;
    reg ack_d;
    reg [1:0] read_pipe;
    wire ack_edge=cmd_block_ack && !ack_d;
    wire read_fire=rd_en && block_ready && !ack_edge && !ack_send && !ack_busy &&
        ({1'b0,rd_addr} < (block_bytes>>1)) && !rd_rst;
    assign rd_valid=read_pipe[1];
    ram256x16_8k u_buffer(.wr_clk(ui_clk),
        .wr_en(store),
        .wr_addr(write_index),
        .wr_data(assembled_pack),
        .rd_clk(rd_clk),
        .rd_rst(rd_rst),
        .rd_en(read_fire),
        .rd_addr(rd_addr),
        .rd_data(rd_data));
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

    // One outstanding MIG read at a time; consume/repack each 32-bit sample pair.
    // This handles ring wrap and arbitrary trigger alignment inside a 256-bit burst.
    always @(posedge ui_clk) begin
        if (rst) begin
            state<=IDLE; next_offset<=0; index_q<=0; bytes_q<=0; last_q<=0;
            addr_q<=BASE_APP_ADDR; cmd_d<=0; desc_send<=0;
            read_accepted<=0; command_rejected<=0; stream_done<=0; protocol_error<=0;
            burst_data<=0; burst_loaded<=0; read_pending<=0;
            source_lane<=0; output_lane<=0; output_pack<=0;
            copied_pairs<=0; goal_pairs<=0; write_index<=0;
        end else begin
            cmd_d<=cmd_read_next; desc_send<=0; read_accepted<=0; command_rejected<=0;
            if (cmd_read_next && !cmd_d) command_rejected<=1;
            if (stream_clear && idle) begin
                next_offset<=0; index_q<=0; stream_done<=0;
            end
            case (state)
                IDLE: if (cmd_read_next && !cmd_d && read_ready) begin
                    bytes_q<=requested_bytes[13:0]; last_q<=remaining<=8192;
                    goal_pairs<=requested_bytes>>2; copied_pairs<=0;
                    source_lane<=physical_start[2:0]; output_lane<=0;
                    output_pack<=0; write_index<=0;
                    burst_loaded<=0; read_pending<=0;
                    addr_q<=BASE_APP_ADDR+((physical_start>>3)<<3);
                    state<=FILL; read_accepted<=1; command_rejected<=0;
                end
                FILL: begin
                    if (issue) read_pending<=1;
                    if (app_rd_data_valid && app_rd_data_end && response_expected) begin
                        burst_data<=app_rd_data;
                        burst_loaded<=1;
                        read_pending<=0;
                    end
                    if (copy_pair) begin
                        copied_pairs<=copied_pairs+1'b1;
                        if (store) begin
                            write_index<=write_index+1'b1;
                            output_lane<=0;
                            output_pack<=0;
                        end else begin
                            output_lane<=output_lane+1'b1;
                            output_pack<=assembled_pack;
                        end
                        if (source_lane==7) begin
                            source_lane<=0;
                            burst_loaded<=0;
                            if (addr_q==BASE_APP_ADDR+record_ring_samples-8)
                                addr_q<=BASE_APP_ADDR;
                            else addr_q<=addr_q+8;
                        end else source_lane<=source_lane+1'b1;
                        if (copied_pairs==goal_pairs-1) begin
                            burst_loaded<=0;
                            state<=PUBLISH;
                        end
                    end
                end
                PUBLISH: if (!desc_busy) begin
                    desc_send<=1;
                    state<=WAIT_ACK;
                end
                WAIT_ACK: if (ack_valid) begin
                    if (ack_dst==index_q) begin
                        next_offset<=next_offset+bytes_q;
                        index_q<=index_q+1;
                        stream_done<=last_q;
                        state<=IDLE;
                    end else begin
                        protocol_error<=1;
                        state<=FAULT;
                    end
                end
                FAULT: begin end
                default: begin protocol_error<=1; state<=FAULT; end
            endcase
            if ((app_rd_data_valid && (!response_expected || !app_rd_data_end)) ||
                consumer_fault_ui || (stream_clear && !idle)) begin
                protocol_error<=1;
                state<=FAULT;
            end
        end
    end
endmodule
`default_nettype wire
