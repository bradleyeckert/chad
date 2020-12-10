// Iterative shifter                        12/3/2020 BNE
// This code is a gift to Divine Mother and all of creation.

// Shifts are done in 6-bit chunks, then 1-bit steps to finish.
// The idea is to balance execution time with mux usage to use fewer
// FPGA resources yet have a reasonable execution time.

module ishift
#(parameter WIDTH = 32                  // should be 32 to 64
)(
  input wire                clk,
  input wire                arstn,      // async reset (offset low)
  output reg                busy,     	// 0 = ready, 1 = busy
  input wire                go,        	// trigger a shift
  input wire  [2:0]         fmt,     	// 3-bit shift format
  input wire  [5:0]         cnt,     	// 6-bit shift coount
  input wire  [WIDTH-1:0]   a,     	// shifter in
  output reg  [WIDTH-1:0]   y     	// shifter out
);

// formats:
// 000 = logical right shift
// 0x1 = left shift
// 010 = arithmetic right shift
// 1xx = rotate right, 32-bit (for SHA)

  reg [2:0] format;
  wire msb = (format[1]) ? y[WIDTH-1] : 1'b0;
  reg [5:0] remaining;

  reg [2:0] mode;                       // shift type: /2, /64, *2, *64
  always @* begin
    if (remaining > 5)                  // 001 = >>6; 011 = <<6, 1x1 = ror 6
      mode <= {format[2], format[0], 1'b1};
    else if (go)
      mode <= 3'b100;                   // 100 = a
    else if (format[2])
      mode <= 3'b110;                   // 110 = ror 1
    else
      mode <= {1'b0, format[0], 1'b0};  // 000 = >>1; 010 = <<1
  end

  wire [31:0] ror1 = {y[0], y[31:1]};   // rotate right lower 32 bits
  wire [31:0] ror6 = {y[5:0], y[31:6]};

  wire load = (remaining) ? 1'b1 : go;  // clock in a new y value
  always @(posedge clk)
    if (load) begin
      case (mode)
      3'b000: y <= {msb, y[WIDTH-1:1]};
      3'b001: y <= {{6{msb}}, y[WIDTH-1:6]};
      3'b010: y <= {y[WIDTH-2:0], 1'b0};
      3'b011: y <= {y[WIDTH-7:0], 6'b0};
      3'b100: y <= a;
      3'b110: y <= ror1;
      3'b111, 3'b101: y <= ror6;
      endcase
    end

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    busy <= 1'b0;
    remaining <= 6'b0;
  end else begin
    if (remaining) begin
      remaining <= remaining - ((mode[0]) ? 6'd6 : 6'd1);
    end else begin
      if (go) begin
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
