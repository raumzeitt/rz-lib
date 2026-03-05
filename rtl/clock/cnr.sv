/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2026 Robert Metchev
 *
 *
 * Description: apb clock and reset block
 *
 */
module cnr #(
	parameter N = 5,
	parameter PA_W = $clog2(N+3), // paddr width
	parameter W = 10
)(
    input   logic           clk,
    input   logic           rst_n_in,
    output  logic           rst_n,          // synced with clk

    input   logic           pclk,           // feed back from 0 if needed
    input   logic           prst_n,         // feed back from 0 if needed

    input   logic           apb_psel,
    input   logic           apb_penable,
    input   logic           apb_pwrite,
    input   logic [PA_W+2-1:2] apb_paddr,
    input   logic [31:0]    apb_pwdata,
    output  logic [31:0]    apb_prdata,
    output  logic           apb_pready,

    input                   wake,

    output  logic[N-1:0]    clk_out,
    output  logic[N-1:0]    rst_n_out
);


logic                   apb_fifo_wfull, 
                        apb_fifo_rempty;
logic [PA_W+2-1:2]      paddr;
logic [31:0]            pwdata;
logic [N-1:0]           rst_status_i;
logic                   rst_status;
logic                   wake_sync;


// 1. synchronize reset
reset_sync reset_sync(
    .clock_in           (clk), 
    .async_reset_n_in   (rst_n_in),
    .sync_reset_n_out   (rst_n)
);

// 2. APB FIFO (assuming APB clock & reset are good)
always_comb  apb_pready = ~(apb_fifo_wfull & apb_pwrite);
afifo #(
    .ASIZE          (1), 
    .DSIZE          (PA_W + 32)
) apb_fifo (
    .i_wclk         (pclk), 
    .i_wrst_n       (prst_n), 
    .i_wr           (apb_psel & apb_pwrite & apb_penable), 
    .i_wdata        ({apb_paddr, apb_pwdata}), 
    .o_wfull        (apb_fifo_wfull),

    .i_rclk         (clk), 
    .i_rrst_n       (rst_n), 
    .i_rd           (1), 
    .o_rdata        ({paddr, pwdata}), 
    .o_rempty       (apb_fifo_rempty), 

    .wptr           (), 
    .rptr           ()
);

// 2a. APB out
always_comb     apb_pready = 1;
always_comb     apb_prdata = ({(N){(apb_paddr == N+1)}} & rst_status);
sync2 sync2_rst_status (.clk(pclk), .rst_n(prst_n), .d(|rst_status_i), .q(rst_status));

// 3. dummy wake logic = resets apb clock to super fast
sync2edge sync2edge_wake (.clk, .rst_n, .d(wake), .q(wake_sync));

genvar i;
generate
for (i = 0; i < N; i = i + 1) begin: cg
    logic           reset;
    logic [1:0]     en;
    logic [W-1:0]   r, n, p;
    logic [1:0]     clock_en;
    
    cnr_pregs #(.I(i), .N(N), .W(W)) cnr_pregs (
        .pclk           (clk), 
        .prst_n         (~(i == 0 & wake_sync) & rst_n), 
        .apb_psel       (~apb_fifo_rempty), 
        .apb_penable    (~apb_fifo_rempty), 
        .apb_pwrite     (~apb_fifo_rempty), 
        .apb_paddr      (paddr), 
        .apb_pwdata     (pwdata), 
        .apb_prdata     ( ), // not connected in order to save logic + synchronization + time + power
        .reset, 
        .en, 
        .r, 
        .n, 
        .p, 
        .*
    );

    // pre divider
    cnr_pre_divider cnr_pre_divider(
        .clk,
        .rst_n          (~(i == 0 & wake_sync) & rst_n), 
        .en             (en[0]), 
        .p,
        .clk_en_out     (clock_en[0])
    );

    // NR
    nr_divider #(.W(W)) nr_divider (
        .clk,
        .rst_n          (~(i == 0 & wake_sync) & rst_n),
        .clk_en_in      (~en[0] | clock_en[0]),
        .n,
        .r,
        .en             (en[1]),
        .clk_en_out     (clock_en[1])
    );
    clkgate clkgate(
        .i_clk (clk), 
        .i_en (en==3 ? &clock_en : en==2 ? clock_en[1] : en==1 ? clock_en[0] : 0),
		.o_clk (clk_out[i])
    );
    reset_sync reset_sync(
        .clock_in (clk_out[i]), 
        .async_reset_n_in ((i == 0 | ~reset) & rst_n),
		.sync_reset_n_out (rst_n_out[i])
    );

    always_comb rst_status_i[i] = |en & ~rst_n_out[i];
end
endgenerate
endmodule


module cnr_pregs #(
	parameter I = 0,
	parameter N = 5,
	parameter PA_W = $clog2(N+3), // paddr width
	parameter W = 10
)(
    input   logic           pclk,
    input   logic           prst_n,

    input   logic           apb_psel,
    input   logic           apb_penable,
    input   logic           apb_pwrite,
    input   logic [PA_W+2-1:2] apb_paddr,
    input   logic [31:0]    apb_pwdata,
    output  logic [31:0]    apb_prdata,
    
    output  logic [W-1:0]   r, n, p,
    output  logic           reset,
    output  logic [1:0]     en
);

`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge pclk or negedge prst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge pclk)
`endif // RZ_LIB_ASYNC_RESETN
if (!prst_n)
    reset <= 0;
else if (apb_pwrite & apb_psel & apb_penable & apb_paddr == N+2)
    reset <= I == 0 ? 0 : (apb_pwdata >> I);

`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge pclk or negedge prst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge pclk)
`endif // RZ_LIB_ASYNC_RESETN
if (!prst_n)
    en <= I == 0 ? 1 : 0;
else if (apb_pwrite & apb_psel & apb_penable & apb_paddr == N)
    en <= (I == 0 ? 1 : 0) | (apb_pwdata >> 2*I);

// APB clock cannot be turned off, just slowed down
//always_comb en = (I == 0 ? 1 : 0) | en_reg;

`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge pclk or negedge prst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge pclk)
`endif // RZ_LIB_ASYNC_RESETN
if (!prst_n)
    p <= I == 0 ? 1 : 'x;
else if (apb_pwrite & apb_psel & apb_penable & apb_paddr == I)
    p <= apb_pwdata;

always @(posedge pclk)
if (apb_pwrite & apb_psel & apb_penable & apb_paddr == I)
    {r, n} <= apb_pwdata >> W;

always_comb
    case(apb_paddr)
    I : apb_prdata = {r, n, p};
    N : apb_prdata = (en << 2*I);
    N+2 : apb_prdata = (reset << I);
    default: apb_prdata = 0;
    endcase

endmodule


module cnr_pre_divider #(
	parameter W = 10
)(
    input logic             clk,
    input logic             rst_n,

    input logic[W-1:0]      p,
    input logic             en,
    output logic            clk_en_out
);

logic [W-1:0]   c;

// pre divider
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge rst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk)
`endif // RZ_LIB_ASYNC_RESETN
if (!rst_n) begin
    c <= 1;
    clk_en_out <= 0;
end
else if (en) begin
    c <= (c==1) ? p : c - 1;
    clk_en_out <= (c==1);
end
endmodule
