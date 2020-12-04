// GPU testbench                                       12/3/2020 BNE

`timescale 1ns/10ps

module gpu_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg  [2:0]    sel;
  reg           go = 0;
  wire [17:0]   y;
  reg  [17:0]   a;
  reg  [17:0]   b;

  gpu #(18) u1 (
    .clk    (clk),
    .rst_n  (rst_n),
    .sel    (sel),
    .go	    (go),
    .busy   (busy),
    .y	    (y),
    .a	    (a),
    .b	    (b)
  );

  always #5 clk <= !clk;

  // Trigger GPU operation
  task TEST;
    input [17:0] ain;
    input [17:0] bin;
    input [2:0] selin;
    begin
      @(posedge clk);
      a <= ain;  b <= bin;  sel <= selin;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
      @(negedge busy);
    end
  endtask

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      TEST(18'o777371, 18'o001116, 0);          // set colors
      TEST(18'o520252, 18'd0, 1);
      repeat (10) TEST(18'd0, 18'd0, 2);        // monochrome out
      TEST(18'o26, 18'd0, 3);                   // gray
      TEST(18'o77, 18'd0, 3);                   // more gray
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
