// Iterative unsigned multiplier                        11/5/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module imultu
#(parameter WIDTH = 8
)(
  input wire                clk,
  input wire                arstn,      // async reset (active low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a multiplication
  input wire  [WIDTH-1:0]   a, b,     	// multiplier inputs
  output wire [2*WIDTH-1:0] p      	// multiplier product
);

  reg [4:0] count;                      // enough for 32x32=64 multiply
  reg [WIDTH-1:0] m;                    // multiplicand
  reg [2*WIDTH-1:0] acc;                // accumulator
  wire [2*WIDTH-1:0] next, sum;         // left-shifted acc, with m added
  wire adding;

  assign {adding, next} = {acc, 1'b0};
  assign sum = {next[2*WIDTH-1:WIDTH+1], next[WIDTH:0] + {1'b0, m}};
  assign p = acc;

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    busy <= 1'b0;
  end else begin
    if (busy) begin
      acc <= (adding) ? {sum} : {next};
      if (count) count <= count - 1'b1;
      else busy <= 1'b0;
    end else begin
      if (go) begin
        busy <= 1'b1;
        count <= WIDTH - 1;
        acc <= {a, {WIDTH{1'b0}}};
        m <= b;
      end
    end
  end

endmodule
