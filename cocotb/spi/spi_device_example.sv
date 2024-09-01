module spi_device_example (
    // System clock + reset
    // input logic clock_in,        // clock not used
    input logic reset_n_in,

    // External SPI signals
    input logic spi_select_in,      // note: CS is active low
    input logic spi_clock_in,
    input logic spi_data_in,
    output logic spi_data_out
);

// To internal registers
logic [7:0] rd_data;
logic [7:0] address_out;
logic [31:0] rd_byte_count;
logic [31:0] wr_byte_count;
logic [7:0] wr_data;
logic data_rd_en;
logic data_wr_en;

spi spi(.*);

logic [7:0] regs[0:127];

// Write registers at falling edge of SPI clock
always @(negedge spi_clock_in)
if (data_wr_en & address_out<128)
    regs[(address_out + wr_byte_count) & 'h7f] <= wr_data;

// Read address = write address + 0x80
always_comb
    if (address_out<128)
        rd_data = 0;
    else
        rd_data = regs[(address_out + rd_byte_count) & 'h7f];

endmodule
