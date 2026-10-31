`timescale 1ns/1ps
// Timing controller for synchronous-read operand banks.
// Read E0 operands at the CLEAR edge; during E(t), read E(t+1) operands.
// Registered read-valid flags advance on the same edge as the RAM output.
module os_mem_prefetch_ctrl #(
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

    output wire load_ready,
    output wire start_ready,
    output wire busy,
    output wire done,
    output wire clear_acc,

    output reg [ROWS*ADDR_WIDTH-1:0] a_rd_addr_flat,
    output reg [COLS*ADDR_WIDTH-1:0] b_rd_addr_flat,
    output reg [ROWS-1:0] a_rd_en,
    output reg [COLS-1:0] b_rd_en,
    output reg [ROWS-1:0] a_valid_left,
    output reg [COLS-1:0] b_valid_top
);
    localparam integer RUN_EDGES = K + ROWS + COLS - 2;
    localparam integer COUNT_WIDTH = (RUN_EDGES <= 1) ? 1 : $clog2(RUN_EDGES);
    localparam [1:0] IDLE = 2'd0, CLEAR = 2'd1,
                     RUN = 2'd2, DONE = 2'd3;

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] run_index;
    reg [K-1:0] loaded_a, loaded_b;
    wire wr_index_valid = (wr_addr < K);

    assign load_ready = (state == IDLE);
    assign start_ready = (state == IDLE) && (&loaded_a) && (&loaded_b);
    assign clear_acc = (state == CLEAR);
    assign busy = (state == CLEAR) || (state == RUN);
    assign done = (state == DONE);

    // All markers must be refreshed after load_begin before starting a new matrix.
    // Memory contents are *not* reset. No loading during processing is accepted.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            run_index <= {COUNT_WIDTH{1'b0}};
            loaded_a <= {K{1'b0}};
            loaded_b <= {K{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    if (load_begin) begin
                        loaded_a <= {K{1'b0}};
                        loaded_b <= {K{1'b0}};
                    end else begin
                        if (a_wr_en && wr_index_valid)
                            loaded_a[wr_addr] <= 1'b1;
                        if (b_wr_en && wr_index_valid)
                            loaded_b[wr_addr] <= 1'b1;
                        if (start && start_ready && !a_wr_en && !b_wr_en) begin
                            state <= CLEAR;
                            run_index <= {COUNT_WIDTH{1'b0}};
                        end
                    end
                end
                CLEAR: begin
                    state <= RUN;
                    run_index <= {COUNT_WIDTH{1'b0}};
                end
                RUN: begin
                    if (run_index == RUN_EDGES-1)
                        state <= DONE;
                    else
                        run_index <= run_index + 1'b1;
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end

    // Read requests are driven combinationally BEFORE each rising edge.
    // CLEAR requests E0; RUN E(t) requests E(t+1).
    integer t_req, r, c, k_idx;
    always @* begin
        a_rd_addr_flat = {ROWS*ADDR_WIDTH{1'b0}};
        b_rd_addr_flat = {COLS*ADDR_WIDTH{1'b0}};
        a_rd_en = {ROWS{1'b0}};
        b_rd_en = {COLS{1'b0}};
        t_req = -1;
        k_idx = 0;
        if (state == CLEAR)
            t_req = 0;
        else if ((state == RUN) && (run_index < RUN_EDGES-1))
            t_req = run_index + 1;
        if (t_req >= 0) begin
            for (r = 0; r < ROWS; r = r + 1) begin
                k_idx = t_req - r;
                if ((k_idx >= 0) && (k_idx < K)) begin
                    a_rd_en[r] = 1'b1;
                    a_rd_addr_flat[r*ADDR_WIDTH +: ADDR_WIDTH] = k_idx;
                end
            end
            for (c = 0; c < COLS; c = c + 1) begin
                k_idx = t_req - c;
                if ((k_idx >= 0) && (k_idx < K)) begin
                    b_rd_en[c] = 1'b1;
                    b_rd_addr_flat[c*ADDR_WIDTH +: ADDR_WIDTH] = k_idx;
                end
            end
        end
    end

    // Align flags with the synchronous read outputs.
    // The banks intentionally have no reset on their read data registers.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_valid_left <= {ROWS{1'b0}};
            b_valid_top <= {COLS{1'b0}};
        end else begin
            a_valid_left <= a_rd_en;
            b_valid_top <= b_rd_en;
        end
    end
endmodule
