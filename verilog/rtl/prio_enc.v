// Parameterizable priority encoder
// see https://github.com/yugr/primogen/blob/master/src/prio_enc.v
// same logic as https://opencores.org/projects/priority_encoder

// `y` = bit number of the highest `a` bit, 0 if none.

`default_nettype none

module prio_enc #(
  parameter WIDTH = 4
)(
  input wire [(1<<WIDTH)-1:0] a,
  output wire [WIDTH - 1:0] y
);

localparam M = 1 << WIDTH;
wire [WIDTH*M - 1:0] ors;
assign ors[WIDTH*M - 1:(WIDTH - 1)*M] = a;

genvar w;
generate
  for (w = WIDTH - 1; w >= 0; w = w - 1) begin : encoder
    assign y[w] = |ors[w*M + 2*(1 << w) - 1:w*M + (1 << w)];
    if (w > 0) begin
      assign ors[(w - 1)*M + (1 << w) - 1:(w - 1)*M] = y[w] ?
             ors[w*M + 2*(1 << w) - 1:w*M + (1 << w)] : ors[w*M + (1 << w) - 1:w*M];
    end
  end
endgenerate

endmodule
