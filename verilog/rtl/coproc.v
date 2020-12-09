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

  wire mbusy, dbusy, sbusy, gbusy;

`ifdef OPTIONS_IMULT                    // SBBBBB1001x
    wire mtrig = go & (sel[4:1] == 4'h9);
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
    wire [2*WIDTH-1:0] mprod = 0;
    assign mbusy = 0;
`endif

`ifdef OPTIONS_IDIV                     // xxxxxx1010x
    wire dtrig = go & (sel[4:1] == 4'hA);
    wire overflow;
    wire [WIDTH-1:0] quot, rem;
    idivu #(WIDTH) u1 (                 // iterative divide
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
    assign dbusy = 0;
`endif

`ifdef OPTIONS_ISHIFT                   // xxxxSL1011x
    wire strig = go & (sel[4:1] == 4'hB);
    wire [2*WIDTH-1:0] shifter;
    ishift #(2*WIDTH) u2 (              // iterative shift
      .clk      (clk),
      .arstn    (arstn),
      .busy     (sbusy),
      .go       (strig),
      .fmt      (sel[7:5]),
      .cnt      (c[5:0]),
      .a        ({a,b}),
      .y        (shifter)
  );
`else
    wire [2*WIDTH-1:0] shifter = 0;
    assign sbusy = 0;
`endif

`ifdef OPTIONS_TINYGPU                  // xxxMMM1100x
    wire gtrig = go & (sel[4:1] == 4'hC);
    wire [WIDTH-1:0] color;
    gpu #(WIDTH) u3 (                   // small TFT helper
      .clk      (clk),
      .rst_n    (arstn),
      .sel      (sel[6:5]),
      .go       (gtrig),
      .busy     (gbusy),
      .y        (color),
      .a        (a),
      .b        (b)
  );
`else
    localparam color = 0;
    assign gbusy = 0;
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
    4'h0:    y <= mbusy | dbusy | sbusy | gbusy;
    4'h1:    y <= {overflow, options};
    4'h2:    y <= mprod[2*WIDTH-1:WIDTH];
    4'h3:    y <= mprod[WIDTH-1:0];
    4'h4:    y <= quot;
    4'h5:    y <= rem;
    4'h6:    y <= shifter[2*WIDTH-1:WIDTH];
    4'h7:    y <= shifter[WIDTH-1:0];
    4'h8:    y <= color;
    default: y <= 1'b0;
    endcase
  end

endmodule
