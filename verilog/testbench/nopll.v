// Simulate a PLL the simplest way possible

`timescale 1 ns / 1 ps
module clkgen (
  input wire CLKI,
  output wire CLKOP,
  output wire LOCK
);

assign CLKOP = CLKI;
assign LOCK = 1'b1;

endmodule
