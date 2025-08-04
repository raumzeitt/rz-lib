`timescale 1ns / 1ps
/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2024 Robert Metchev
 *
 *
 * Description:
 * Modified/redesigned 
 * https://github.com/raumzeitt/Tiny_But_Mighty_I2C_Master_Verilog/blob/main/rtl/i2c_master.sv
 * to support arbitrary read/write sizes
 *
 */
//////////////////////////////////////////////////////////////////////////////////
// Company:  www.circuitden.com
// Engineer: Artin Isagholian
//           artinisagholian@gmail.com
// 
// Create Date: 01/20/2021 05:47:22 PM
// Design Name: 
// Module Name: i2c_master
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: cycle_timer.sv
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module rz_i2c_master #(
    parameter integer unsigned CHECK_FOR_CLOCK_STRETCHING   = 1,    //set to non zero value to enable
    parameter integer unsigned CLOCK_STRETCHING_MAX_COUNT   = 'h1F, //set to 0 to disable, max number of divider ticks to wait during stretch check
    parameter integer unsigned CMD_FIFO_DEPTH = 2,
    parameter integer unsigned MISO_FIFO_DEPTH = 2,
    parameter integer unsigned MOSI_FIFO_DEPTH = 2
)(
    input   logic               clock,
    input   logic               reset_n,

    // Command interface
    // AXI-Stream command input (1 word = command)
    input   logic               s_axis_cmd_tvalid,   // was enable
    output  logic               s_axis_cmd_tready,   // was busy
    input   logic [23:0]        s_axis_cmd_tdata,    // [23:17] device_addr, [16] read_write (1 = read, 0 = write), [15:8] num_bytes, [7:0] register_addr

    // Write stream interface
    // AXI-Stream write data input
    input   logic               s_axis_data_tvalid,
    output  logic               s_axis_data_tready,
    input   logic [7:0]         s_axis_data_tdata,

    // Read stream interface
    // AXI-Stream read data output
    output  logic               m_axis_data_tvalid,
    input   logic               m_axis_data_tready,
    output  logic [7:0]         m_axis_data_tdata,
    

    input   logic   [15:0]      divider,

    input   logic               sda_in,
    output  logic               sda_out,
    input   logic               scl_in,
    output  logic               scl_out
);

// synchronize SDA/SCL
logic   sda;
logic   scl;

// FIFOs
logic               s_axis_cmd_tready_n;
logic               cmd_valid_n;
logic               cmd_valid;
logic               cmd_ready;
logic   [23:0]      cmd_data;

logic               s_axis_data_tready_n;
logic               mosi_valid_n;
logic               mosi_valid;
logic               mosi_ready;
logic   [7:0]       mosi_data;

logic               m_axis_data_tvalid_n;
logic               miso_ready_n;
logic               miso_valid;
logic               miso_ready;
logic   [7:0]       miso_data;

// Assign the packed input to typedef
typedef struct packed {
    logic [6:0]  device_address;    // 7-bit I2C address
    logic        read_write;        // 1 = read, 0 = write
    logic [7:0]  num_bytes;         // number of data bytes (after 1-byte register)
    logic [7:0]  register_address;  // register address to access
} i2c_cmd_t;

i2c_cmd_t cmd;
always_comb cmd = cmd_data;

// state
typedef enum
{
    S_IDLE,
    S_START,
    S_WRITE_ADDR_W,
    S_CHECK_ACK,
    S_WRITE_REG_ADDR,
    S_RESTART,
    S_WRITE_ADDR_R,
    S_READ_REG,
    S_SEND_NACK,
    S_SEND_STOP,
    S_WRITE_REG_DATA,
    S_SEND_ACK
} state_t;

state_t             state, next_state;
state_t             post_state, next_post_state;
logic   [1:0]       process_counter, next_process_counter;
logic   [2:0]       bit_counter, next_bit_counter;
logic               last_acknowledge, next_last_acknowledge;
logic   [7:0]       byte_counter, next_byte_counter;

logic               next_sda_out;
logic               next_scl_out;

logic   [15:0]      divider_counter, next_divider_counter;
logic               divider_tick;
logic               timeout_cycle_timer_expired;


// synchronize SDA/SCL
//logic sda_in_z, scl_in_z;
//always @(posedge clock) {sda, sda_in_z} <= {sda_in_z, sda_in};
//always @(posedge clock) {scl, scl_in_z} <= {scl_in_z, scl_in};
always_comb sda = sda_in;
always_comb scl = scl_in;

// FIFOs
always_comb s_axis_cmd_tready   = ~s_axis_cmd_tready_n;
always_comb cmd_valid           = ~cmd_valid_n;
always_comb s_axis_data_tready  = ~s_axis_data_tready_n;
always_comb mosi_valid          = ~mosi_valid_n;
always_comb m_axis_data_tvalid  = ~m_axis_data_tvalid_n;
always_comb miso_ready          = ~miso_ready_n;

sfifo 
    #(.DW(24), .DEPTH(CMD_FIFO_DEPTH))
cmd_fifo (
    .clk(clock), .resetn(reset_n), .rptr(), .wptr(),
    .we(s_axis_cmd_tvalid), .wd(s_axis_cmd_tdata), .full(s_axis_cmd_tready_n), 
    .re(cmd_ready), .rd(cmd_data), .empty(cmd_valid_n)
);

sfifo 
    #(.DW(8), .DEPTH(MOSI_FIFO_DEPTH))
mosi_fifo (
    .clk(clock), .resetn(reset_n), .rptr(), .wptr(),
    .we(s_axis_data_tvalid), .wd(s_axis_data_tdata), .full(s_axis_data_tready_n), 
    .re(mosi_valid), .rd(mosi_data), .empty(mosi_valid_n)
);

sfifo 
    #(.DW(8), .DEPTH(MISO_FIFO_DEPTH))
miso_fifo (
    .clk(clock), .resetn(reset_n), .rptr(), .wptr(),
    .we(miso_valid), .wd(miso_data), .full(miso_ready_n), 
    .re(m_axis_data_tready), .rd(m_axis_data_tdata), .empty(m_axis_data_tvalid_n)
);

cycle_timer #(
    .BIT_WIDTH  ($clog2(CLOCK_STRETCHING_MAX_COUNT))
) cycle_timer (
    .clock      (clock),
    .reset_n    (reset_n),
    .enable     (CHECK_FOR_CLOCK_STRETCHING & CLOCK_STRETCHING_MAX_COUNT != 0 & divider_tick),
    .load_count (process_counter == 0),
    .count      (CLOCK_STRETCHING_MAX_COUNT),

    .expired    (timeout_cycle_timer_expired)
);

// Divider for clock
always_comb begin
    next_divider_counter = divider_counter;
    if (state != S_IDLE | cmd_valid)
        if (divider_tick)
            next_divider_counter = divider - 1;
        else
            next_divider_counter = divider_counter - 1;
end
always_comb divider_tick = (divider_counter == 0) ;
// assert never cmd_ready & divider_tick

always_ff @(posedge clock or negedge reset_n)
if (!reset_n)
    divider_counter <= 0;
else
    divider_counter <= next_divider_counter;

// Stream control signals
always_comb cmd_ready = (state != S_IDLE) & (next_state == S_IDLE);
always_comb mosi_ready = divider_tick && (state == S_WRITE_REG_DATA) && (process_counter == 3) && (bit_counter == 0);
always_ff @(posedge clock or negedge reset_n)
if (!reset_n) 
    miso_valid   <= 0;
else
    if (divider_tick && (state == S_READ_REG) && (process_counter == 2) && (bit_counter == 0)) 
        miso_valid   <= 1;
    else if (miso_ready) 
        miso_valid   <= 0;

// workaround icarus static cast issues:  state_t'(S_X);
//wire [$bits(state_t)-1:0] S_X;
//assign S_X = 'x;

always_ff @(posedge clock or negedge reset_n)
if (!reset_n) begin
    state   <= S_IDLE;
    sda_out   <= 1;
    scl_out   <= 1;
end else begin
    state   <= next_state;
    sda_out   <= next_sda_out;
    scl_out   <= next_scl_out;
end

always_ff @(posedge clock) begin
    post_state <= next_post_state;
    process_counter <= next_process_counter;
    bit_counter <= next_bit_counter;
    byte_counter <= next_byte_counter;
    last_acknowledge <= next_last_acknowledge;
end

always_comb begin
    next_state   = state;
    next_sda_out   = sda_out;
    next_scl_out   = scl_out;
    
    next_post_state = post_state;
    next_process_counter = process_counter;
    next_bit_counter = bit_counter;
    next_byte_counter = byte_counter;

    if (divider_tick) begin // aggressive gating
        next_process_counter = process_counter + 1;
        case (state)

            S_IDLE: if (cmd_valid)
                        next_state = S_START;

            S_START:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  next_sda_out = 0;
                    2:  next_scl_out = 0;
                    3:  begin
                            next_sda_out = cmd.device_address[6];
                            next_bit_counter = 7;
                            next_state = S_WRITE_ADDR_W;
                        end
                endcase

            S_WRITE_ADDR_W, S_WRITE_ADDR_R:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING &  CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_sda_out = 1;
                            next_state = S_IDLE;
                        end 
                    2:  next_scl_out = 0;
                    3:  begin
                            next_bit_counter = bit_counter - 1;
                            if (bit_counter == 0) begin
                                next_sda_out = 1;
                                next_state = S_CHECK_ACK;
                                next_post_state = state==S_WRITE_ADDR_W ? S_WRITE_REG_ADDR : S_READ_REG;
                            end
                            else if (bit_counter == 1)
                                next_sda_out = state==S_WRITE_ADDR_R; //cmd.read_write; // 1 = read, 0 = write
                            else
                                next_sda_out = cmd.device_address >> (bit_counter - 2);
                    end
                endcase

            S_CHECK_ACK:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING &  CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_sda_out = 1;
                            next_state = S_IDLE;
                        end
                    2:  begin 
                            next_scl_out = 0;
                            next_last_acknowledge = sda;
                        end
                    3:  if (last_acknowledge | post_state == S_SEND_STOP) begin
                            next_sda_out = 0;
                            next_state = S_SEND_STOP;
                        end else if (post_state == S_RESTART | post_state == S_READ_REG) begin
                            next_sda_out = 1;
                            next_state = post_state;
                        end else if (post_state == S_WRITE_REG_ADDR) begin
                            next_sda_out = cmd.register_address[7];
                            next_state = post_state;
                        end else if (post_state == S_WRITE_REG_DATA)
                            if (mosi_valid) begin
                                next_sda_out = mosi_data[7];
                                next_state = post_state;
                            end
                endcase

            S_WRITE_REG_ADDR:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING &  CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_sda_out = 1;
                            next_state = S_IDLE;
                        end 
                    2:  next_scl_out = 0;
                    3:  begin
                            next_bit_counter = bit_counter - 1;
                            if (bit_counter == 0) begin
                                next_sda_out = 1;
                                next_state = S_CHECK_ACK;
                                if (cmd.read_write)
                                    next_post_state = S_RESTART; // 1 = read, 0 = write
                                else
                                    next_post_state = S_WRITE_REG_DATA; // 1 = read, 0 = write
                                next_byte_counter = cmd.num_bytes - 1;
                            end
                            else
                                next_sda_out = cmd.register_address >> (bit_counter - 1);
                        end
                endcase

            S_WRITE_REG_DATA:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING &  CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_sda_out = 1;
                            next_state = S_IDLE;
                        end 
                    2:  next_scl_out = 0;
                    3:  begin
                            next_bit_counter = bit_counter - 1;
                            if (bit_counter == 0) begin
                                next_sda_out = 1;
                                next_state = S_CHECK_ACK;
                                if (byte_counter == 0)
                                    next_post_state = S_SEND_STOP;
                                else
                                    next_post_state = S_WRITE_REG_DATA;
                                if (byte_counter != 0)
                                    next_byte_counter = byte_counter - 1;
                            end
                            else
                                next_sda_out = mosi_data[bit_counter - 1];
                    end
                endcase

            S_RESTART:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  next_sda_out = 0;
                    2:  next_scl_out = 0;
                    3:  begin
                            next_sda_out = cmd.device_address[6];
                            next_bit_counter = 7;
                            next_state = S_WRITE_ADDR_R;
                        end
                endcase

            S_READ_REG:
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING &  CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_sda_out = 1;
                            next_state = S_IDLE;
                        end 
                    2:  begin 
                            next_scl_out = 0;
                            miso_data[bit_counter] = ~sda;
                        end
                    3:  if (bit_counter != 0 | (!miso_valid | miso_ready)) begin //FIXME handhake
                            next_bit_counter = bit_counter - 1;
                            if (bit_counter == 0) begin
                                next_post_state = S_READ_REG;
                                if (byte_counter != 0) begin
                                    next_sda_out = 0;
                                    next_byte_counter = byte_counter - 1;
                                    next_state = S_SEND_ACK;
                                end else begin
                                    next_sda_out = 1;
                                    next_state = S_SEND_NACK;
                                end
                            end
                        end
                endcase

            S_SEND_ACK, S_SEND_NACK: 
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (~scl & CHECK_FOR_CLOCK_STRETCHING & CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired) begin //check for clock stretching
                            next_state = S_IDLE;
                            next_sda_out = 1;
                        end
                    2:  next_scl_out = 0;
                    3:  if (state==S_SEND_ACK) begin
                            next_sda_out = 1;
                            next_state = S_READ_REG;
                        end else begin
                            next_sda_out = 0;
                            next_state = S_SEND_STOP;
                        end
                endcase

            S_SEND_STOP:  
                case (process_counter)
                    0:  next_scl_out = 1;
                    1:  if (scl | !CHECK_FOR_CLOCK_STRETCHING)
                            next_sda_out = 1;
                        //check for clock stretching
                        else if (CLOCK_STRETCHING_MAX_COUNT != 0 & timeout_cycle_timer_expired)
                            next_state = S_IDLE;
                    //2: ;
                    3:  next_state = S_IDLE;
                endcase
        endcase   
    end
end

endmodule
