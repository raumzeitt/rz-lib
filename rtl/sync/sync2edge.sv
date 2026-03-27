/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2026 Robert Metchev
 *
 *
 * Description: double synchronizer + edge detect
 *
 */

module sync2edge #(
    parameter D = 1
)(
    input logic clk,
    input logic rst_n,
    input logic[D-1:0] d,
    output logic[D-1:0] q,
    output logic[D-1:0] e
);
logic[2:0][D-1:0] q0;
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge rst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk)
`endif // RZ_LIB_ASYNC_RESETN
if(~rst_n)  q0 <= 0;
else        q0 <= {q0, d};
always_comb q = q0[1];
always_comb e = ~q0[2] & q0[1];
endmodule
