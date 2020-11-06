// Divider testbench                                  11/5/2020 BNE

`timescale 1ns/10ps

module idivu_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          busy;
  reg           go = 0;
  reg  [15:0]   dividend = 46845;
  reg  [7:0]    divisor = 200;
  wire [7:0]    quot;
  wire [7:0]    rem;
  wire          overflow;

  idivu u1 (
    .clk       (clk),
    .arstn     (rst_n),
    .busy      (busy),
    .go	       (go),
    .dividend  (dividend),
    .divisor   (divisor),
    .quot      (quot),
    .rem       (rem),
    .overflow  (overflow)
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
