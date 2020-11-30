// Streaming interface for ILI9341 or ILI9388 LCD controller

// Input = 16-bit data stream
// Output = 18-bit, 16-bit, 9-bit, or 8-bit data to TFT module

// The TFT connection is minimal: /RD is not used.
// /RESET, /CS, and backlight LED modulation are provided externally.
// Valid IM modes are 0 through 3, indicating bus width {8, 16, 9, 18}.

// This module is for hardware-assisted bitmap copying to a color LCD module
// with ILI9341 type controller: Typically QVGA or HVGA resolution.
// 16-bit tokens are intended to be streamed to this module to render text.
// The bitmap is run-length-encoded grayscale or monochrome bitmap data.
// The grayscale is interpolated between foreground and background colors.

`default_nettype none

module ILI9341 (
  input wire        clk,
  input wire        rst_n,
// Stream input
  input wire [15:0] st_i,               // stream data
  input wire        stb,                // stream strobe
  output reg        busy,
// LCD connection
  output reg [17:0] db,                 // data bus
  output reg        rs,                 // RS pin
  output reg        wr_n                // /WR pin
);

  reg  [3:0] state, next;               // bus byte select
  reg [17:0] pixel;                     // 18-bit pixel data to send
  reg  [8:0] data;                      // register data to send

// Output formats:
//  8-bit: R5:G3, G3:B5 or R6, G6, B6
// 16-bit: R5:G6:B5 or R6:G6:B4, B2
//  9-bit: R6:G3, G3:B6 or R6, G6, B6
// 18-bit: R6:G6:B6

  always @*
  case (state) // translate 18-bit (6:6:6) pixel data to the bus format
// 8-bit format
  4'b0000: {next, db} <= {14'b0000_0000000000, pixel[17:12], 2'b00};
  4'b0001: {next, db} <= {14'b0010_0000000000, pixel[17:12], 2'b00}; // R6
  4'b0010: {next, db} <= {14'b0011_0000000000, pixel[11:6],  2'b00}; // G6
  4'b0011: {next, db} <= {14'b0000_0000000000, pixel[5:0],   2'b00}; // B6
  4'b0100: {next, db} <= {14'b0101_0000000000, pixel[17:13], pixel[11:9]};
  4'b0101: {next, db} <= {14'b0000_0000000000, pixel[8:6], pixel[5:1]};
  4'b0110,
  4'b0111: {next, db} <= {14'b0000_0000000000, data[7:0]};
// 9-bit format
  4'b1000: {next, db} <= {13'b1001_000000000, pixel[17:12], pixel[11:9]};
  4'b1001: {next, db} <= {13'b0000_000000000, pixel[8:6], pixel[5:0]};
// 16-bit format
  4'b1010: {next, db} <= { 6'b0000_00, pixel[17:13], pixel[11:6], pixel[5:1]};
  4'b1011: {next, db} <= { 6'b1100_00, pixel[17:2]};
  4'b1100: {next, db} <= {16'b0000_000000000000, pixel[1:0]};
// 18-bit format
  default: {next, db} <= {4'b0000, pixel};
  endcase

// Internally, pixels are 18-bit. One or more bus cycles send them over the bus
// depending on IM. Two strobes trigger the output.

  reg  [3:0] mode;                      // starting state of write sequence
  reg  [3:0] delay, period, wrhigh;     // timing parameters
  reg  [6:0] repcount;                  // repeat counter
  reg [17:0] fgcolor, bgcolor;          // foreground and background colors

  reg [3:0] istate;                     // input state
  reg [5:0] fg, bg;                     // 6-bit colors to interpolate
  reg [5:0] gray;                       // grayscale

  wire [5:0] dark = ~gray;
  wire [11:0] prod = fg * gray  +  bg * dark;
  wire [5:0] color = prod[11:6];

  localparam IDLE  = 4'b0001;
  localparam RED   = 4'b0010;
  localparam GREEN = 4'b0100;
  localparam BLUE  = 4'b1000;

  reg [14:0] monodata;
  reg [3:0] monochrome;                 // monochrome bit counter
  reg [1:0] BWpair;                     // repeat pair state: 2, 1
  reg [6:0] BWcount0, BWcount1;         // bit counter for BWpair

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state <= 4'b0;  busy <= 1'b0;  repcount <= 7'b0;
      delay <= 4'b0;  period <= 4'hF;  istate <= IDLE;
      wrhigh <= 4'h7;   wr_n <= 1'b1;  rs <= 1'b0;
      mode <= 4'h4;                     // bus: 8-bit mode, 16-bit format
      monochrome <= 4'h0;  BWpair <= 2'b0;
    end else begin
      case (istate)
        IDLE:
          if (delay) begin              // write cycle in progress
            if (delay == wrhigh)
              wr_n <= 1'b1;
            delay <= delay - 1'b1;
          end else begin
            if (next) begin             // another write cycle pending
              state <= next;
              wr_n <= 1'b0;
              delay = period;
            end else begin              // finished sending pixel or data
              if (repcount) begin       // repeating last pixel
                repcount <= repcount - 1'b1;
                state <= mode;
                wr_n <= 1'b0;  rs <= 1'b0;  busy <= 1'b1;
                delay = period;
              end else if (monochrome) begin
                monochrome <= monochrome - 1'b1;
                pixel <= (monodata[0]) ? fgcolor : bgcolor;
                monodata <= {monodata[14], monodata[14:1]};
                state <= mode;          // next monochrome pixel
                wr_n <= 1'b0;  rs <= 1'b0;  busy <= 1'b1;
                delay = period;
              end else if (BWpair) begin
                BWpair <= BWpair - 1'b1;
                pixel <= (BWpair[0]) ? fgcolor : bgcolor;
                repcount <= (BWpair[0]) ? BWcount1 : BWcount0;
              end else begin
                busy <= 1'b0;           // ready to interpret st_i
// st_i is interpreted to output multiple pixels per 16-bit token. The tokens are:
// WRREG   00010xxx_xxdddddd  Register writes.
// DIRECT  0000xxxr_dddddddd  Reserved for direct control of data bus, r is RS bit.
// MONOCT  001nnnnx_xxxxxxxx  Output 0 to 9 monochrome pixels, LSB first.
// MONO01  0100aaaa_aabbbbbb  Output a BG pixels followed by b FG pixels.
// GRAY0   01010ggg_gccccccc  Output 4-bit g pixel followed by up to 127 BG pixels
// GRAY1   01011ggg_gccccccc  Output 4-bit g pixel followed by up to 127 FG pixels
// SETRG   0110rrrr_rrgggggg  Color pixel prefix: RG
// RGBRUN  0111cccc_ccbbbbbb  Output RGB pixel with repeat counter up to 127
// MONO15  1xxxxxxx_xxxxxxxx  Output 15 monochrome pixels, LSB first.
                if (stb) casez (st_i)
                16'b0000????_????????:          // DIRECT
                  begin
                    rs <= st_i[8];
                    data <= st_i[7:0];
                    state <= 4'd7;
                    wr_n <= 1'b0;  busy <= 1'b1;
                    delay = period;
                  end
                16'b0001????_00??????:          // WRREG
                  bgcolor <= {bgcolor[11:0], st_i[5:0]};
                16'b0001????_01??????:
                  fgcolor <= {fgcolor[11:0], st_i[5:0]};
                16'b0001????_1000????:
                  mode   <= st_i[3:0];
                16'b0001????_1001????:
                  period <= st_i[3:0];
                16'b0001????_1010????:
                  wrhigh <= st_i[3:0];
                16'b1???????_????????:          // MONO15
                  begin
                    monochrome <= 4'd15;
                    monodata <= st_i[14:0];
                  end
                16'b001?????_????????:          // MONOCT
                  begin
                    monochrome <= st_i[12:9];
                    monodata <= st_i[14:0];
                  end
                16'b0100????_????????:          // MONO01
                  begin
                    BWcount0 <= {1'b0, st_i[11:6]};
                    BWcount1 <= {1'b0, st_i[5:0]};
                    BWpair <= 2'b10;
                  end
                16'b0101????_????????:          // GRAY0, GRAY1
                  begin
                    if (st_i[11]) begin
                      BWcount0 <= 6'b0;
                      BWcount1 <= st_i[6:0];
                    end else begin
                      BWcount0 <= st_i[6:0];
                      BWcount1 <= 6'b0;
                    end
                    BWpair <= 2'b01;
                    gray <= {st_i[10:7], st_i[10:9]};
                    state <= mode;
                    wr_n <= 1'b0;  rs <= 1'b0;  busy <= 1'b1;
                    delay = period;
                    {fg, bg} <= {fgcolor[17:12], bgcolor[17:12]};
                    istate <= RED;
                  end
                16'b0110????_????????:          // SETRG
                  pixel[17:6] <= st_i[11:0];
                16'b0111????_????????:          // RGBRUN
                  begin
                    pixel[5:0] <= st_i[5:0];
                    repcount  <= st_i[11:6];
                    state <= mode;
                    wr_n <= 1'b0;  rs <= 1'b0;  busy <= 1'b1;
                    delay = period;
                  end
                endcase
              end
            end
          end
        RED:
          begin
            pixel[17:12] <= color;
            {fg, bg} <= {fgcolor[11:6], bgcolor[11:6]};
            istate <= GREEN;
          end
        GREEN:
          begin
            pixel[11:6] <= color;
            {fg, bg} <= {fgcolor[5:0], bgcolor[5:0]};
            istate <= BLUE;
          end
        BLUE:
          begin
            pixel[5:0] <= color;
            istate <= IDLE;
          end
      endcase
    end

endmodule
