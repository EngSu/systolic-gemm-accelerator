`timescale 1ns/1ps
// Compile once with original pe_os.v and again with experimental version.
// Define EXPECT_SYNC_ACC_RESET only when compiling the experimental RTL.
module pe_os_reset_characterization_tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0;
    reg clear_acc = 0;
    reg valid_in = 0;
    reg signed [15:0] a_in = 0;
    reg signed [15:0] b_in = 0;
    wire signed [15:0] a_out, b_out;
    wire valid_out;
    wire signed [31:0] acc_out;

    pe_os #(.DATA_WIDTH(16), .ACC_WIDTH(32)) dut (
        .clk(clk), .rst_n(rst_n), .clear_acc(clear_acc),
        .valid_in(valid_in), .a_in(a_in), .b_in(b_in),
        .a_out(a_out), .b_out(b_out), .valid_out(valid_out),
        .acc_out(acc_out)
    );

    initial begin
        // Reset is held across multiple clock edges, so both versions initialize.
        repeat (2) @(posedge clk);
        #1;
        if (acc_out !== 32'sd0)
            $fatal(1, "initial acc_out=%0d, expected 0", acc_out);

        @(negedge clk);
        rst_n = 1;
        a_in = 2;
        b_in = 3;
        valid_in = 1;
        @(posedge clk);
        #1;
        if (acc_out !== 32'sd6)
            $fatal(1, "accumulate: got %0d, expected 6", acc_out);

        // Assert reset between rising edges: two versions must now differ.
        #1 rst_n = 0;
        #1;
`ifdef EXPECT_SYNC_ACC_RESET
        if (acc_out !== 32'sd6)
            $fatal(1, "synchronous reset modified acc before clk: %0d", acc_out);
        $display("PASS: experimental accumulator does NOT reset before clock");
`else
        if (acc_out !== 32'sd0)
            $fatal(1, "asynchronous accumulator did not reset immediately: %0d", acc_out);
        $display("PASS: baseline accumulator resets asynchronously");
`endif
        if (valid_out !== 1'b0)
            $fatal(1, "forwarded valid must clear asynchronously");

        @(posedge clk);
        #1;
        if (acc_out !== 32'sd0)
            $fatal(1, "accumulator did not reset at clock edge");

        @(negedge clk);
        rst_n = 1;
        valid_in = 0;
        clear_acc = 0;
        @(posedge clk);
        #1;
        if (acc_out !== 32'sd0)
            $fatal(1, "hold check failed");

        $display("PASS: PE reset-characterization experiment completed");
        $finish;
    end
endmodule
