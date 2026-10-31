`timescale 1ns/1ps
// Stage 13 AXI4-Lite transaction-level regression for Stage 11 compute core.
// Exercises independent AW/W handshakes, register protocol, loading, computation,
// signed/overflow results, sticky DONE, invalid accesses, and repeated operations.
module os_axi4lite_gemm_tb #(
    parameter integer ROWS = 2,
    parameter integer K = 2,
    parameter integer COLS = 2
);
    localparam integer RUN_EDGES = K + ROWS + COLS - 2;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst_n = 1'b0;

    reg [11:0] awaddr = 0;
    reg [2:0] awprot = 0;
    reg awvalid = 0;
    wire awready;
    reg [31:0] wdata = 0;
    reg [3:0] wstrb = 4'hf;
    reg wvalid = 0;
    wire wready;
    wire [1:0] bresp;
    wire bvalid;
    reg bready = 0;
    reg [11:0] araddr = 0;
    reg [2:0] arprot = 0;
    reg arvalid = 0;
    wire arready;
    wire [31:0] rdata;
    wire [1:0] rresp;
    wire rvalid;
    reg rready = 0;

    os_gemm_axi_lite_top #(.ROWS(ROWS), .COLS(COLS), .K(K)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(rst_n),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp),
        .s_axi_rvalid(rvalid), .s_axi_rready(rready)
    );

    reg signed [15:0] A [0:ROWS-1][0:K-1];
    reg signed [15:0] B [0:K-1][0:COLS-1];
    reg signed [31:0] product;
    reg signed [31:0] expected;
    reg [31:0] value;
    reg [1:0] response;
    integer r, c, q, case_id, poll;
    integer errors = 0;
    integer tests_passed = 0;

    // skew=0 concurrent AW/W; 1 AW precedes W; 2 W precedes AW.
    task axi_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0] strobes;
        input integer skew;
        output [1:0] resp;
        reg aw_done, w_done;
        integer cycles;
        begin
            aw_done = 0;
            w_done = 0;
            cycles = 0;
            @(negedge clk);
            awaddr = addr;
            wdata = data;
            wstrb = strobes;
            awvalid = (skew != 2);
            wvalid = (skew != 1);
            bready = 0;
            while (!(aw_done && w_done)) begin
                @(posedge clk);
                if (awvalid && awready) aw_done = 1;
                if (wvalid && wready) w_done = 1;
                @(negedge clk);
                if (aw_done) awvalid = 0;
                if (w_done) wvalid = 0;
                cycles = cycles + 1;
                if (cycles >= 3) begin
                    if (skew == 1 && !w_done) wvalid = 1;
                    if (skew == 2 && !aw_done) awvalid = 1;
                end
                if (cycles > 100)
                    $fatal(1, "AXI write AW/W handshake timeout addr=%h", addr);
            end
            cycles = 0;
            while (bvalid !== 1'b1) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 100) $fatal(1, "AXI B timeout addr=%h", addr);
            end
            resp = bresp;
            // Check that write response holds under backpressure.
            repeat (2) begin
                @(posedge clk); #1;
                if (!bvalid || bresp !== resp)
                    $fatal(1, "AXI write response not held while BREADY=0");
            end
            @(negedge clk); bready = 1;
            @(posedge clk);
            @(negedge clk); bready = 0;
        end
    endtask

    task axi_write_expect;
        input [11:0] addr;
        input [31:0] data;
        input [3:0] strobes;
        input integer skew;
        input [1:0] expected_resp;
        reg [1:0] got_resp;
        begin
            axi_write(addr, data, strobes, skew, got_resp);
            if (got_resp !== expected_resp) begin
                $display("FAIL AXI write addr=%h data=%h resp=%b expected=%b",
                    addr, data, got_resp, expected_resp);
                errors = errors + 1;
            end
        end
    endtask

    task axi_read;
        input [11:0] addr;
        output [31:0] data;
        output [1:0] resp;
        integer cycles;
        reg accepted;
        begin
            accepted = 0;
            cycles = 0;
            @(negedge clk);
            araddr = addr;
            arvalid = 1;
            rready = 0;
            while (!accepted) begin
                @(posedge clk);
                if (arvalid && arready) accepted = 1;
                @(negedge clk);
                if (accepted) arvalid = 0;
                cycles = cycles + 1;
                if (cycles > 100) $fatal(1,"AXI AR timeout addr=%h",addr);
            end
            cycles = 0;
            while (rvalid !== 1'b1) begin
                @(negedge clk);
                cycles = cycles + 1;
                if (cycles > 100) $fatal(1,"AXI R timeout addr=%h",addr);
            end
            data = rdata;
            resp = rresp;
            repeat (2) begin
                @(posedge clk); #1;
                if (!rvalid || rdata !== data || rresp !== resp)
                    $fatal(1,"AXI read response not held while RREADY=0");
            end
            @(negedge clk); rready = 1;
            @(posedge clk);
            @(negedge clk); rready = 0;
        end
    endtask

    task expect_read;
        input [11:0] addr;
        input [31:0] exp_data;
        input [1:0] exp_resp;
        reg [31:0] d;
        reg [1:0] resp;
        begin
            axi_read(addr,d,resp);
            if (d !== exp_data || resp !== exp_resp) begin
                $display("FAIL AXI read addr=%h data=%h exp=%h resp=%b expresp=%b",
                    addr,d,exp_data,resp,exp_resp);
                errors = errors + 1;
            end
        end
    endtask

    task make_matrices;
        input integer which;
        integer tr, tc, tk;
        begin
            for (tr=0;tr<ROWS;tr=tr+1)
                for (tk=0;tk<K;tk=tk+1)
                    if (which==0) A[tr][tk] = tr*K + tk + 1;
                    else if (which==1)
                        A[tr][tk] = (((tr+tk)%2)==0) ? -(tr*K+tk+1) : (tr*K+tk+1);
                    else A[tr][tk] = 16'sd32767;
            for (tk=0;tk<K;tk=tk+1)
                for (tc=0;tc<COLS;tc=tc+1)
                    if (which==0) B[tk][tc] = 5 + tk*COLS + tc;
                    else if (which==1)
                        B[tk][tc] = (((tk+tc)%2)==0) ? (tk*COLS+tc+2) : -(tk*COLS+tc+2);
                    else B[tk][tc] = 16'sd32767;
        end
    endtask

    task run_case;
        input integer id;
        integer before_errors;
        reg [31:0] status;
        reg [1:0] rr;
        begin
            before_errors = errors;
            make_matrices(id);
            axi_write_expect('h000, 32'd2, 4'hf, 1, 2'b00); // LOAD_BEGIN, split AW/W
            axi_read('h004,status,rr);
            if (rr !== 2'b00 || status[1] !== 1'b0 || status[3] !== 1'b0) begin
                $display("FAIL LOAD_BEGIN status=%h resp=%b",status,rr);
                errors = errors+1;
            end
            for (q=0; q<K; q=q+1) begin
                axi_write_expect('h008, q, 4'hf, 2, 2'b00); // LOAD_INDEX, W before AW
                if (id==0 && q==0) begin
                    // Staging only one operand must not permit COMMIT.
                    axi_write_expect('h100, A[0][q],4'hf,0,2'b00);
                    axi_write_expect('h000,32'd4,4'hf,0,2'b10);
                end
                for (r=0;r<ROWS;r=r+1)
                    axi_write_expect('h100+4*r, A[r][q],4'hf,0,2'b00);
                for (c=0;c<COLS;c=c+1)
                    axi_write_expect('h140+4*c, B[q][c],4'hf,0,2'b00);
                axi_read('h004,status,rr);
                if (rr !== 2'b00 || status[5] !== 1'b1) begin
                    $display("FAIL staged word mask case=%0d q=%0d status=%h",id,q,status);
                    errors = errors+1;
                end
                axi_write_expect('h000,32'd4,4'hf,0,2'b00); // COMMIT bank beat
                axi_read('h004,status,rr);
                if (rr !== 2'b00 || status[5] !== 1'b0) begin
                    $display("FAIL staging mask not cleared after COMMIT case=%0d q=%0d",id,q);
                    errors=errors+1;
                end
            end
            axi_read('h004,status,rr);
            if (rr !== 2'b00 || status[1] !== 1'b1) begin
                $display("FAIL START_READY after full load case=%0d status=%h",id,status);
                errors=errors+1;
            end
            axi_write_expect('h000,32'd1,4'hf,0,2'b00); // START
            poll=0;
            status=0;
            while ((status[3] !== 1'b1) && (poll < 100)) begin
                axi_read('h004,status,rr);
                if (rr !== 2'b00) errors=errors+1;
                poll=poll+1;
            end
            if (status[3] !== 1'b1) begin
                $display("FAIL DONE timeout case=%0d",id);
                errors=errors+1;
            end
            // Read back every output element; the 512-bit bus is hidden behind AXI.
            for (r=0;r<ROWS;r=r+1)
                for (c=0;c<COLS;c=c+1) begin
                    expected = 32'sd0;
                    for (q=0;q<K;q=q+1) begin
                        product = A[r][q] * B[q][c];
                        expected = expected + product;
                    end
                    axi_read('h200 + 4*(r*COLS+c),value,rr);
                    if (rr !== 2'b00 || $signed(value) !== expected) begin
                        $display("FAIL result case=%0d C[%0d][%0d] got=%0d expected=%0d resp=%b",
                            id,r,c,$signed(value),expected,rr);
                        errors=errors+1;
                    end
                end
            // The pulse may be gone, but sticky DONE must remain set.
            repeat (2) @(posedge clk);
            axi_read('h004,status,rr);
            if (status[3] !== 1'b1 || rr !== 2'b00) begin
                $display("FAIL sticky DONE case=%0d status=%h",id,status);
                errors=errors+1;
            end
            if (errors == before_errors) begin
                tests_passed=tests_passed+1;
                $display("PASS Stage13 AXI4-Lite M=%0d K=%0d N=%0d case=%0d",ROWS,K,COLS,id);
            end
        end
    endtask

    initial begin
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        expect_read('h00c,{8'd0,K[7:0],COLS[7:0],ROWS[7:0]},2'b00);
        axi_write_expect('h000,32'd1,4'hf,0,2'b10); // START before LOAD
        axi_write_expect('h008,32'd255,4'hf,0,2'b10); // out of range
        axi_write_expect('h008,32'd0,4'b0011,0,2'b10); // partial WSTRB rejected
        axi_write_expect('h040,32'h12345678,4'hf,0,2'b10); // invalid address
        axi_read('h200,value,response);
        if (response !== 2'b10) begin
            $display("FAIL early result access must return SLVERR");
            errors=errors+1;
        end
        run_case(0);
        run_case(1);
        run_case(2);
        if (errors != 0)
            $fatal(1, "STAGE 13 FAILED M=%0d K=%0d N=%0d errors=%0d",
                ROWS,K,COLS,errors);
        $display("ALL STAGE 13 AXI4-LITE TESTS PASSED M=%0d K=%0d N=%0d cases=%0d",
            ROWS,K,COLS,tests_passed);
        $finish;
    end
    initial begin
        #5000000;
        $fatal(1,"Stage 13 AXI4-Lite simulation timeout");
    end
endmodule
