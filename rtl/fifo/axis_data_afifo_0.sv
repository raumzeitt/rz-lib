/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2025 Robert Metchev
 *
 *
 * Description: AXI-Stream async FIFO using inferrebale BRAM
 *
 */

// clogb2() - $clog2() alternative
//`include "clogb2.vh" 
module axis_data_afifo_0 #(
    parameter DEPTH = 8192,
    parameter DW = 24
)(
    input logic s_axis_aresetn,
    input logic s_axis_aclk,
    input logic s_axis_tvalid,
    output logic s_axis_tready,
    input logic[DW-1 : 0] s_axis_tdata,

    input logic m_axis_aresetn,
    input logic m_axis_aclk,
    output logic m_axis_tvalid,
    input logic m_axis_tready,
    output logic[DW-1 : 0] m_axis_tdata
    //output logic[31 : 0] axis_rd_data_count
);
localparam AW = $clog2(DEPTH);

//  1. FIFO - we are using just the control logic
logic empty, full;
logic pipe_di_hold;
logic [AW:0] waddr, raddr;

//always_comb axis_rd_data_count = waddr - raddr;
always_comb s_axis_tready = ~full;

//  1a. Dan's async FIFO
afifo #(.DSIZE(DW), .ASIZE(AW)) fifo(
    .i_wclk(s_axis_aclk),
    .i_wrst_n(s_axis_aresetn), 

    .i_rclk(m_axis_aclk),
    .i_rrst_n(m_axis_aresetn),

    .i_wr(s_axis_tvalid),
    .i_wdata('0),
    .o_wfull(full),
    .wptr(waddr),

    .i_rd(~pipe_di_hold),
    .o_rdata(),
    .o_rempty(empty),
    .rptr(raddr)
);

//  2. Inferable BRAM
dp_ram_be #(
    .DEPTH  (DEPTH), 
    .DW     (DW)
) ram (
    .wclk   (s_axis_aclk), // =clk for sync fifo
    .we     (s_axis_tvalid & s_axis_tready),
    .wa     (waddr[AW-1:0]),
    .wbe    ('1),
    .wd     (s_axis_tdata),

    .rclk   (m_axis_aclk), // =clk for sync fifo
    .re     (~empty & ~pipe_di_hold),
    .ra     (raddr[AW-1:0]),
    .rd     (m_axis_tdata)
);

//  3. m_axis_tvalid = delayed ~empty
pipe #(
    .DW         (DW)
) pipe (
    .clk        (m_axis_aclk), // =clk for sync fifo
    .resetn     (m_axis_aresetn), // =resetn for sync fifo

    .di_valid   (~empty),
    .di         ('0),
    .di_hold    (pipe_di_hold),

    .q_valid    (m_axis_tvalid),
    .q          (),
    .q_hold     (~m_axis_tready)
);

endmodule
