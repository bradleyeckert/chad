// gecko testbench                                  10/26/2020 BNE
// Run this for 5 us
// expected $display output: 08 01 80 72 78 59 91 de ...

`timescale 1ns/10ps

module gecko_tb();

  reg clk = 1;
  reg rst_n = 0;

  reg clken = 1'b0;     // clock enable
  wire ready;           // initializing
  reg next = 1'b0;      // byte trigger
  wire [7:0] dout;      // PRNG output

//  reg [63:0] widekey = 64'h0012345687654321;
  reg [63:0] widekey = 64'h1;
  reg [3:0] idx = 0;
  wire [7:0] key = widekey[7:0];

  gecko u1 (
    .clk        (clk),
    .rst_n      (rst_n),
    .clken      (clken),
    .ready      (ready),
    .next       (next),
    .key        (key),
    .dout	(dout)
  );

  always #5 clk <= !clk;

  task NEXT;                    // get next PRNG byte
    reg [7:0] x;
    begin
      @(posedge ready);     x = dout;
      @(posedge clk);   next <= 1'b1;
      @(posedge clk);   next <= 1'b0;
      $display("%Xh", x);
    end
  endtask // NEXT

  // Main Testing:
  initial
    begin
      #7  rst_n = 1'b1;
      @(posedge clk);
      clken <= 1'b1;
      while (idx < 7) begin    // load the key
        @(posedge clk);
        widekey <= {8'h00, widekey[63:8]};
        idx = idx + 1;
      end
      repeat (1000) NEXT();
      @(posedge ready);
      #100
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
