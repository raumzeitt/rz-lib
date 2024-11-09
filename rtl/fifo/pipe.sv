/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * CERN Open Hardware Licence Version 2 - Permissive
 *
 * Copyright (C) 2024 Robert Metchev
 *
 *
 * Description: Pipeline stage, either rigid, or bubble collapsing
 *
 */

module pipe #(
	parameter DW = 8,
	parameter RIGID = 0
)(
    input logic             clk,
    input logic             resetn,

    input logic             di_valid,
    input logic[DW-1:0]     di,
    output logic            di_hold,

    output logic            q_valid,
    output logic[DW-1:0]    q,
    input logic             q_hold
);

always_comb di_hold = q_hold & (q_valid | RIGID);

always @(posedge clk)
if (!resetn)
    q_valid <= 0;
else if (~di_hold)
    q_valid <= di_valid;

always @(posedge clk)
if (di_valid & ~di_hold)
    q <= di;

endmodule
