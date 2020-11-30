// ILI9341 testbench                                       11/24/2020 BNE

`timescale 1ns/10ps

module ILI9341_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  reg  [15:0]   data;           // stream output data          o
  reg           stb = 0;        // stream strobe               o
  wire          busy;           // busy                        i
  wire [17:0]   db;             // data bus                    i
  wire          rs;             // RS pin                      i
  wire          wr_n;           // /WR pin                     i

  ILI9341 u1 (
    .clk        (clk),
    .rst_n      (rst_n),
    .st_i       (data),
    .stb        (stb),
    .busy       (busy),
    .db  	(db),
    .rs	        (rs),
    .wr_n       (wr_n)
  );

  task SEND;
    input [15:0] i_Data;
    begin
      @(posedge clk);  stb <= 1'b1;  data <= i_Data;
      @(posedge clk);  stb <= 1'b0;  #2
      while (busy) @(posedge clk);
    end
  endtask // SEND

  always #5 clk <= !clk;

// mode   pixel   writes
// `0000` 18-bit: Three bytes representing R, G, and B.
// `0100` 16-bit: Two bytes representing 5:6:5 color format.
// `1000` 18-bit: Two 9-bit words representing 6:6:6 color format.
// `1010` 16-bit: One 16-bit word representing 5:6:5 color format.
// `1011` 18-bit: Two 16-bit words representing 6:6:6 color format.
// `1110` 18-bit: One 18-bit word representing 6:6:6 color format.

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      SEND(16'h108E);    // format = full
      SEND(16'h1094);    // cycle length
      SEND(16'h10A2);    // wr_n edge position
      SEND(16'h1000);    // BG
      SEND(16'h1009);
      SEND(16'h1011);
      SEND(16'h107F);    // FG
      SEND(16'h1078);
      SEND(16'h1070);
      SEND(16'h0222);    // test bytes
      SEND(16'h0333);
      SEND(16'hAAAA);    // monochrome pixels
      repeat (300) @(posedge clk);
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule

// st_i is interpreted to output multiple pixels per 16-bit token. The tokens are:
// WRREG   00010xxx_xxdddddd  Register writes.
// BGCOLOR 00010000_00dddddd  Load background color
// FGCOLOR 00010000_01dddddd  Load foreground color
// MODE    00010000_1000dddd  Load mode
// PERIOD  00010000_1001dddd  Load period
// WRHIGH  00010000_1010dddd  Load write trailing edge position
// DIRECT  0000xxxr_dddddddd  Reserved for direct control of data bus, r is RS bit.
// MONOCT  001nnnnx_xxxxxxxx  Output 0 to 9 monochrome pixels, LSB first.
// MONO01  0100aaaa_aabbbbbb  Output a BG pixels followed by b FG pixels.
// GRAY0   01010ggg_gccccccc  Output 4-bit g pixel followed by up to 127 BG pixels
// GRAY1   01011ggg_gccccccc  Output 4-bit g pixel followed by up to 127 FG pixels
// SETRG   0110rrrr_rrgggggg  Color pixel prefix: RG
// RGBRUN  0111cccc_ccbbbbbb  Output RGB pixel with repeat counter up to 127
// MONO15  1xxxxxxx_xxxxxxxx  Output 15 monochrome pixels, LSB first.
