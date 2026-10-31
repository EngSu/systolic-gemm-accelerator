`timescale 1ns/1ps
// Stage 13 experimental AXI4-Lite register interface to Stage 11 banked OS GEMM.
// Intended for one shared clock, 32-bit data, 16-bit operands, 32-bit accumulators.
// All address offsets are byte addresses; memory map in docs/design/stage13_axi4lite.md.
// One outstanding write and one outstanding read; AW/W may arrive independently.
// No AXI4 bursts, no interrupts, no DMA. Full-word (WSTRB=4'hF) writes only.
module os_gemm_axi_lite_top #(
    parameter integer ROWS = 4,
    parameter integer COLS = 4,
    parameter integer K = 4,
    parameter integer AXI_ADDR_WIDTH = 12,
    parameter integer ADDR_WIDTH = (K <= 1) ? 1 : $clog2(K)
)(
    input  wire                         s_axi_aclk,
    input  wire                         s_axi_aresetn,
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [2:0]                   s_axi_awprot,
    input  wire                         s_axi_awvalid,
    output wire                         s_axi_awready,
    input  wire [31:0]                  s_axi_wdata,
    input  wire [3:0]                   s_axi_wstrb,
    input  wire                         s_axi_wvalid,
    output wire                         s_axi_wready,
    output reg  [1:0]                   s_axi_bresp,
    output reg                          s_axi_bvalid,
    input  wire                         s_axi_bready,
    input  wire [AXI_ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [2:0]                   s_axi_arprot,
    input  wire                         s_axi_arvalid,
    output wire                         s_axi_arready,
    output reg  [31:0]                  s_axi_rdata,
    output reg  [1:0]                   s_axi_rresp,
    output reg                          s_axi_rvalid,
    input  wire                         s_axi_rready
);
    localparam [1:0] RESP_OKAY = 2'b00, RESP_SLVERR = 2'b10;
    localparam integer COMMAND_ADDR   = 'h000;
    localparam integer STATUS_ADDR    = 'h004;
    localparam integer LOAD_INDEX_ADDR= 'h008;
    localparam integer CONFIG_ADDR    = 'h00c;
    localparam integer A_STAGE_BASE   = 'h100;
    localparam integer B_STAGE_BASE   = 'h140;
    localparam integer C_RESULT_BASE  = 'h200;

    // Reserve 0x100..0x13f for at most sixteen row registers,
    // and 0x140..0x17f for at most sixteen column registers.
    // Only supported configuration: 1<=ROWS,COLS<=16, 1<=K<=255.
    reg [ROWS*16-1:0] a_stage;
    reg [COLS*16-1:0] b_stage;
    reg [ROWS-1:0] a_stage_written;
    reg [COLS-1:0] b_stage_written;
    reg [ADDR_WIDTH-1:0] load_index;
    reg done_sticky;

    reg accel_start, accel_load_begin, accel_commit;
    wire load_ready, start_ready, busy, done;
    wire [ROWS*COLS*32-1:0] c_flat;

    os_gemm_banked_top #(.DATA_WIDTH(16), .ACC_WIDTH(32),
        .ROWS(ROWS), .COLS(COLS), .K(K)) u_accel (
        .clk(s_axi_aclk), .rst_n(s_axi_aresetn),
        .start(accel_start), .load_begin(accel_load_begin),
        .a_wr_en(accel_commit), .b_wr_en(accel_commit),
        .wr_addr(load_index), .a_wr_data_flat(a_stage),
        .b_wr_data_flat(b_stage),
        .load_ready(load_ready), .start_ready(start_ready),
        .busy(busy), .done(done), .c_flat(c_flat)
    );

    // Independent write address and data acceptance.
    reg [AXI_ADDR_WIDTH-1:0] awaddr_q;
    reg [31:0] wdata_q;
    reg [3:0] wstrb_q;
    reg aw_captured, w_captured;
    assign s_axi_awready = !aw_captured && !s_axi_bvalid;
    assign s_axi_wready  = !w_captured  && !s_axi_bvalid;
    wire execute_write = aw_captured && w_captured && !s_axi_bvalid;

    reg write_allowed;
    integer wi;
    always @* begin
        write_allowed = 1'b0;
        if ((awaddr_q[1:0] == 2'b00) && (wstrb_q == 4'hf)) begin
            if (awaddr_q == COMMAND_ADDR) begin
                case (wdata_q)
                    32'd0: write_allowed = 1'b1; // no-op
                    32'd1: write_allowed = start_ready; // START
                    32'd2: write_allowed = load_ready; // LOAD_BEGIN
                    32'd4: write_allowed = load_ready &&
                        (&a_stage_written) && (&b_stage_written) && (load_index < K); // COMMIT
                    default: write_allowed = 1'b0;
                endcase
            end else if (awaddr_q == LOAD_INDEX_ADDR) begin
                write_allowed = load_ready && (wdata_q < K);
            end else begin
                for (wi = 0; wi < ROWS; wi = wi + 1)
                    if (awaddr_q == (A_STAGE_BASE + 4*wi))
                        write_allowed = load_ready;
                for (wi = 0; wi < COLS; wi = wi + 1)
                    if (awaddr_q == (B_STAGE_BASE + 4*wi))
                        write_allowed = load_ready;
            end
        end
    end

    integer ri;
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            aw_captured <= 1'b0;
            w_captured <= 1'b0;
            awaddr_q <= {AXI_ADDR_WIDTH{1'b0}};
            wdata_q <= 32'd0;
            wstrb_q <= 4'd0;
            s_axi_bresp <= RESP_OKAY;
            s_axi_bvalid <= 1'b0;
            a_stage <= {ROWS*16{1'b0}};
            b_stage <= {COLS*16{1'b0}};
            a_stage_written <= {ROWS{1'b0}};
            b_stage_written <= {COLS{1'b0}};
            load_index <= {ADDR_WIDTH{1'b0}};
            accel_start <= 1'b0;
            accel_load_begin <= 1'b0;
            accel_commit <= 1'b0;
            done_sticky <= 1'b0;
        end else begin
            accel_start <= 1'b0;
            accel_load_begin <= 1'b0;
            accel_commit <= 1'b0;
            if (done)
                done_sticky <= 1'b1;

            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_q <= s_axi_awaddr;
                aw_captured <= 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                wdata_q <= s_axi_wdata;
                wstrb_q <= s_axi_wstrb;
                w_captured <= 1'b1;
            end
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (execute_write) begin
                aw_captured <= 1'b0;
                w_captured <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= write_allowed ? RESP_OKAY : RESP_SLVERR;
                if (write_allowed) begin
                    if (awaddr_q == COMMAND_ADDR) begin
                        if (wdata_q == 32'd1) begin
                            accel_start <= 1'b1;
                            done_sticky <= 1'b0;
                        end else if (wdata_q == 32'd2) begin
                            accel_load_begin <= 1'b1;
                            done_sticky <= 1'b0;
                            a_stage_written <= {ROWS{1'b0}};
                            b_stage_written <= {COLS{1'b0}};
                        end else if (wdata_q == 32'd4) begin
                            accel_commit <= 1'b1;
                            a_stage_written <= {ROWS{1'b0}};
                            b_stage_written <= {COLS{1'b0}};
                        end
                    end else if (awaddr_q == LOAD_INDEX_ADDR) begin
                        load_index <= wdata_q[ADDR_WIDTH-1:0];
                    end else begin
                        for (ri = 0; ri < ROWS; ri = ri + 1)
                            if (awaddr_q == (A_STAGE_BASE + 4*ri)) begin
                                a_stage[ri*16 +: 16] <= wdata_q[15:0];
                                a_stage_written[ri] <= 1'b1;
                            end
                        for (ri = 0; ri < COLS; ri = ri + 1)
                            if (awaddr_q == (B_STAGE_BASE + 4*ri)) begin
                                b_stage[ri*16 +: 16] <= wdata_q[15:0];
                                b_stage_written[ri] <= 1'b1;
                            end
                    end
                end
            end
        end
    end

    // Register the read response. One outstanding read; output held while stalled.
    assign s_axi_arready = !s_axi_rvalid;
    reg [31:0] read_data_comb;
    reg read_allowed;
    integer rr;
    always @* begin
        read_data_comb = 32'd0;
        read_allowed = 1'b0;
        if (s_axi_araddr[1:0] == 2'b00) begin
            if (s_axi_araddr == STATUS_ADDR) begin
                read_data_comb = {26'd0,
                    ((&a_stage_written) && (&b_stage_written)),
                    done, (done_sticky || done), busy, start_ready, load_ready};
                read_allowed = 1'b1;
            end else if (s_axi_araddr == CONFIG_ADDR) begin
                read_data_comb = {8'd0, K[7:0], COLS[7:0], ROWS[7:0]};
                read_allowed = 1'b1;
            end else if (s_axi_araddr == LOAD_INDEX_ADDR) begin
                read_data_comb = load_index;
                read_allowed = 1'b1;
            end else begin
                for (rr = 0; rr < ROWS; rr = rr + 1)
                    if (s_axi_araddr == (A_STAGE_BASE + 4*rr)) begin
                        read_data_comb = {{16{a_stage[rr*16+15]}}, a_stage[rr*16 +: 16]};
                        read_allowed = 1'b1;
                    end
                for (rr = 0; rr < COLS; rr = rr + 1)
                    if (s_axi_araddr == (B_STAGE_BASE + 4*rr)) begin
                        read_data_comb = {{16{b_stage[rr*16+15]}}, b_stage[rr*16 +: 16]};
                        read_allowed = 1'b1;
                    end
                for (rr = 0; rr < ROWS*COLS; rr = rr + 1)
                    if (s_axi_araddr == (C_RESULT_BASE + 4*rr)) begin
                        read_data_comb = c_flat[rr*32 +: 32];
                        read_allowed = (done_sticky || done) && !busy;
                    end
            end
        end
    end
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_rdata <= 32'd0;
            s_axi_rresp <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
        end else begin
            if (s_axi_rvalid && s_axi_rready)
                s_axi_rvalid <= 1'b0;
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata <= read_data_comb;
                s_axi_rresp <= read_allowed ? RESP_OKAY : RESP_SLVERR;
                s_axi_rvalid <= 1'b1;
            end
        end
    end
endmodule
