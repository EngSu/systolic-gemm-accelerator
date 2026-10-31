`timescale 1ns/1ps

// Register-backed input scheduler for a parameterized OS systolic array.
// Matrix input buses are packed in row-major order and MUST remain
// stable from start until done. No BRAM latency is modeled here.
module os_input_scheduler #(
    parameter DATA_WIDTH = 16,
    parameter ROWS = 2,
    parameter COLS = 2,
    parameter K = 2
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    input  wire [ROWS*K*DATA_WIDTH-1:0] a_matrix_flat,
    input  wire [K*COLS*DATA_WIDTH-1:0] b_matrix_flat,

    output reg  [ROWS*DATA_WIDTH-1:0] a_left_flat,
    output reg  [COLS*DATA_WIDTH-1:0] b_top_flat,
    output reg  [ROWS-1:0] a_valid_left,
    output reg  [COLS-1:0] b_valid_top,

    output wire clear_acc,
    output wire busy,
    output wire done
);
    // E0 ... E(TOTAL_EDGES-1), including pipeline drain.
    localparam integer TOTAL_EDGES = K + ROWS + COLS - 2;
    localparam integer COUNT_WIDTH =
        (TOTAL_EDGES <= 1) ? 1 : $clog2(TOTAL_EDGES);

    localparam [1:0] S_IDLE  = 2'd0;
    localparam [1:0] S_CLEAR = 2'd1;
    localparam [1:0] S_RUN   = 2'd2;
    localparam [1:0] S_DONE  = 2'd3;

    reg [1:0] state;
    reg [COUNT_WIDTH-1:0] cycle_count;

    assign clear_acc = (state == S_CLEAR);
    assign busy      = (state == S_CLEAR) || (state == S_RUN);
    assign done      = (state == S_DONE); // one-cycle pulse

    // Controller: one clear edge, then all processing edges.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            cycle_count <= {COUNT_WIDTH{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        state       <= S_CLEAR;
                        cycle_count <= {COUNT_WIDTH{1'b0}};
                    end
                end
                S_CLEAR: begin
                    state       <= S_RUN;
                    cycle_count <= {COUNT_WIDTH{1'b0}};
                end
                S_RUN: begin
                    if (cycle_count == TOTAL_EDGES - 1) begin
                        state <= S_DONE;
                    end else begin
                        cycle_count <= cycle_count + 1'b1;
                    end
                end
                S_DONE: state <= S_IDLE;
                default: state <= S_IDLE;
            endcase
        end
    end

    // Combinational, zero-latency selection from matrix input buses.
    // Inputs for E(t) are stable BEFORE their capturing rising edge.
    integer r, c, a_k, b_k;
    always @* begin
        a_left_flat  = {ROWS*DATA_WIDTH{1'b0}};
        b_top_flat   = {COLS*DATA_WIDTH{1'b0}};
        a_valid_left = {ROWS{1'b0}};
        b_valid_top  = {COLS{1'b0}};
        a_k = 0;
        b_k = 0;

        if (state == S_RUN) begin
            for (r = 0; r < ROWS; r = r + 1) begin
                if ((cycle_count >= r) && (cycle_count < (r + K))) begin
                    a_k = cycle_count - r;
                    a_left_flat[r*DATA_WIDTH +: DATA_WIDTH] =
                        a_matrix_flat[(r*K + a_k)*DATA_WIDTH +: DATA_WIDTH];
                    a_valid_left[r] = 1'b1;
                end
            end

            for (c = 0; c < COLS; c = c + 1) begin
                if ((cycle_count >= c) && (cycle_count < (c + K))) begin
                    b_k = cycle_count - c;
                    b_top_flat[c*DATA_WIDTH +: DATA_WIDTH] =
                        b_matrix_flat[(b_k*COLS + c)*DATA_WIDTH +: DATA_WIDTH];
                    b_valid_top[c] = 1'b1;
                end
            end
        end
    end
endmodule
