// Shifter testbench                           11/6/2020 BNE

`timescale 1ns/10ps

module ishift_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg           go = 0;
  reg  [1:0]    fmt = 0;
  reg  [4:0]    cnt = 2;
  reg  [15:0]   a = 100;
  wire [15:0]   y;

  ishift u1 (
    .clk    (clk),
    .arstn  (rst_n),
    .busy   (busy),
    .go	    (go),
    .fmt    (fmt),
    .cnt    (cnt),
    .a	    (a),
    .y      (y)
  );

  always #5 clk <= !clk;

  // Trigger a shift using 1 of
  task TEST;
    input [15:0] i_data;
    input [4:0] i_cnt;
    input [1:0] i_fmt;
    begin
      @(posedge clk);
      a <= i_data;
      cnt <= i_cnt;
      fmt <= i_fmt;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
      @(negedge busy);
      $display("shift %d by %d produces %d in format %d", i_data, i_cnt, y, i_fmt);
    end
  endtask // UART_WRITE_BYTE

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      TEST(100, 2, 0);          // LSR
      TEST(100, 3, 1);          // LSL
      TEST(-1000, 2, 2);        // ASR
      TEST(-1000, 2, 0);        // LSR
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
