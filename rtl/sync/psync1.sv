/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 *
 *
 * Description:
 * One-way pulse synchronizer for single isolated pulses, ie. no handshake/ack
 * assuming many clock cycles between pulses, either clock domain
 *
 */

module psync1 (
    input logic     in,
    input logic     in_clk,
    input logic     in_reset_n,
    output logic    out,
    input logic     out_clk,
    input logic     out_reset_n
);

logic p;
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge in_clk or negedge in_reset_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge in_clk)
`endif // RZ_LIB_ASYNC_RESETN
if (!in_reset_n) p <= 0;
else if (in) p <= ~p;

logic [2:0] p_cdc;
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge out_clk or negedge out_reset_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge out_clk)
`endif // RZ_LIB_ASYNC_RESETN
if (!out_reset_n) p_cdc <= 0;
else p_cdc <= {p_cdc, p};

always_comb out = ^p_cdc[2:1];

endmodule
