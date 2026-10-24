
`timescale 1ns/1ps

module ws_array_param #(
    parameter DATA_WIDTH = 16,
    parameter ACC_WIDTH  = 32,
    parameter K_STAGES   = 2,
    parameter COLS       = 2
)(
    input wire clk,
    input wire rst_n,

    // Preload all stationary weights together.
    input wire load_weights,
    input wire [K_STAGES*COLS*DATA_WIDTH-1:0] weights_flat,

    // One activation per reduction stage.
    input wire [K_STAGES*DATA_WIDTH-1:0] activation_flat,
    input wire [K_STAGES-1:0] activation_valid,

    // Streaming outputs, one per column.
    output wire [COLS*ACC_WIDTH-1:0] result_flat,
    output wire [COLS-1:0] result_valid
);

    // Registered partial sums and their validity.
    wire [ACC_WIDTH-1:0]
        psum_bus [0:K_STAGES-1][0:COLS-1];

    wire valid_bus [0:K_STAGES-1][0:COLS-1];

    genvar k, c;

    generate
        for (k = 0; k < K_STAGES; k = k + 1) begin : GEN_STAGES

            for (c = 0; c < COLS; c = c + 1) begin : GEN_COLS

                wire [ACC_WIDTH-1:0] incoming_psum;
                wire incoming_valid;

                if (k == 0) begin : FIRST_STAGE

                    // First stage starts the sum at zero.
                    assign incoming_psum = {ACC_WIDTH{1'b0}};
                    assign incoming_valid = activation_valid[k];

                end
                else begin : LATER_STAGE

                    // Consume the previous stage's
                    // registered partial sum.
                    assign incoming_psum = psum_bus[k-1][c];

                    assign incoming_valid =
                        valid_bus[k-1][c] &
                        activation_valid[k];

                end

                pe_ws #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH(ACC_WIDTH)
                ) u_pe (
                    .clk(clk),
                    .rst_n(rst_n),

                    .load_weight(load_weights),
                    .weight_in(
                        weights_flat[
                            (k*COLS+c)*DATA_WIDTH
                            +: DATA_WIDTH
                        ]
                    ),

                    .activation_in(
                        activation_flat[
                            k*DATA_WIDTH +: DATA_WIDTH
                        ]
                    ),

                    .psum_in(incoming_psum),
                    .valid_in(incoming_valid),

                    .psum_out(psum_bus[k][c]),
                    .valid_out(valid_bus[k][c])
                );

            end
        end

        // Connect last-stage results to output ports.
        for (c = 0; c < COLS; c = c + 1) begin : OUTPUTS

            assign result_flat[c*ACC_WIDTH +: ACC_WIDTH] =
                psum_bus[K_STAGES-1][c];

            assign result_valid[c] =
                valid_bus[K_STAGES-1][c];

        end
    endgenerate

endmodule

