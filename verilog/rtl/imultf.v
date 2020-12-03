// Iterative fractional multiplier                        11/30/2020 BNE
// This code is a gift to the divine.

// The versatility of fractional multiply is astounding. Algorithms can tune
// the operation to their needs by adjusting the number of iterations, trading
// precision for speed. A `sign` option allows either signed or unsigned
// operation. Unsigned supports `um*`.

// Compare to C, which gives you all the bits of precision, all the time.
// An iterative multiply there will cost you the maximum since you don't get to
// specify how many bits of precision you actually need.

// The chad CPU doesn't have +* due to the cost of multiplexers in FPGAs.
// Having extra muxes after the adder affects the critical path.

// a is signed or unsigned, b is unsigned with (bits-1) bits of precision.

`default_nettype none
module imultf
#(parameter WIDTH = 24
)(
  input wire                clk,
  input wire                arstn,      // async reset (active low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a multiplication
  input wire                sign,       // signed if 1, unsigned if 0
  input wire  [4:0]         bits,      	// bits of precision to use, less 1
  input wire  [WIDTH-1:0]   a, b,     	// multiplier inputs
  output wire [2*WIDTH-1:0] p      	// multiplier product
);

  reg [4:0] count;                      // enough for 32x32=64 multiply
  reg [WIDTH-1:0] m;                    // multiplicand
  reg [2*WIDTH-1:0] acc;                // accumulator
  reg sgn;                              // 1 = signed, 0 = unsigned

  wire [WIDTH:0] sum = {(acc[2*WIDTH-1] & sgn), acc[2*WIDTH-1:WIDTH]}
                     + {(m[WIDTH-1] & sgn), m};
  assign p = acc[2*WIDTH-1:0];

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    busy <= 1'b0;
  end else begin
    if (busy) begin
      acc <= (acc[0])
           ? {sum, acc[WIDTH-1:1]}
           : {(acc[2*WIDTH-1] & sgn),  acc[2*WIDTH-1:1]};
      if (count) count <= count - 1'b1;
      else busy <= 1'b0;
    end else begin
      if (go) begin
        busy <= 1'b1;
        sgn <= sign;
        count <= bits;
        acc <= b;
        m <= a;
      end
    end
  end

endmodule
