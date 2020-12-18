// Coprocessor testbench                                  12/17/2020 BNE

`timescale 1ns/10ps

module coproc_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  reg  [10:0]    sel = 0;
  reg            go = 0;
  wire [17:0]    y;
  reg  [17:0]    tos = 0;
  reg  [17:0]    nos = 0;
  reg  [17:0]    w = 0;

  coproc #(18) u1 (
    .clk    (clk),
    .arstn  (rst_n),
    .sel    (sel),
    .go	    (go),
    .y	    (y),
    .a	    (tos),
    .b	    (nos),
    .c	    (w)
  );

  always #5 clk <= !clk;

  // Poll the busy flag in a loop
  task WAIT;
    begin
      sel <= 0;
      @(posedge clk);
      while (y) @(posedge clk);
    end
  endtask

  // Trigger coprocessor operation
  task TEST;
    input [10:0] selin; // select
    input [17:0] ain;   // TOS
    input [17:0] bin;   // NOS
    input [17:0] cin;   // W
    begin
      @(posedge clk);
      tos <= ain;  nos <= bin;  w <= cin;  sel <= selin;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
    end
  endtask

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      TEST(11'h18, 18'o777371, 18'o001116, 0);     // set colors
      TEST(11'h38, 18'o520252, 18'd0, 0);
      repeat (10) TEST(11'h58, 18'd0, 18'd0, 0);   // monochrome out
      TEST(11'h78, 18'o26, 18'd0, 0);              // gray
      WAIT();
      TEST(11'h78, 18'o77, 18'd0, 0);              // more gray
      WAIT();
      repeat (200) @(posedge clk);
      $display("Testbench Finished");
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
