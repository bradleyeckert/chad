// MCU testbench                                     10/10/2020 BNE
// License: This code is a gift to the divine.

// The MCU connects to a SPI flash model from FMF.
// Run this for 600 usec.

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

  pullup(qd[3]);                // pullup resistors on all four lines
  pullup(qd[2]);
  pullup(qd[1]);
  pullup(qd[0]);
  pullup(cs_n);

  mcu #(24) u1 (
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

  // Send a byte: 1 start, 8 data, 1 stop
  task UART_TX;
    input [7:0] i_Data;
    begin
      rxd = 1'b0;
      repeat (10) begin
        #500
        rxd = i_Data[0];
        i_Data = {1'b1, i_Data[7:1]};
      end
    end
  endtask // UART_TX

  // Main Testing:
  initial
    begin
      #107
      rst_n <= 1'b1;
      @(posedge cs_n);
      $display("Finished booting");
      repeat (15000) @(posedge clk);
      // Demonstrate ISP by reading the 3-byte JDID (9F command).
      // A more modern method of getting flash characteristics is with the
      // SFDP (5A command), which fixes the mess created by the JDID scheme.
      UART_TX(8'h12);           // activate ISP
      UART_TX(8'hA5);
      UART_TX(8'h5A);
      UART_TX(8'h42);           // ping (4 bytes)
      repeat (2000) @(posedge clk);
      UART_TX(8'h00);
      UART_TX(8'h00);
      UART_TX(8'h82);           // send to SPI flash
      UART_TX(8'h9F);           // trigger ID read
      UART_TX(8'h02);
      UART_TX(8'hC2);           // read the 3 return bytes
      UART_TX(8'h80);           // raise CS_N
      UART_TX(8'h82);           // send to SPI flash 1 byte
      UART_TX(8'h05);           // RDSR
      UART_TX(8'hC2);           // read 1 status byte
      repeat (1000) @(posedge clk);
      UART_TX(8'hC2);           // read 1 status byte
      repeat (1000) @(posedge clk);
      UART_TX(8'hC2);           // read 1 status byte
      repeat (2000) @(posedge clk);
      UART_TX(8'h80);           // raise CS_N
      UART_TX(8'h12);           // deactivate ISP
      UART_TX(8'h00);
      repeat (2000) @(posedge clk);
      $stop();
    end

  // Capture UART data puttering along at 2 MBPS
  reg [7:0] uart_rxdata;
  always @(negedge txd) begin   // wait for start bit
    #250
    uart_rxdata = 8'd0;
    repeat (8) begin
      #500
      uart_rxdata = {txd, uart_rxdata[7:1]};
    end
    #500
    $display("UART: %02Xh", uart_rxdata);
  end

  // Dump signals for EPWave, a free waveform viewer on Github.
  initial
    begin
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule