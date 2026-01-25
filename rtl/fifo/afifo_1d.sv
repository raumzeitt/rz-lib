/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2025 Robert Metchev
 *
 *
 * Description: 1-deep async FIFO
 *
 */

module afifo_1d #(
    parameter D=8
)(
    input   logic           we,
    output  logic           full,
    input   logic [D-1:0]   wd,
    input   logic           wclk,
    input   logic           wreset_n,
    
    input   logic           re,
    output  logic           empty,
    output  logic [D-1:0]   rd,
    input   logic           rclk,
    input   logic           rreset_n
);

logic wptr, rptr;
logic [1:0] wptr_sync, rptr_sync;

always_comb full = (wptr != rptr_sync[1]);
always_comb empty = (rptr == wptr_sync[1]);

always @(posedge wclk) if (we & ~full) rd <= wd;

 `ifdef RZ_LIB_ASYNC_RESETN
always @(posedge wclk or negedge wreset_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge wclk)
`endif // RZ_LIB_ASYNC_RESETN
if (!wreset_n) begin
    wptr <= 0;
    rptr_sync <= 0;
end
else begin
    if (we & ~full) wptr <= ~wptr;
    rptr_sync <= {rptr_sync, rptr};
end

 `ifdef RZ_LIB_ASYNC_RESETN
always @(posedge rclk or negedge rreset_n)
`else // RZ_LIB_ASYNC_RESETN
always @(posedge rclk)
`endif // RZ_LIB_ASYNC_RESETN
if (!rreset_n) begin
    rptr <= 0;
    wptr_sync <= 0;
end
else begin
    if (re & ~empty) rptr <= ~rptr;
    wptr_sync <= {wptr_sync, wptr};
end

endmodule
