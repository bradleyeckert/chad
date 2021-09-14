// Clock domain crossing with glitch removal                11/6/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

// This module is used to bring asynchronous signals into a clock domain.
// It allows for metastable behavior in the first couple of flops, including
// metastability that doesn't settle within one clock cycle on both.
// The `a` signal can be up to CLK/6 before the glitch filter impacts it.

`default_nettype none
module cdc
(
  input wire  clk,
  input wire  a,
  output reg  y                         // propagation delay: 3 to 4 beats
);

// B[3] and B[2] are not trusted. B[1] and B[0] are used to trigger the glitch timer.
// The glitch timer provides two beats to shift B[1] into the bit bucket.
// B[3:2] could be built with metastable-hardened flops for even more reliability.

  reg [3:0] b;                          // multi-flop delay shift register
  reg [1:0] c;                          // one-hot-coded glitch timer

  always @(posedge clk) begin
    b <= {a, b[3:1]};                   // a -> bbbb (right-shift)
    if (c)                              // filtering
      c <= {1'b0, c[1]};                // right-shift c
    else begin
      y <= b[1];
      if (b[1] != b[0])
        c <= 2'b11;                     // start glitch filter
    end
  end

endmodule
`default_nettype wire
