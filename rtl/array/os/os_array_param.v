
`timescale 1ns/1ps

module os_array_param #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32,
    parameter ROWS       = 2,
    parameter COLS       = 2
)(
    input wire clk,
    input wire rst_n,
    input wire clear_acc,

    // A enters from the left, one value per row.
    input wire [ROWS*DATA_WIDTH-1:0] a_left_flat,
    input wire [ROWS-1:0] a_valid_left,

    // B enters from the top, one value per column.
    input wire [COLS*DATA_WIDTH-1:0] b_top_flat,
    input wire [COLS-1:0] b_valid_top,

    // Row-major array of output accumulators.
    output wire [ROWS*COLS*ACC_WIDTH-1:0] c_flat
);

    // A travels horizontally.
    wire signed [DATA_WIDTH-1:0]
        a_bus [0:ROWS-1][0:COLS];

    // B travels vertically.
    wire signed [DATA_WIDTH-1:0]
        b_bus [0:ROWS][0:COLS-1];

    // Independent operand-valid pipelines.
    wire a_valid_bus [0:ROWS-1][0:COLS];
    wire b_valid_bus [0:ROWS][0:COLS-1];

    genvar r, c;

    generate

        // -------------------------------------
        // Left boundary: incoming A operands
        // -------------------------------------

        for (r = 0; r < ROWS; r = r + 1) begin : A_INPUTS

            assign a_bus[r][0] =
                a_left_flat[r*DATA_WIDTH +: DATA_WIDTH];

            assign a_valid_bus[r][0] = a_valid_left[r];

        end

        // -------------------------------------
        // Top boundary: incoming B operands
        // -------------------------------------

        for (c = 0; c < COLS; c = c + 1) begin : B_INPUTS

            assign b_bus[0][c] =
                b_top_flat[c*DATA_WIDTH +: DATA_WIDTH];

            assign b_valid_bus[0][c] = b_valid_top[c];

        end

        // -------------------------------------
        // Generate ROWS x COLS processing PEs
        // -------------------------------------

        for (r = 0; r < ROWS; r = r + 1) begin : GEN_ROWS

            for (c = 0; c < COLS; c = c + 1) begin : GEN_COLS

                reg a_valid_q;
                reg b_valid_q;

                // Valid bits advance with the
                // corresponding registered operands.
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        a_valid_q <= 1'b0;
                        b_valid_q <= 1'b0;
                    end
                    else begin
                        a_valid_q <= a_valid_bus[r][c];
                        b_valid_q <= b_valid_bus[r][c];
                    end
                end

                assign a_valid_bus[r][c+1] = a_valid_q;
                assign b_valid_bus[r+1][c] = b_valid_q;

                // Instantiate one existing OS PE.
                pe_os #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .clear_acc(clear_acc),

                    .a_in(a_bus[r][c]),
                    .b_in(b_bus[r][c]),

                    .valid_in(
                        a_valid_bus[r][c] &
                        b_valid_bus[r][c]
                    ),

                    // Registered operand forwarding.
                    .a_out(a_bus[r][c+1]),
                    .b_out(b_bus[r+1][c]),

                    // The wrapper tracks validity
                    // independently for A and B.
                    .valid_out(),

                    .acc_out(
                        c_flat[
                            ((r*COLS+c)*ACC_WIDTH)
                            +: ACC_WIDTH
                        ]
                    )
                );

            end
        end

    endgenerate

endmodule

