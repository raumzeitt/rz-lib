module spi (
    // System clock + reset
    // input logic clock_in,        // clock not used
    input logic reset_n_in,

    // External SPI signals
    input logic spi_select_in,      // note: CS is active low
    input logic spi_clock_in,
    input logic spi_data_in,
    output logic spi_data_out,
    
    // To internal registers
    input logic [7:0] rd_data,
    output logic [7:0] address_out,
    output logic [31:0] rd_byte_count,
    output logic [31:0] wr_byte_count,
    output logic [7:0] wr_data,
    output logic data_rd_en,
    output logic data_wr_en
);

logic                   spi_resetn;
logic [3:0]             bit_index;
logic [8:0]             shift_reg;

always_comb  spi_resetn = reset_n_in & ~spi_select_in; // local reset
always_comb  wr_data = shift_reg;

// At rising edge of SPI clock keep track data bytes and bits within the data
always_ff @(posedge spi_clock_in or negedge spi_resetn)
if (!spi_resetn) begin
    bit_index <= 15;
    rd_byte_count <= 0;
    wr_byte_count <= 0;
    data_wr_en <= 0;
    data_rd_en <= 0;
end else begin
    // Roll underflows back over to read multiple bytes continiously
    if (bit_index == 0) begin
        bit_index <= 7;
        rd_byte_count <= rd_byte_count + 1;
    end
    else
        bit_index <= bit_index - 1;
    data_wr_en <= bit_index == 0;
    data_rd_en <= bit_index == 1;
    if(data_wr_en)
        wr_byte_count <= rd_byte_count;
end

// At falling edge of SPI clock, shift out read data
always @(negedge spi_clock_in or negedge spi_resetn)
if (!spi_resetn)
    spi_data_out <= 0;
else if (bit_index == 7)
    spi_data_out <= rd_data[7];
else  if (~bit_index[3])  
    spi_data_out <= shift_reg[7];
    
// At rising edge of SPI clock, shift in address/data phases    
always_ff @(posedge spi_clock_in)
if (bit_index[3]) 
    address_out <= {address_out, spi_data_in};
else if (bit_index == 7)
    shift_reg <= {rd_data, spi_data_in};
else
    shift_reg <= {shift_reg, spi_data_in};

endmodule
