// Shifter testbench                           11/6/2020 BNE

`timescale 1ns/10ps

module ishift_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg           go = 0;
  reg  [1:0]    fmt = 0;
  reg  [5:0]    cnt = 2;
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

  // Trigger a shift using (data, count, format)
  // format: 0 to 3 = >>1, <<1, /2, *2
  reg  signed [15:0] is_data;
  wire signed [15:0] ys = y;
  task TEST;
    input [15:0] i_data;
    input [5:0] i_cnt;
    input [1:0] i_fmt;
    begin
      is_data <= i_data;
      @(posedge clk);
      a <= i_data;
      cnt <= i_cnt;
      fmt <= i_fmt;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
      @(negedge busy);
      case (i_fmt)
      2'd0: $display("Unsigned %d >> %d produces %d", i_data, i_cnt, y);
      2'd1: $display("Unsigned %d << %d produces %d", i_data, i_cnt, y);
      2'd2: $display("Signed %d >> %d produces %d", is_data, i_cnt, ys);
      2'd3: $display("Signed %d << %d produces %d", is_data, i_cnt, ys);
      endcase
    end
  endtask

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      TEST( 10000, 8, 0);               // LSR
      TEST(   100, 4, 1);               // LSL
      TEST(-10000, 3, 2);               // ASR
      TEST(-10000, 3, 0);               // LSR
      TEST(   -10, 4, 3);               // ASL
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
