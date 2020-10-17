// gecko testbench                                  10/16/2020 BNE

`timescale 1ns/10ps

module gecko_tb();

  reg clk = 1;
  reg rst_n = 0;

  reg clken = 1'b1;     // clock enable
  wire ready;           // initializing
  reg key = 1'b1;       // 121-bit randomized key
  reg next = 1'b0;      // byte trigger
  wire [7:0] dout;      // PRNG output

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

  task NEXT;            // get next PRNG byte
    reg   [7:0] sr;
    begin
      @(posedge ready);
      sr = dout;
      @(posedge clk);  next <= 1'b1;
      @(posedge clk);  next <= 1'b0;
      $display("%Xh", sr);
    end
  endtask // NEXT

  // Main Testing:
  initial
    begin
      #7
      rst_n = 1'b1;
      #100
      key = 1'b0;
      repeat (20) NEXT();
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
