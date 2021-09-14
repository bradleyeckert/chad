// Graphics Processing Unit for Small Color LCDs                12/3/2020

// Perhaps a wee bit smaller than nVidia...
// This does some math for feeding a ILI9341 or ILI9488 LCD controller.
// Basic functions are:
// 1. Translating a 1pbb word into a color one bit at a time.
// 2. Alpha-blending two colors using 4bpp grayscale.
// 3. Formatting color data for bus writes.

`default_nettype none

module gpu
#(
  parameter WIDTH = 18                  // data width
)
(
  input wire  clk,
  input wire  rst_n,
  input wire  [1:0] sel,
  input wire  go,                       // trigger CLOAD, MLOAD, MONO, GRAY
  output reg  busy,
  output wire [WIDTH-1:0] y,
  input wire  [WIDTH-1:0] a,            // tos
  input wire  [WIDTH-1:0] b             // nos
);

  reg [17:0] pixel, fgcolor, bgcolor;
  assign y = pixel;

// Two multipliers are used in the interpolation

  reg [5:0] fg, bg, gray;               // 6-bit colors to interpolate
  wire [5:0] dark = ~gray;
  reg mtrig, mbusy;

  reg [2:0] count;
  reg [11:0] accf, accb;                // accumulators

  wire [6:0] sumf = accf[11:6] + gray;
  wire [6:0] sumb = accb[11:6] + dark;

  always @(posedge clk or negedge rst_n)
  if (!rst_n) begin
    mbusy <= 1'b0;
	{count, accf, accb} <= 1'b0;
  end else begin                        // dual unsigned multiply
    if (mbusy) begin
      accf <= (accf[0]) ? {sumf, accf[5:1]} : {1'b0, accf[11:1]};
      accb <= (accb[0]) ? {sumb, accb[5:1]} : {1'b0, accb[11:1]};
      if (count) count <= count - 1'b1;
      else mbusy <= 1'b0;
    end else begin
      if (mtrig) begin
        mbusy <= 1'b1;
        count <= 3'd5;
        accf <= fg;
        accb <= bg;
      end
    end
  end

  wire [6:0] color = accf[11:5] + accb[11:5];

// FSM

  reg [WIDTH-1:0] monodata;
  reg [1:0] state;
  wire ready = ~mbusy & ~mtrig;

  always @*
    case (state)
    2'd3:    {fg, bg} = {fgcolor[17:12], bgcolor[17:12]};
    2'd2:    {fg, bg} = {fgcolor[11:6], bgcolor[11:6]};
    default: {fg, bg} = {fgcolor[5:0], bgcolor[5:0]};
    endcase

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      {busy, state, mtrig} <= 1'b0;
      {pixel, fgcolor, bgcolor, monodata, gray} <= 1'b0;
    end else begin
      mtrig <= 1'b0;
      if (state) begin
        if (ready) begin
          case (state)
          2'd3: {pixel[17:12], mtrig} <= {color[6:1], 1'b1};
          2'd2: {pixel[11:6],  mtrig} <= {color[6:1], 1'b1};
          2'd1: {pixel[5:0],   mtrig} <= {color[6:1], 1'b0};
          endcase
          state <= state - 1'b1;
        end
      end else begin
        busy <= go;
        if (go) case (sel)
        2'd0:
          begin
            fgcolor <= a[17:0];
            bgcolor <= b[17:0];
          end
        2'd1:
          begin
            monodata <= a;
          end
        2'd2:
          begin
            pixel <= (monodata[0]) ? fgcolor : bgcolor;
            monodata <= {1'b0, monodata[WIDTH-1:1]};
          end
        default:
          begin
            gray <= {a[3:0], a[3:2]};
            mtrig <= 1'b1;
            state <= 2'd3;
          end
        endcase
      end
    end

endmodule
`default_nettype wire
