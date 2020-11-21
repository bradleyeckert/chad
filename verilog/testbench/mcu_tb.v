// MCU testbench                                     11/20/2020 BNE
// License: This code is a gift to the divine.

// The MCU connects to a SPI flash model from FMF.
// Run this for 8 msec to exercise the interpreter and wait for ISP.

`timescale 100ps/10ps

module mcu_tb();

  localparam CLKPERIOD = 100;   // 100 MHz
  localparam UBAUD = 31;        // 3 MBPS, off by 1%

  reg	        clk = 1;
  reg	        rst_n = 0;

  reg           rxd = 1;
  wire          txd;
  wire          sclk;
  wire          cs_n;
  wire  [3:0]   qdi;
  wire  [3:0]   qdo;
  wire  [3:0]   oe;             // output enable for qdo
  wire  [3:0]   qd;             // quad data bus

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

  mcu #(24, UBAUD) u1 (
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

  always #(CLKPERIOD / 2) clk <= !clk;

  // Send a byte: 1 start, 8 data, 1 stop
  task UART_TX;
    input [7:0] i_Data;
    begin
      rxd = 1'b0;
      repeat (10) begin
        #(CLKPERIOD * UBAUD)
        rxd = i_Data[0];
        i_Data = {1'b1, i_Data[7:1]};
      end
    end
  endtask // UART_TX

  // Main Testing:
  initial
    begin
      #1 rst_n <= 1'b1;
      $display("Began booting at %t", $time);
      @(posedge cs_n);
      $display("Finished booting at %t", $time);
      $display("Time is in units of ns/10 or us/10000");
      repeat (20000) @(posedge clk);
      $display("Sending line of text to UART RXD");
      UART_TX(8'h35); // 5 .s
      UART_TX(8'h20);
      UART_TX(8'h2E);
      UART_TX(8'h73);
      UART_TX(8'h0A);
      repeat (400000) @(posedge clk);
      // Demonstrate ISP by reading the 3-byte JDID (9F command).
      // A more modern method of getting flash characteristics is with the
      // SFDP (5A command), which fixes the mess created by the JDID scheme.
      $display("Activating ISP, trigger ping");
      UART_TX(8'h12);           // activate ISP
      UART_TX(8'hA5);
      UART_TX(8'h5A);
      UART_TX(8'h42);           // ping (4 bytes)
      repeat (20000) @(posedge clk);
      $display("Get SPI flash JDID");
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
    #(CLKPERIOD * UBAUD / 2)
    uart_rxdata = 8'd0;
    repeat (8) begin
      #(CLKPERIOD * UBAUD)
      uart_rxdata = {txd, uart_rxdata[7:1]};
    end
    #(CLKPERIOD * UBAUD)
    $display("UART: %02Xh = %c at %t", uart_rxdata, uart_rxdata, $time);
  end

  // Dump signals for EPWave, a free waveform viewer on Github.
  initial
    begin
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
