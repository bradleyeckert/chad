// Iterative unsigned divider                                   11/5/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

module idivu
#(parameter WIDTH = 8
)(
  input wire                clk,
  input wire                arstn,      // async reset (active low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a division
  input wire [2*WIDTH-1:0]  dividend,
  input wire   [WIDTH-1:0]  divisor,
  output reg   [WIDTH-1:0]  quot,
  output reg   [WIDTH-1:0]  rem,
  output reg                overflow
);

  reg [4:0] count;                      // enough for 64/32=32 divide

  wire [WIDTH:0] diff = {1'b0, rem[WIDTH-2:0], quot[WIDTH-1]} - {1'b0, divisor};
  wire subtract = ~diff[WIDTH] | rem[WIDTH-1];

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    {busy, overflow} <= 1'b0;
    {rem, quot, count} <= 1'b0;         // optional reset
  end else begin
    if (busy) begin
      if (subtract)
        {rem, quot} <= {diff[WIDTH-1:0], quot[WIDTH-2:0], 1'b1};
      else
        {rem, quot} <= {rem[WIDTH-2:0], quot, 1'b0};
      if (count)
        count <= count - 1'b1;
      else
        busy <= 1'b0;
    end else
      if (go) begin
        if (dividend[2*WIDTH-1:WIDTH] >= divisor) begin
          {rem, quot} <= {2*WIDTH{1'b1}};
          overflow <= 1'b1;
        end else begin
          {busy, overflow} <= 2'b10;
          {rem, quot} <= dividend;
          count <= WIDTH - 1;
        end
      end
  end

endmodule
