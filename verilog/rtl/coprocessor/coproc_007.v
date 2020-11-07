// Coprocessor for Chad processor       11/5/2020 BNE
// Type 007 = hardware multiply, divide, and shift

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

  wire mbusy, dbusy, overflow, sbusy;
  wire [2*WIDTH-1:0] product, shifter;
  wire [WIDTH-1:0] quot, rem;
  wire mtrig = go & (sel[3:0] == 4'h8);
  wire dtrig = go & (sel[3:0] == 4'h9);
  wire strig = go & (sel[3:0] == 4'hA);

  imultu #(WIDTH) u1 (          // iterative multiply
    .clk      (clk),
    .arstn    (arstn),
    .busy     (mbusy),
    .go	      (mtrig),
    .a	      (a),
    .b	      (b),
    .p        (product)
  );

  idivu #(WIDTH) u2 (           // iterative divide
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

// This module handles double-cell shifts.
// To handle single lshift, 0 before shift.
// To handle single rshift, dup before shift.

  ishift #(2*WIDTH) u3 (        // iterative shift
    .clk      (clk),
    .arstn    (arstn),
    .busy     (sbusy),
    .go	      (strig),
    .fmt      (sel[7:6]),
    .cnt      (c[4:0]),
    .a        ({a,b}),
    .y        (shifter)
  );

  always @(posedge clk or negedge arstn)
  if (!arstn)
    y <= 1'b0;
  else if (go)
    case (sel[3:0])
    4'h0:    y = mbusy | dbusy | sbusy;
    4'h1:    y = {overflow, 8'h07};
    4'h2:    y = product[2*WIDTH-1:WIDTH];
    4'h3:    y = product[WIDTH-1:0];
    4'h4:    y = quot;
    4'h5:    y = rem;
    4'h6:    y = shifter[2*WIDTH-1:WIDTH];
    4'h7:    y = shifter[WIDTH-1:0];
    default: y = 1'b0;
    endcase

endmodule
