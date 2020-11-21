// Iterative shifter                        11/6/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module ishift
#(parameter WIDTH = 16
)(
  input wire                clk,
  input wire                arstn,      // async reset (active low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a shift
  input wire  [1:0]         fmt,     	// 2-bit shift format
  input wire  [5:0]         cnt,     	// 5-bit shift count
  input wire  [WIDTH-1:0]   a,     	// shifter in
  output reg  [WIDTH-1:0]   y     	// shifter out
);

// formats:
// 00 = logical right shift
// x1 = left shift
// 10 = arithmetic right shift

  wire msb = (fmt[1]) ? y[WIDTH-1] : 1'b0;
  reg [5:0] count;

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    busy <= 1'b0;
  end else begin
    if (busy) begin
      y <= (fmt[0]) ? {y[WIDTH-2:0], 1'b0} : {msb, y[WIDTH-1:1]};
      if (count) count <= count - 1'b1;
      else busy <= 1'b0;
    end else begin
      if (go) begin
        y <= a;
        if (cnt) begin
          busy <= 1'b1;
          count <= cnt - 1'b1;
        end
      end
    end
  end

endmodule
