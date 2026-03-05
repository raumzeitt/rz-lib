/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2026 Robert Metchev
 *
 *
 * Description: NR divider
 *
 */
module nr_divider #(
	parameter W = 10
)(
    input logic             clk,
    input logic             clk_en_in,
    input logic             rst_n,

    input logic[W-1:0]      n,
    input logic[W-1:0]      r,
    input logic             en,
    output logic            clk_en_out
);

logic [W-1:0]   c;
logic [W-1:0]   s;
logic [W:0]     t;

always_comb s = c + n;
always_comb t = c + n - r;

`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge rst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk)
`endif // RZ_LIB_ASYNC_RESETN
if (!rst_n) begin
    c <= 0;
    clk_en_out <= 0;
end
else if (en & clk_en_in) begin
    c <= t[W] ? s : t;
    clk_en_out <= ~t[W];
end
endmodule
