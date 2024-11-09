/*
 * Authored by: Robert Metchev / Raumzeit Technologies (robert@raumzeit.co)
 *
 * CERN Open Hardware Licence Version 2 - Permissive
 *
 * Copyright (C) 2024 Robert Metchev
 *
 *
 * Description: Ceil(log2()) function in verilog , same as $clog2()
 *
 */

`ifndef __CLOGB2_VH__
`define __CLOGB2_VH__

function automatic integer clogb2;
input integer d;
integer i, x;
begin
  x = 1;
  for (i=0; x<d; i=i+1)
    x = x << 1;
  clogb2 = ((d==1) | (d==0)) ? 1 : i;
end
endfunction

`endif //__CLOGB2_VH__
