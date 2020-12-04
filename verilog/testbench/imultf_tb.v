// Multipler testbench                                       11/30/2020 BNE

`timescale 1ns/10ps

module imultf_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg           go = 0;
  reg           sign = 1;
  reg  [7:0]    a = 99;
  reg  [7:0]    b = 43;
  reg  [4:0]    bits = 5;
  wire [15:0]   p;
// a is signed, b is unsigned

// This kind of multiplier lets you trade precision for speed.
// Tests:
// 99 * (43/64) = 4284h = 66.515625
// -123 * (43/64) = AD5Ch = -52A4h = -82.640625

  imultf #(8) u1 (
    .clk    (clk),
    .arstn  (rst_n),
    .busy   (busy),
    .go	    (go),
    .sign   (sign),
    .bits   (bits),
    .a	    (a),
    .b	    (b),
    .p      (p)
  );

  always #5 clk <= !clk;

  // Trigger a multiply
  reg  signed [7:0] ns;
  wire signed [15:0] ps = p;
  reg [8:0] denominator;
  real actual, expected;
  task TEST;
    input [7:0] n;
    input [7:0] u;
    input [5:0] count;
    input is_signed;
    begin
      ns <= n;
      denominator <= 1 << (count + 1);
      @(posedge clk);
      a <= n;  b <= u;  bits <= count;
      sign <= is_signed;
      @(posedge clk);  go <= 1'b1;
      @(posedge clk);  go <= 1'b0;
      @(negedge busy);
      if (is_signed) begin
        expected = $itor(ns) * $itor(u) / $itor(denominator);
        actual = $itor(ps) / $itor(256);
        $display("(%d * %d) / %d produces %f (%f)", ns, u, denominator, actual, expected);
      end else begin
        expected = $itor(n) * $itor(u) / $itor(1 << (count + 1));
        actual = $itor(p) / $itor(256);
        $display("(%d * %d) / %d produces %f (%f)", n, u, denominator, actual, expected);
      end
    end
  endtask

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      TEST(99, 43, 5, 1);
      if (p != 16'h4284) $error("Test 1 failed");
      TEST(-123, 43, 5, 1);
      if (p != 16'hAD5C) $error("Test 2 failed");
      TEST(255, 255, 7, 0); // -1 -1 um* test
      if (p != 16'hFE01) $error("Test 3 failed");
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
