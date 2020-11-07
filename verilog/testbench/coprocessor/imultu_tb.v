// Multipler testbench                                       11/5/2020 BNE

`timescale 1ns/10ps

module imultu_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg           go = 0;
  reg  [7:0]    a = 100;
  reg  [7:0]    b = 100;
  wire [15:0]   p;

  imultu u1 (
    .clk    (clk),
    .arstn  (rst_n),
    .busy   (busy),
    .go	    (go),
    .a	    (a),
    .b	    (b),
    .p      (p)
  );

  always #5 clk <= !clk;

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
      repeat (200) @(posedge clk);
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
