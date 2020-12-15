// Parameterizable priority encoder
// see https://github.com/yugr/primogen/blob/master/src/prio_enc.v

// `y` = bit number of the highest `a` bit, 0 if none.
// `a` has 2^WIDTH - 1 usable inputs.

module prio_enc #(
  parameter WIDTH = 4   // 2^WIDTH inputs --> WIDTH outputs
)(
  input wire [(1<<WIDTH)-1:0] a,
  output reg [WIDTH - 1:0] y
);

// May give slightly different synthesis results depending on ALTERNATE.

`ifdef ALTERNATE

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

`else

integer i, w;
reg [(1<<WIDTH) - 1:0] part;

always @* begin
  y = 0;
  part = a;
  for (i = WIDTH - 1; i >= 0; i = i - 1) begin
    w = 1 << i;
    if (|(part >> w))
      y[i] = 1;
    // Hopefully synthesizer understands that 'part' is shrinking...
    part = y[i] ? part >> w : part & ((1'd1 << w) - 1'd1);
  end
end

`endif

endmodule
