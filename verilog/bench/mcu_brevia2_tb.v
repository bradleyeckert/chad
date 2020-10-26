// MCU testbench                                     10/10/2020 BNE
// License: This code is a gift to the divine.

// The MCU connects to a SPI flash model from FMF.
// Run this for 700 usec.

`timescale 1ns/10ps

module mcu_brevia2_tb();

  reg	        clk_in = 1;
  reg	        rst_n = 0;

// UART connection
  reg           uart_rx = 1;
  wire          uart_tx;

  wire          led_0;        // test LEDs
  wire          led_1;
  wire          led_2;
  wire          led_3;
  wire          led_4;
  wire          led_5;
  wire          led_6;
  wire          led_7;
  reg           sw_4 = 1;     // test buttons
  reg           sw_5 = 1;
  reg           sw_6 = 1;
  reg           sw_7 = 1;
// 6-wire connection to SPI flash chip
  wire          spi_sclk;
  wire          spi_csn;
  wire          spi_mosi;     // io0
  wire          spi_miso;     // io1
  wire          wn;           // io2
  wire          holdn;        // io3

  s25fl064l #(
    .mem_file_name ("myapp.txt"),
    .secr_file_name ("none")
  ) SPIflash (
    .SCK          (spi_sclk),
    .SO           (spi_miso),
    .CSNeg        (spi_csn ),
    .IO3_RESETNeg (holdn),
    .WPNeg        (wn),
    .SI           (spi_mosi),
    .RESETNeg     (rst_n)
  );

  pullup(spi_mosi);                // pullup resistors on all four lines
  pullup(spi_miso);
  pullup(wn);
  pullup(holdn);
  pullup(cs_n);

  mcu_top u1 (
    .clk_in   (clk_in  ),
    .rst_n    (rst_n   ),
    .uart_rx  (uart_rx ),
    .uart_tx  (uart_tx ),
    .spi_sclk (spi_sclk),
    .spi_csn  (spi_csn ),
    .spi_mosi (spi_mosi),
    .spi_miso (spi_miso),
    .wn       (wn      ),
    .holdn    (holdn   ),
    .led_0    (led_0   ),
    .led_1    (led_1   ),
    .led_2    (led_2   ),
    .led_3    (led_3   ),
    .led_4    (led_4   ),
    .led_5    (led_5   ),
    .led_6    (led_6   ),
    .led_7    (led_7   ),
    .sw_4     (sw_4    ),
    .sw_5     (sw_5    ),
    .sw_6     (sw_6    ),
    .sw_7     (sw_7    )
  );

  always #5 clk_in <= !clk_in;

  // Send a byte: 1 start, 8 data, 1 stop
  task UART_SEND;
    input [7:0] i_Data;
    begin
      uart_rx = 1'b0;
      repeat (10) begin
        #500
        uart_rx = i_Data[0];
        i_Data = {1'b1, i_Data[7:1]};
      end
    end
  endtask // UART_SEND

  // Main Testing:
  initial
    begin
      #107
      rst_n <= 1'b1;
      @(posedge spi_csn);
      $display("Finished booting");
      repeat (15000) @(posedge clk_in);
      // Demonstrate ISP by reading the 3-byte JDID (9F command).
      // A more modern method of getting flash characteristics is with the
      // SFDP (5A command), which fixes the mess created by the JDID scheme.
      UART_SEND(8'h12);           // activate ISP
      UART_SEND(8'hA5);
      UART_SEND(8'h5A);
      UART_SEND(8'h42);           // ping (5 bytes)
      repeat (2000) @(posedge clk_in);
      UART_SEND(8'h00);
      UART_SEND(8'h00);
      UART_SEND(8'h82);           // send to SPI flash
      UART_SEND(8'h9F);           // trigger ID read
      UART_SEND(8'h02);
      UART_SEND(8'hC2);           // read the 3 return bytes
      UART_SEND(8'h80);           // raise CS_N
      UART_SEND(8'h82);           // send to SPI flash 1 byte
      UART_SEND(8'h05);           // RDSR
      UART_SEND(8'hC2);           // read 1 status byte
      repeat (1000) @(posedge clk_in);
      UART_SEND(8'hC2);           // read 1 status byte
      repeat (1000) @(posedge clk_in);
      UART_SEND(8'hC2);           // read 1 status byte
      repeat (2000) @(posedge clk_in);
      UART_SEND(8'h80);           // raise CS_N
      UART_SEND(8'h12);           // deactivate ISP
      UART_SEND(8'h00);
      repeat (2000) @(posedge clk_in);
      $stop();
    end

  // Capture UART data puttering along at 2 MBPS
  reg [7:0] uart_rxdata;
  always @(negedge uart_tx) begin   // wait for start bit
    #250
    uart_rxdata = 8'd0;
    repeat (8) begin
      #500
      uart_rxdata = {uart_tx, uart_rxdata[7:1]};
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
