// Iterative shifter                        12/2/2020 BNE
// This code is a gift to Divine Mother and all of creation.

// Shifts are done in 6-bit chunks, then 1-bit steps to finish.
// The idea is to balance execution time with mux usage to use fewer
// FPGA resources yet have a reasonable execution time.

`default_nettype none
module ishift
#(parameter WIDTH = 16
)(
  input wire                clk,
  input wire                arstn,      // async reset (offset low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a shift
  input wire  [1:0]         fmt,     	// 2-bit shift format
  input wire  [5:0]         cnt,     	// 6-bit shift coount
  input wire  [WIDTH-1:0]   a,     	// shifter in
  output reg  [WIDTH-1:0]   y     	// shifter out
);

// formats:
// 00 = logical right shift
// x1 = left shift
// 10 = arithmetic right shift

  reg [1:0] format;
  wire msb = (format[1]) ? y[WIDTH-1] : 1'b0;
  reg [5:0] remaining;

  reg [1:0] mode;                       // shift type: /2, /64, *2, *64
  always @* begin
    if (remaining > 5)
      mode <= {format[0], 1'b1};
    else
      mode <= {format[0], 1'b0};
  end

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    busy <= 1'b0;
    remaining <= 6'b0;
  end else begin
    if (remaining) begin
      case (mode)
      2'b00: y <= {msb, y[WIDTH-1:1]};
      2'b01: y <= {{6{msb}}, y[WIDTH-1:6]};
      2'b10: y <= {y[WIDTH-2:0], 1'b0};
      2'b11: y <= {y[WIDTH-7:0], 6'b0};
      endcase
      remaining <= remaining - ((mode[0]) ? 6'd6 : 6'd1);
    end else begin
      if (go) begin
        y <= a;
        format <= fmt;
        if (cnt) begin
          busy <= 1'b1;
          remaining <= cnt;
        end
      end else
        busy <= 1'b0;
    end
  end

endmodule
