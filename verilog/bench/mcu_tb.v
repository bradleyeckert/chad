// MCU testbench                                     10/10/2020 BNE
// License: This code is a gift to the divine.
// status: crude start, not tested

// The MCU connects to a SPI flash model from FMF.
// The UART should be monitored so it displays chars.

`timescale 1ns/10ps

module mcu_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  reg           rxd = 1;
  wire          txd;
  wire          sclk;
  wire          cs_n;
  wire  [3:0]   qdi;
  wire  [3:0]   qdo;
  wire  [3:0]   oe;               // output enable for qdo
  wire  [3:0]   qd;               // quad data bus

  assign qdi = qd;
  assign qd[0] = (oe[0]) ? qdo[0] : 1'bZ;
  assign qd[1] = (oe[1]) ? qdo[1] : 1'bZ;
  assign qd[2] = (oe[2]) ? qdo[2] : 1'bZ;
  assign qd[3] = (oe[3]) ? qdo[3] : 1'bZ;

  s25fl064l #(
    .mem_file_name ("myapp.txt"),
    .secr_file_name ("none")
  ) SPIflash (
    .SCK          (sclk ),
    .SO           (qd[1]),
    .CSNeg        (cs_n ),
    .IO3_RESETNeg (qd[3]),
    .WPNeg        (qd[2]),
    .SI           (qd[0]),
    .RESETNeg     (rst_n)
  );

  pullup(qd[3]);
  pullup(qd[2]);
  pullup(qd[1]);
  pullup(qd[0]);

  mcu u1 (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .rxd      (rxd     ),
    .txd      (txd     ),
    .sclk     (sclk    ),
    .cs_n     (cs_n    ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .oe       (oe      )
  );

  always #5 clk <= !clk;

  // Main Testing:
  initial
    begin
      #107
      rst_n <= 1'b1;
      @(posedge cs_n);
      $display("Finished booting");
      #100000000
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
