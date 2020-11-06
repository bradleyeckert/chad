// Coprocessor for Chad processor       11/5/2020 BNE
// Type 003 = hardware multiply and divide

`default_nettype none
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
  input wire  [WIDTH-1:0] a,
  input wire  [WIDTH-1:0] b,
  input wire  [WIDTH-1:0] c
);

  wire mbusy, dbusy, overflow;
  wire [2*WIDTH-1:0] product;
  wire [WIDTH-1:0] quot, rem;
  wire mtrig = go & (sel[3:0] == 4'h8);
  wire dtrig = go & (sel[3:0] == 4'h9);

  imultu #(WIDTH) u1 (  // iterative multiply
    .clk      (clk),
    .arstn    (arstn),
    .busy     (mbusy),
    .go	      (mtrig),
    .a	      (a),
    .b	      (b),
    .p        (product)
  );

  idivu #(WIDTH) u2 (   // iterative divide
    .clk      (clk),
    .arstn    (arstn),
    .busy     (dbusy),
    .go	      (dtrig),
    .dividend ({a,b}),
    .divisor  (c),
    .quot     (quot),
    .rem      (rem),
    .overflow (overflow)
  );

  always @(posedge clk or negedge arstn)
  if (!arstn)
    y <= 1'b0;
  else if (go)
    case (sel[2:0])
    3'h0:    y = mbusy | dbusy;
    3'h1:    y = {overflow, 8'h03};
    3'h2:    y = product[2*WIDTH-1:WIDTH];
    3'h3:    y = product[WIDTH-1:0];
    3'h4:    y = quot;
    3'h5:    y = rem;
    default: y = 1'b0;
    endcase

endmodule
