// ============================================================================
// 模块：adc_ddr_fbg484_top —— 双通道 ADC 采集与 DDR3 存储调试顶层
// 底稿：用户本次粘贴的无 LED、带读回 VIO 顶层代码。
// 数据路径：ADC -> 采集/打包 -> 异步 FIFO -> MIG -> DDR3 -> 块缓存 -> VIO。
// 本文件仅调整空白排版并增加中文说明，保留全部端口、参数和实例连接。
// 引脚电气兼容性、时钟 P/N 与输入时序约束仍须独立核对；注释不代替验证。
// ============================================================================

`timescale 1ns/1ps
`default_nettype none
module adc_ddr_fbg484_top(

    // 板载系统时钟；沿用参考工程的 50 MHz 输入配置
    input wire sys_clk, sys_rst_n, 

    // ADC 返回的数据时钟；以此时钟接收 A、B 两路数据
    input wire ADC_CLK_OUT_P, 

    // 两路 ADC 有效数据总线，保留原理图的 [13:2] 编号，每路 12 位
    input wire [13:2] ADC_DA, ADC_DB, 

    // FPGA 送给 ADC 的差分采样时钟；P/N 物理对应及电气标准需单独核对
    output wire ADC_CLK_IN_P, ADC_CLK_IN_N, 

    // ADC 复位及串行配置输出；本版只写配置，不提供 ADC_SDO 读回
    output wire ADC_RESET, ADC_CS, ADC_SCK, ADC_SDI, 

    // ADC 控制引脚；数组下标 0、1、2 对应原理图 CTRL1、CTRL2、CTRL3
    output wire [2:0] ADC_CTRL, 

    // 两颗 x16 DDR 组成的 32 位双向数据总线
    inout wire [31:0] ddr3_dq, 

    // 四组差分数据选通，每组对应一个数据字节
    inout wire [3:0] ddr3_dqs_n, ddr3_dqs_p, 

    // DDR 行列复用地址，具体含义由 MIG 命令时序决定
    output wire [13:0] ddr3_addr, 

    // DDR 内部存储体地址
    output wire [2:0] ddr3_ba, 

    // DDR 命令及复位信号，后缀 _n 表示低有效
    output wire ddr3_ras_n, ddr3_cas_n, ddr3_we_n, ddr3_reset_n, 

    // DDR 差分时钟、时钟使能、片选和片内终端控制
    output wire [0:0] ddr3_ck_p, ddr3_ck_n, ddr3_cke, ddr3_cs_n, ddr3_odt, 

    // 四个字节的数据掩码
    output wire [3:0] ddr3_dm
);

    // 时钟与状态：200 MHz 供 MIG，100 MHz 供采样时钟转发；ui_clk 由 MIG 输出
    wire clk_200m, clk_100m, locked, ui_clk, ui_rst, calib;

    // ------------------------------------------------------------------------
    // 时钟生成
    // Clocking Wizard 生成 200 MHz 和 100 MHz；locked 表示输出时钟已锁定。
    // ------------------------------------------------------------------------
    capture_clocks u_clocks(
        .clk_in1               (sys_clk),
        .reset                 (!sys_rst_n),
        .locked                (locked),
        .clk_out1              (clk_200m),
        .clk_out2              (clk_100m)
    );

    // ------------------------------------------------------------------------
    // ADC 采样时钟转发
    // 将 100 MHz 时钟经专用输出逻辑送至 ADC；本次保留原有连接，不修改 P/N。
    // ------------------------------------------------------------------------
    adc_clock_forward_7series u_forward(
        .clk_100m              (clk_100m),
        .adc_clk_p             (ADC_CLK_IN_P),
        .adc_clk_n             (ADC_CLK_IN_N)
    );

    // MIG 原生接口地址；位宽及地址步进由存储模块与 MIG 配置共同约定
    wire [27:0] app_addr;

    // MIG 命令码：写命令 000，读命令 001
    wire [2:0] app_cmd;

    // MIG 命令握手与写数据握手；两组就绪信号独立
    wire app_en, app_rdy, app_wdf_wren, app_wdf_end, app_wdf_rdy;

    // MIG 单拍写数据，256 位可容纳 8 组 A/B 样本
    wire [255:0] app_wdf_data;

    // 写数据的逐字节掩码，1 表示对应字节不写入
    wire [31:0] app_wdf_mask;

    // 采集长度、记录统计及锁存长度；cfg_samples 单位为样本对，不是毫秒
    wire [31:0] cfg_samples, record_samples, record_bytes, blocks, latched_samples;

    // 采集命令与状态；done 表示记录提交完成，valid 表示记录有效
    wire start, release_record, ready, busy, done, valid, overflow, cfg_done, accepted, rejected, capture_finished;

    // MIG 返回的 256 位读数据
    wire [255:0] app_rd_data;

    // MIG 返回数据的有效标志和突发结束标志
    wire app_rd_data_valid, app_rd_data_end;

    // DDR 分块读取命令及读取状态
    wire read_next, read_ready, read_accepted, read_idle, stream_done, read_error;

    // 调试读字命令、实际读脉冲、块确认命令和调试清除命令
    wire read_word, rd_en, block_ack, clear_debug;

    // 8 KiB 块缓存的 16 位字地址，范围 0～4095
    wire [11:0] rd_addr;

    // 缓存返回数据、调试状态及供 VIO 显示的最近一次有效数据
    wire [15:0] rd_data, debug_status, debug_data;

    // 缓存与块所有权状态，以及确认/读字命令的接收或拒绝标志
    wire rd_valid, block_ready, block_last, ack_accepted, ack_rejected, rd_rejected;

    // 当前块序号、记录内字节偏移，以及调试累计计数
    wire [31:0] block_index, block_offset, debug_words, debug_acks, debug_requests;

    // 当前块有效字节数；完整块为 8192，最后一块可能不足
    wire [13:0] block_bytes;

    // ui_clk 域调试复位，高有效，由 reset_sync 同步释放
    wire debug_rst;

    // ------------------------------------------------------------------------
    // 调试复位同步
    // 外部复位、时钟失锁或 MIG 用户复位均使调试逻辑复位；在 ui_clk 域同步释放。
    // ------------------------------------------------------------------------
    reset_sync u_debug_reset(
        .clk                   (ui_clk),
        .arst                  (!sys_rst_n || !locked || ui_rst),
        .rst                   (debug_rst)
    );

    // ------------------------------------------------------------------------
    // 采集、DDR 写入与分块读回
    // 内部完成 ADC 初始化、跨时钟缓存、定长采集和 MIG 读写调度。
    // 记录完成后按命令读入块缓存；消费者读取后确认，才能复用该块缓存。
    // 本版读回消费者使用 ui_clk，尚未接入 STM32 FMC。
    // ------------------------------------------------------------------------
    adc_record_store #(.APP_ADDR_WIDTH(28)) u_store(

        .ui_clk                (ui_clk),
        .ui_rst                (ui_rst),
        .global_rst            (!sys_rst_n || !locked),
        .init_calib_complete   (calib),
        .adc_clk_out           (ADC_CLK_OUT_P),
        .adc_da                (ADC_DA),
        .adc_db                (ADC_DB),
        .adc_reset             (ADC_RESET),
        .adc_cs_n              (ADC_CS),
        .adc_sck               (ADC_SCK),
        .adc_sdi               (ADC_SDI),
        .adc_ctrl              (ADC_CTRL),
        .cfg_samples           (cfg_samples),
        .cmd_start             (start),
        .cmd_release           (release_record),
        .cmd_read_next         (read_next),
        .ready                 (ready),
        .busy                  (busy),
        .cfg_done              (cfg_done),
        .start_accepted        (accepted),
        .command_rejected      (rejected),
        .record_done           (done),
        .record_valid          (valid),
        .capture_finished      (capture_finished),
        .overflow              (overflow),
        .record_samples        (record_samples),
        .record_bytes          (record_bytes),
        .latched_samples       (latched_samples),
        .submitted_blocks      (blocks),
        .app_addr              (app_addr),
        .app_cmd               (app_cmd),
        .app_en                (app_en),
        .app_rdy               (app_rdy),
        .app_wdf_data          (app_wdf_data),
        .app_wdf_mask          (app_wdf_mask),
        .app_wdf_wren          (app_wdf_wren),
        .app_wdf_end           (app_wdf_end),
        .app_wdf_rdy           (app_wdf_rdy),
        .app_rd_data           (app_rd_data),
        .app_rd_data_valid     (app_rd_data_valid),
        .app_rd_data_end       (app_rd_data_end),
        .read_ready            (read_ready),
        .read_accepted         (read_accepted),
        .read_idle             (read_idle),
        .stream_done           (stream_done),
        .read_error            (read_error),
        .rd_clk                (ui_clk),
        .rd_en                 (rd_en),
        .rd_addr               (rd_addr),
        .rd_data               (rd_data),
        .rd_valid              (rd_valid),
        .block_ready           (block_ready),
        .block_index           (block_index),
        .block_offset          (block_offset),
        .block_bytes           (block_bytes),
        .block_last            (block_last),
        .cmd_block_ack         (block_ack),
        .ack_accepted          (ack_accepted),
        .ack_rejected          (ack_rejected),
        .rd_rejected           (rd_rejected)
    );

    // ------------------------------------------------------------------------
    // 读回调试适配
    // 将 read_word 上升沿变为一次读脉冲，并保存返回数据、事件标志及计数。
    // debug_status[5:0]：读就绪、读空闲、块就绪、末块、流完成、读错误。
    // debug_status[12:6]：读数据有效、读命令接受、块确认接受、命令拒绝、
    //                      块确认拒绝、读字拒绝、采集启动接受；这些事件保持到清除。
    // ------------------------------------------------------------------------
    readout_debug u_read_debug(

        .clk                   (ui_clk),
        .rst                   (debug_rst),
        .read_word             (read_word),
        .clear_debug           (clear_debug),
        .rd_en                 (rd_en),
        .read_ready            (read_ready),
        .read_idle             (read_idle),
        .block_ready           (block_ready),
        .block_last            (block_last),
        .stream_done           (stream_done),
        .read_error            (read_error),
        .rd_valid              (rd_valid),
        .rd_data               (rd_data),
        .read_accepted         (read_accepted),
        .ack_accepted          (ack_accepted),
        .command_rejected      (rejected),
        .ack_rejected          (ack_rejected),
        .rd_rejected           (rd_rejected),
        .start_accepted        (accepted),
        .status                (debug_status),
        .last_data             (debug_data),
        .word_count            (debug_words),
        .ack_count             (debug_acks),
        .request_count         (debug_requests)
    );

    // ------------------------------------------------------------------------
    // 读回 VIO 面板
    // 通过 Hardware Manager 手动请求数据块、选择字地址、读取并确认数据块。
    // ------------------------------------------------------------------------
    readout_vio u_read_vio(
        .clk                   (ui_clk),
        .probe_in0             (debug_status), // 综合读回状态
        .probe_in1             (block_index), // 当前块序号
        .probe_in2             (block_offset), // 当前块在记录中的字节偏移
        .probe_in3             (block_bytes), // 当前块有效字节数
        .probe_in4             (debug_data), // 最近一次读出的 16 位数据
        .probe_in5             (debug_words), // 累计有效读字次数
        .probe_in6             (debug_acks), // 累计成功确认块次数
        .probe_in7             (debug_requests), // 累计接受读块请求次数
        .probe_out0            (read_next), // 请求下一块
        .probe_out1            (rd_addr), // 块内 16 位字地址
        .probe_out2            (read_word), // 读一个字，上升沿有效
        .probe_out3            (block_ack), // 确认当前块已消费
        .probe_out4            (clear_debug) // 清除调试事件与计数
    );

    // ------------------------------------------------------------------------
    // 采集 VIO 面板
    // 设置采样对数并启动采集；例如 100 MSPS 下，200 ms 对应 20000000 对。
    // 目前未实现毫秒到采样对数的顶层换算，也未实现 FMC 寄存器接口。
    // ------------------------------------------------------------------------
    capture_vio u_vio(
        .clk                   (ui_clk),
        .probe_in0             (ready), // 可接受采集启动
        .probe_in1             (busy), // 采集忙
        .probe_in2             (done), // 记录完成
        .probe_in3             (valid), // 记录有效
        .probe_in4             (overflow), // 采集溢出
        .probe_in5             (record_samples), // 记录实际样本对数
        .probe_in6             (record_bytes), // 记录有效字节数
        .probe_in7             (blocks), // 已提交写块数
        .probe_in8             (cfg_done), // ADC 初始化完成
        .probe_out0            (cfg_samples), // 目标样本对数
        .probe_out1            (start), // 启动采集命令
        .probe_out2            (release_record) // 释放当前记录命令
    );

    // ------------------------------------------------------------------------
    // DDR3 MIG 控制器
    // 保持厂家 IP 及端口连接；当前配置的 sys_rst 为低有效。
    // app_* 为用户侧原生接口，ddr3_* 为外部存储器接口。
    // 手动自刷新、刷新和 ZQ 请求置零；正常刷新由 MIG 自身管理。
    // ------------------------------------------------------------------------
    mig_7series_0 u_mig(

        .ddr3_dq               (ddr3_dq),
        .ddr3_dqs_n            (ddr3_dqs_n),
        .ddr3_dqs_p            (ddr3_dqs_p),
        .ddr3_addr             (ddr3_addr),
        .ddr3_ba               (ddr3_ba),
        .ddr3_ras_n            (ddr3_ras_n),
        .ddr3_cas_n            (ddr3_cas_n),
        .ddr3_we_n             (ddr3_we_n),
        .ddr3_reset_n          (ddr3_reset_n),
        .ddr3_ck_p             (ddr3_ck_p),
        .ddr3_ck_n             (ddr3_ck_n),
        .ddr3_cke              (ddr3_cke),
        .ddr3_cs_n             (ddr3_cs_n),
        .ddr3_odt              (ddr3_odt),
        .ddr3_dm               (ddr3_dm),
        .sys_clk_i             (clk_200m),
        .clk_ref_i             (clk_200m),
        .sys_rst               (sys_rst_n && locked),
        .ui_clk                (ui_clk),
        .ui_clk_sync_rst       (ui_rst),
        .init_calib_complete   (calib),
        .app_addr              (app_addr),
        .app_cmd               (app_cmd),
        .app_en                (app_en),
        .app_rdy               (app_rdy),
        .app_wdf_data          (app_wdf_data),
        .app_wdf_mask          (app_wdf_mask),
        .app_wdf_end           (app_wdf_end),
        .app_wdf_wren          (app_wdf_wren),
        .app_wdf_rdy           (app_wdf_rdy),
        .app_rd_data           (app_rd_data),
        .app_rd_data_valid     (app_rd_data_valid),
        .app_rd_data_end       (app_rd_data_end),
        .app_sr_req            (1'b0),
        .app_ref_req           (1'b0),
        .app_zq_req            (1'b0),
        .app_sr_active         (),
        .app_ref_ack           (),
        .app_zq_ack            ()
    );
endmodule
`default_nettype wire
