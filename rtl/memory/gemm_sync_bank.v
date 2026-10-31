`timescale 1ns/1ps
// One synchronous-read, one synchronous-write port, same clock.
// No RAM initialization/reset: write all addresses before the first read.
// This template may infer BRAM, distributed RAM or registers depending on size.
module gemm_sync_bank #(
    parameter integer DATA_WIDTH = 16,
    parameter integer DEPTH = 4,
    parameter integer ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
)(
    input wire clk,
    input wire wr_en,
    input wire [ADDR_WIDTH-1:0] wr_addr,
    input wire [DATA_WIDTH-1:0] wr_data,
    input wire rd_en,
    input wire [ADDR_WIDTH-1:0] rd_addr,
    output reg [DATA_WIDTH-1:0] rd_data
);
    (* ram_style = "auto" *) reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
        if (rd_en)
            rd_data <= mem[rd_addr];
    end
endmodule
