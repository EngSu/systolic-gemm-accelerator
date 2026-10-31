`timescale 1ns/1ps
// Stage 11: register-loaded banked operands -> prefetch -> verified OS array.
// A row r has bank r holding A[r][0..K-1].
// B col c has bank c holding B[0..K-1][c].
// At each load edge write one common K address across each enabled set of banks.
module os_gemm_banked_top #(
    parameter integer DATA_WIDTH = 16,
    parameter integer ACC_WIDTH = 32,
    parameter integer ROWS = 2,
    parameter integer COLS = 2,
    parameter integer K = 2,
    parameter integer ADDR_WIDTH = (K <= 1) ? 1 : $clog2(K)
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire load_begin,
    input wire a_wr_en,
    input wire b_wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [ROWS*DATA_WIDTH-1:0] a_wr_data_flat,
    input wire [COLS*DATA_WIDTH-1:0] b_wr_data_flat,
    output wire load_ready,
    output wire start_ready,
    output wire busy,
    output wire done,
    output wire [ROWS*COLS*ACC_WIDTH-1:0] c_flat
);
    wire [ROWS*ADDR_WIDTH-1:0] a_rd_addr_flat;
    wire [COLS*ADDR_WIDTH-1:0] b_rd_addr_flat;
    wire [ROWS-1:0] a_rd_en, a_valid_left;
    wire [COLS-1:0] b_rd_en, b_valid_top;
    wire [ROWS*DATA_WIDTH-1:0] a_left_flat;
    wire [COLS*DATA_WIDTH-1:0] b_top_flat;
    wire clear_acc;
    wire wr_allow = load_ready && !load_begin && (wr_addr < K);

    os_mem_prefetch_ctrl #(.ROWS(ROWS), .COLS(COLS), .K(K),
                           .ADDR_WIDTH(ADDR_WIDTH)) u_ctrl (
        .clk(clk), .rst_n(rst_n), .start(start), .load_begin(load_begin),
        .a_wr_en(a_wr_en), .b_wr_en(b_wr_en), .wr_addr(wr_addr),
        .load_ready(load_ready), .start_ready(start_ready),
        .busy(busy), .done(done), .clear_acc(clear_acc),
        .a_rd_addr_flat(a_rd_addr_flat), .b_rd_addr_flat(b_rd_addr_flat),
        .a_rd_en(a_rd_en), .b_rd_en(b_rd_en),
        .a_valid_left(a_valid_left), .b_valid_top(b_valid_top)
    );

    genvar r,c;
    generate
        for (r=0; r<ROWS; r=r+1) begin: A_BANK
            gemm_sync_bank #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(K),
                             .ADDR_WIDTH(ADDR_WIDTH)) u_bank (
                .clk(clk), .wr_en(wr_allow && a_wr_en),
                .wr_addr(wr_addr),
                .wr_data(a_wr_data_flat[r*DATA_WIDTH +: DATA_WIDTH]),
                .rd_en(a_rd_en[r]),
                .rd_addr(a_rd_addr_flat[r*ADDR_WIDTH +: ADDR_WIDTH]),
                .rd_data(a_left_flat[r*DATA_WIDTH +: DATA_WIDTH])
            );
        end
        for (c=0; c<COLS; c=c+1) begin: B_BANK
            gemm_sync_bank #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(K),
                             .ADDR_WIDTH(ADDR_WIDTH)) u_bank (
                .clk(clk), .wr_en(wr_allow && b_wr_en),
                .wr_addr(wr_addr),
                .wr_data(b_wr_data_flat[c*DATA_WIDTH +: DATA_WIDTH]),
                .rd_en(b_rd_en[c]),
                .rd_addr(b_rd_addr_flat[c*ADDR_WIDTH +: ADDR_WIDTH]),
                .rd_data(b_top_flat[c*DATA_WIDTH +: DATA_WIDTH])
            );
        end
    endgenerate

    os_array_param #(.DATA_WIDTH(DATA_WIDTH), .ACC_WIDTH(ACC_WIDTH),
                     .ROWS(ROWS), .COLS(COLS)) u_array (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .a_left_flat(a_left_flat), .a_valid_left(a_valid_left),
        .b_top_flat(b_top_flat), .b_valid_top(b_valid_top),
        .c_flat(c_flat)
    );
endmodule
