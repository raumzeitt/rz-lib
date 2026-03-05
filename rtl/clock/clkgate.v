/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * GPL-3.0 license
 *
 * Copyright (C) 2026 Robert Metchev
 *
 *
 * Description: clock gate. 
 * Full credits: ZipCPU
 * https://zipcpu.com/blog/2021/10/26/clkgate.html
 *
 */
module clkgate( input wire i_clk, i_en,
		output wire o_clk);

	reg	latch;

	always @(*)
	if (!i_clk)
		latch = i_en;

	assign	o_clk = (latch)&&(i_clk);
endmodule
