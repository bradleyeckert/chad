// Stack definition from J1 family
// Made from shift registers

module stack
#(
  parameter WIDTH = 18,
  parameter DEPTH = 16
)
(
  input wire  clk,
  input wire  hold,
  output wire [WIDTH-1:0] rd,
  input wire  we,
  input wire  [1:0] delta,
  input wire  [WIDTH-1:0] wd
);

  localparam BITS = (WIDTH * DEPTH) - 1;
  localparam EMPTY = 32'h55AA55AA;
  wire move = delta[0];

  reg  [WIDTH-1:0] head;
  reg  [BITS:0] tail;
  wire [WIDTH-1:0] headN;
  wire [BITS:0] tailN;

  assign headN = we ? wd : tail[WIDTH-1:0];
  assign tailN = delta[1] ?
    {EMPTY[WIDTH-1:0], tail[BITS:WIDTH]} :
    {tail[BITS-WIDTH:0], head};

  always @(posedge clk)
    if (!hold) begin
      if (we | move)  head <= headN;
      if (move)       tail <= tailN;
    end

  assign rd = head;

endmodule
