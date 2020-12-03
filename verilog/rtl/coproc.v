// Coprocessor for Chad processor               12/2/2020 BNE
// This code is a gift to Divine Mother and all of creation.

`include "options.vh"

module coproc
#(
  parameter WIDTH = 16
)
(
  input wire  clk,
  input wire  arstn,
  input wire  [10:0] sel,
  input wire  go,
  output reg  [WIDTH-1:0] y,
  input wire  [WIDTH-1:0] a,            // tos
  input wire  [WIDTH-1:0] b,            // nos
  input wire  [WIDTH-1:0] c             // w
);

  wire mbusy, dbusy, sbusy;
  wire mtrig = go & (sel[4:1] == 4'h9); // SBBBBB1001x
  wire dtrig = go & (sel[4:1] == 4'hA); // xxxxxx1010x
  wire strig = go & (sel[4:1] == 4'hB); // xxxxSL1011x

`ifdef OPTIONS_IMULT
    wire [2*WIDTH-1:0] mprod;
    imultf #(WIDTH) u0 (                // iterative fractional multiply
      .clk      (clk),
      .arstn    (arstn),
      .busy     (mbusy),
      .go	(mtrig),
      .sign     (sel[10]),
      .bits     (sel[9:5]),
      .a        (a),
      .b        (b),
      .p        (mprod)
    );
`else
    localparam mprod = 0;
`endif

`ifdef OPTIONS_IDIV
    wire overflow;
    wire [WIDTH-1:0] quot, rem;
    idivu #(WIDTH) u1 (                   // iterative divide
      .clk      (clk),
      .arstn    (arstn),
      .busy     (dbusy),
      .go       (dtrig),
      .dividend ({a,b}),
      .divisor  (c),
      .quot     (quot),
      .rem      (rem),
      .overflow (overflow)
    );
`else
    localparam quot = 0;
    localparam rem = 0;
    localparam overflow = 0;
`endif

`ifdef OPTIONS_ISHIFT
    wire [2*WIDTH-1:0] shifter;
    ishift #(2*WIDTH) u2 (                // iterative shift
      .clk      (clk),
      .arstn    (arstn),
      .busy     (sbusy),
      .go       (strig),
      .fmt      (sel[6:5]),
      .cnt      (c[5:0]),
      .a        ({a,b}),
      .y        (shifter)
  );
`else
    localparam shifter = 0;
`endif

  reg  [3:0] sticky;
  wire [3:0] outsel = (go) ? sel[3:0] : sticky;
  wire [7:0] options = `OPTIONS_COP;

  always @(posedge clk or negedge arstn)
  if (!arstn)
    y <= 1'b0;
  else begin
    if (go) sticky <= sel[3:0];
    case (outsel)
    4'h0:    y <= mbusy | dbusy | sbusy;
    4'h1:    y <= {overflow, options};
    4'h2:    y <= mprod[2*WIDTH-1:WIDTH];
    4'h3:    y <= mprod[WIDTH-1:0];
    4'h4:    y <= quot;
    4'h5:    y <= rem;
    4'h6:    y <= shifter[2*WIDTH-1:WIDTH];
    4'h7:    y <= shifter[WIDTH-1:0];
    default: y <= 1'b0;
    endcase
  end


endmodule
