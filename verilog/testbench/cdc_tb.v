// CDC testbench                               11/6/2020 BNE

`timescale 10ps/10ps

module cdc_tb();

  reg	        clk = 1;
  reg           a = 0;
  wire          y;

  cdc u1 (
    .clk    (clk),
    .a	    (a),
    .y      (y)
  );

  always #500 clk <= !clk;
  always #3217 a <= !a;

  // Main Testing:
  initial
    begin
      repeat (1000) @(posedge clk);
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule

