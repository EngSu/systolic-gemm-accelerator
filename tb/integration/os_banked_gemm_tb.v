`timescale 1ns/1ps
// Self-checking Stage 11 regression. Requires 16-bit data, 32-bit accumulation.
// Exercises 3 GEMMs per run without a global reset: positive, signed, overflow.
module os_banked_gemm_tb #(
    parameter integer ROWS = 2,
    parameter integer K = 2,
    parameter integer COLS = 2
);
    localparam integer DW = 16;
    localparam integer CW = 32;
    localparam integer AW = (K <= 1) ? 1 : $clog2(K);
    localparam integer RUN_EDGES = K + ROWS + COLS - 2;

    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0, start = 1'b0, load_begin = 1'b0;
    reg a_wr_en = 1'b0, b_wr_en = 1'b0;
    reg [AW-1:0] wr_addr = 0;
    reg [ROWS*DW-1:0] a_wr_data_flat = 0;
    reg [COLS*DW-1:0] b_wr_data_flat = 0;
    wire load_ready, start_ready, busy, done;
    wire [ROWS*COLS*CW-1:0] c_flat;

    reg signed [DW-1:0] A [0:ROWS-1][0:K-1];
    reg signed [DW-1:0] B [0:K-1][0:COLS-1];
    reg signed [2*DW-1:0] product;
    reg signed [CW-1:0] exp_sum, observed;
    integer errors = 0, passed = 0;
    integer r, c, q, t, idx;

    os_gemm_banked_top #(.DATA_WIDTH(DW), .ACC_WIDTH(CW),
        .ROWS(ROWS), .COLS(COLS), .K(K)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .load_begin(load_begin), .a_wr_en(a_wr_en), .b_wr_en(b_wr_en),
        .wr_addr(wr_addr),
        .a_wr_data_flat(a_wr_data_flat), .b_wr_data_flat(b_wr_data_flat),
        .load_ready(load_ready), .start_ready(start_ready),
        .busy(busy), .done(done), .c_flat(c_flat)
    );

    task run_case;
        input integer case_id;
        integer before_errors;
        begin
            before_errors = errors;
            // Matrix patterns identical in spirit to Stage 10.
            for (r=0; r<ROWS; r=r+1)
                for (q=0; q<K; q=q+1)
                    if (case_id == 0)
                        A[r][q] = r*K + q + 1;
                    else if (case_id == 1)
                        A[r][q] = (((r+q)%2)==0) ? -(r*K+q+1) : (r*K+q+1);
                    else
                        A[r][q] = 16'sd32767;
            for (q=0; q<K; q=q+1)
                for (c=0; c<COLS; c=c+1)
                    if (case_id == 0)
                        B[q][c] = 5 + q*COLS + c;
                    else if (case_id == 1)
                        B[q][c] = (((q+c)%2)==0) ? (q*COLS+c+2) : -(q*COLS+c+2);
                    else
                        B[q][c] = 16'sd32767;

            // Explicitly invalidate old matrix content without resetting RAM.
            @(negedge clk);
            load_begin = 1'b1;
            a_wr_en = 1'b0;
            b_wr_en = 1'b0;
            @(posedge clk); #1;
            if (start_ready !== 1'b0) begin
                $display("FAIL case=%0d: load_begin did not invalidate operands", case_id);
                errors = errors + 1;
            end
            load_begin = 1'b0;

            // Each load edge writes A[r][k] to each row bank and B[k][c]
            // to each column bank, for the same address k.
            for (q=0; q<K; q=q+1) begin
                @(negedge clk);
                wr_addr = q;
                a_wr_en = 1'b1;
                b_wr_en = 1'b1;
                a_wr_data_flat = 0;
                b_wr_data_flat = 0;
                for (r=0; r<ROWS; r=r+1)
                    a_wr_data_flat[r*DW +: DW] = A[r][q];
                for (c=0; c<COLS; c=c+1)
                    b_wr_data_flat[c*DW +: DW] = B[q][c];
                @(posedge clk); #1;
                if (q < K-1 && start_ready !== 1'b0) begin
                    $display("FAIL case=%0d: start_ready asserted before all addresses loaded", case_id);
                    errors = errors + 1;
                end
            end
            if (start_ready !== 1'b1 || load_ready !== 1'b1) begin
                $display("FAIL case=%0d: start_ready not asserted after loading", case_id);
                errors = errors + 1;
            end

            @(negedge clk);
            a_wr_en = 1'b0;
            b_wr_en = 1'b0;
            start = 1'b1;
            @(posedge clk); #1;
            start = 1'b0;
            if (dut.clear_acc !== 1'b1 || busy !== 1'b1 || done !== 1'b0) begin
                $display("FAIL case=%0d: missing CLEAR state", case_id);
                errors = errors + 1;
            end
            // At this edge RAM outputs E0 operands; accumulator is cleared.
            @(posedge clk); #1;
            if (dut.clear_acc !== 1'b0 || busy !== 1'b1 || done !== 1'b0) begin
                $display("FAIL case=%0d: missing RUN state", case_id);
                errors = errors + 1;
            end
            for (r=0; r<ROWS; r=r+1)
                for (c=0; c<COLS; c=c+1)
                    if (c_flat[(r*COLS+c)*CW +: CW] !== {CW{1'b0}}) begin
                        $display("FAIL case=%0d: accumulator not zero after CLEAR", case_id);
                        errors = errors + 1;
                    end

            for (t=0; t<RUN_EDGES; t=t+1) begin
                // Verify each live bank output and its matching valid bit,
                // before the array captures the current processing edge.
                for (r=0; r<ROWS; r=r+1) begin
                    idx = t-r;
                    if ((idx >= 0) && (idx < K)) begin
                        if (dut.a_valid_left[r] !== 1'b1 ||
                            $signed(dut.a_left_flat[r*DW +: DW]) !== A[r][idx]) begin
                            $display("FAIL case=%0d edge=%0d A bank=%0d address=%0d",case_id,t,r,idx);
                            errors = errors + 1;
                        end
                    end else if (dut.a_valid_left[r] !== 1'b0) begin
                        $display("FAIL case=%0d edge=%0d: A bank %0d incorrectly valid",case_id,t,r);
                        errors = errors + 1;
                    end
                end
                for (c=0; c<COLS; c=c+1) begin
                    idx = t-c;
                    if ((idx >= 0) && (idx < K)) begin
                        if (dut.b_valid_top[c] !== 1'b1 ||
                            $signed(dut.b_top_flat[c*DW +: DW]) !== B[idx][c]) begin
                            $display("FAIL case=%0d edge=%0d B bank=%0d address=%0d",case_id,t,c,idx);
                            errors = errors + 1;
                        end
                    end else if (dut.b_valid_top[c] !== 1'b0) begin
                        $display("FAIL case=%0d edge=%0d: B bank %0d incorrectly valid",case_id,t,c);
                        errors = errors + 1;
                    end
                end

                @(posedge clk); #1;
                for (r=0; r<ROWS; r=r+1)
                    for (c=0; c<COLS; c=c+1) begin
                        exp_sum = {CW{1'b0}};
                        for (q=0; q<K; q=q+1)
                            if ((r+c+q) <= t) begin
                                product = A[r][q] * B[q][c];
                                exp_sum = exp_sum + $signed(product);
                            end
                        observed = $signed(c_flat[(r*COLS+c)*CW +: CW]);
                        if (observed !== exp_sum) begin
                            $display("FAIL case=%0d edge=%0d PE(%0d,%0d) expected=%0d got=%0d",
                                case_id,t,r,c,exp_sum,observed);
                            errors = errors + 1;
                        end
                    end
            end
            if (done !== 1'b1 || busy !== 1'b0) begin
                $display("FAIL case=%0d: missing DONE pulse",case_id);
                errors = errors + 1;
            end
            @(posedge clk); #1;
            if (done !== 1'b0 || busy !== 1'b0 || start_ready !== 1'b1) begin
                $display("FAIL case=%0d: DONE must be one cycle, then IDLE",case_id);
                errors = errors + 1;
            end
            if (errors == before_errors) begin
                passed = passed + 1;
                $display("PASS Stage11 M=%0d K=%0d N=%0d case=%0d",ROWS,K,COLS,case_id);
            end
        end
    endtask

    initial begin
        if (ROWS < 1 || COLS < 1 || K < 1)
            $fatal(1,"Dimensions must be positive");
        repeat (2) @(posedge clk);
        @(negedge clk); rst_n = 1'b1;
        // A start before loading should be ignored.
        start = 1'b1;
        @(posedge clk); #1;
        if (busy !== 1'b0 || done !== 1'b0 || start_ready !== 1'b0) begin
            $display("FAIL: start incorrectly accepted before loading");
            errors = errors + 1;
        end
        start = 1'b0;

        run_case(0);
        run_case(1);
        run_case(2);

        if (errors != 0)
            $fatal(1,"STAGE 11 FAILED M=%0d K=%0d N=%0d errors=%0d",ROWS,K,COLS,errors);
        $display("ALL STAGE 11 BANKED MEMORY TESTS PASSED M=%0d K=%0d N=%0d cases=%0d",ROWS,K,COLS,passed);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1,"Stage 11 simulation timeout");
    end
endmodule
