// Coprocessor for Chad processor       11/5/2020 BNE
// Type 000 = minimal stub

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
  output wire [WIDTH-1:0] y,
  input wire  [WIDTH-1:0] a,
  input wire  [WIDTH-1:0] b,
  input wire  [WIDTH-1:0] c
);

  assign y = 1'b0;

endmodule
