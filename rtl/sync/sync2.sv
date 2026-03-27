/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2026 Robert Metchev
 *
 *
 * Description: double synchronizer
 *
 */

module sync2 #(
    parameter D = 1
)(
    input logic clk,
    input logic rst_n,
    input logic[D-1:0] d,
    output logic[D-1:0] q
);
logic[D-1:0] q0;
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge rst_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk)
`endif // RZ_LIB_ASYNC_RESETN
if(~rst_n)  {q, q0} <= 0;
else        {q, q0} <= {q0, d};
endmodule
