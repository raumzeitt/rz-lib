/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 *
 *
 * Description: A simple synchronous FIFO made of FFs
 *
 */

module sfifo #(
	parameter DW = 8,
	parameter DEPTH = 4,
	parameter AW = $clog2(DEPTH)
)(
    input logic             clk,
    input logic             resetn,

    input logic             we,
    input logic[DW-1:0]     wd,
    output logic            full,
    output logic[AW:0]      wptr,

    input logic             re,
    output logic[DW-1:0]    rd,
    output logic            empty,
    output logic[AW:0]      rptr
);
logic[DW-1:0]   mem[0:DEPTH-1];

// full/empty
always_comb full = wptr[AW] != rptr[AW] & wptr[AW-1:0] == rptr[AW-1:0];
always_comb empty = wptr == rptr;

// write/read pointers
`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge resetn)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk) //sync reset
`endif // RZ_LIB_ASYNC_RESETN
if (!resetn) wptr <= 0;
else if (we & ~full) wptr <= wptr + 1;

`ifdef RZ_LIB_ASYNC_RESETN
always @(posedge clk or negedge resetn)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge clk) //sync reset
`endif // RZ_LIB_ASYNC_RESETN
if (!resetn) rptr <= 0;
else if (re & ~empty) rptr <= rptr + 1;

// store write data
always @(posedge clk)
if (we & ~full) mem[wptr[AW-1:0]] <= wd;

// output read data
always_comb rd = mem[rptr[AW-1:0]];

endmodule
