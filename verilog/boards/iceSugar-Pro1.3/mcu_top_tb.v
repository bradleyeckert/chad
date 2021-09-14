// MCU_TOP testbench                                     9/11/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

// This is a stimulus file for simulating the iCESugar board's FPGA connected to
// UART and SPI flash.
// To do: Instantiate mcu_top

// Run this for 5 msec to exercise the interpreter and wait for ISP.

`timescale 1ns/100ps

module mcu_top_tb();

  localparam CLKPERIOD = 16;    // 62.5 MHz
  localparam BITPERIOD = 1000;      // 1 MBPS

  pullup(spi_fd3);              // pullup resistors on all four lines
  pullup(spi_fd2);
  pullup(spi_miso);
  pullup(spi_mosi);

  reg         clk_in = 1'b1;
  wire [7:0]  led;              // test LEDs
  wire [4:0]  sw = 5'b01010; 	// test buttons
  wire        cs_n;
//  wire        spi_mosi;         // io0
//  wire        spi_miso;         // io1
//  wire        spi_fd2;       	// io2
//  wire        spi_fd3;        // io3
  wire        spi_sclk;         // copy of SCLK for simulation (see USRMCLK)
  reg         rxd;
  wire        txd;

  s25fl064l #(
    .mem_file_name ("myapp.txt"),
    .secr_file_name ("none")
  ) SPIflash (
    .SCK          (spi_sclk ),
    .SO           (spi_miso),
    .CSNeg        (cs_n),
    .IO3_RESETNeg (spi_fd3),
    .WPNeg        (spi_fd2),
    .SI           (spi_mosi),
    .RESETNeg     (1'b1)
  );

  mcu_top u1 (
    .clk_in   (clk_in  ),
    .led      (led     ),
    .sw       (sw      ),
    .spi_csn  (cs_n    ),
    .spi_mosi (spi_mosi),
    .spi_miso (spi_miso),
    .spi_fd2  (spi_fd2 ),
    .spi_fd3  (spi_fd3 ),
    .spi_sclk (spi_sclk),
    .uart_rx  (rxd ),
    .uart_tx  (txd )
  );

  always #(CLKPERIOD / 2)
	clk_in <= !clk_in;

  // Send a byte: 1 start, 8 data, 1 stop
  task UART_TX;
    input [7:0] i_Data;
    begin
      rxd = 1'b0;
      repeat (10) begin
        #(BITPERIOD)
        rxd = i_Data[0];
        i_Data = {1'b1, i_Data[7:1]};
      end
    end
  endtask // UART_TX

  reg prompt;
  integer okay = 0;

  // Main Testing:
  initial
    begin
      $display("Began booting at %0t", $time);
      @(posedge cs_n);
      $display("Finished booting at %0t", $time);
      $display("Time is in units of ns/10 or us/10000");
      @(posedge prompt);
      #(CLKPERIOD * 5000)       // wait 50 us after prompt
      $display("Sending line of text to UART RXD");
      UART_TX(8'h35);
      UART_TX(8'h20);
      UART_TX(8'h2E);
      UART_TX(8'h73);
      UART_TX(8'h0A);
      $display("\"5 .s\" entered at %0t", $time);
      @(posedge prompt);
      #(CLKPERIOD * 5000)
      // Demonstrate ISP by reading the 3-byte JDID (9F command).
      // A more modern method of getting flash characteristics is with the
      // SFDP (5A command), which fixes the mess created by the JDID scheme.
      $display("Activating ISP, trigger ping");
      UART_TX(8'h12);           // activate ISP
      UART_TX(8'hA5);           // 6-byte password
      UART_TX(8'h5A);
      UART_TX(8'h11);
      UART_TX(8'h22);
      UART_TX(8'h33);
      UART_TX(8'h44);
      UART_TX(8'h42);           // ping (7 bytes)
      repeat (20000) @(posedge clk_in);
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
      repeat (1000) @(posedge clk_in);
      UART_TX(8'hC2);           // read 1 status byte
      repeat (1000) @(posedge clk_in);
      UART_TX(8'hC2);           // read 1 status byte
      repeat (2000) @(posedge clk_in);
      UART_TX(8'h80);           // raise CS_N
      UART_TX(8'h12);           // deactivate ISP
      UART_TX(8'h00);           // 6-byte password mismatch
      UART_TX(8'h00);
      UART_TX(8'h00);
      UART_TX(8'h00);
      UART_TX(8'h00);
      UART_TX(8'h00);
      repeat (2000) @(posedge clk_in);
      $stop();
    end

  // Capture UART data
  reg [7:0] uart_rxdata;
  always @(negedge txd) begin   // wait for start bit
    #(BITPERIOD / 2)
    uart_rxdata = 8'd0;
    repeat (8) begin
      #(BITPERIOD)
      uart_rxdata = {txd, uart_rxdata[7:1]};
    end
    #(BITPERIOD)
    $display("UART: %02Xh = %c at %0t", uart_rxdata, uart_rxdata, $time);
    case (okay)
    0: if (uart_rxdata == 8'h6f) okay = 1;  // "ok>"
    1: if (uart_rxdata == 8'h6b) okay = 2;  else okay = 0;
    default: begin
       if (uart_rxdata == 8'h3e) begin
         prompt = 1'b1;  #(CLKPERIOD)
         prompt = 1'b0;
       end
       okay = 0;
    end
    endcase
  end

  // Dump signals for EPWave, a free waveform viewer on Github.
  initial
    begin
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule