// MCU testbench                                     10/10/2020 BNE
// License: This code is a gift to the divine.

// The MCU connects to a SPI flash model from FMF.
// Run this for 5 msec.

`timescale 1ns/10ps

module mcu_artyA7_tb();

  localparam CLKPERIOD = 10;      // 100 MHz
  localparam UBAUD = (100 / 3);   // 3 MBPS

  reg	        clk_in = 1;
  reg	        rst_n = 0;

// UART connection
  reg           uart_rxd = 1;
  wire          uart_txd;

  wire [3:0]    led;              // test LEDs, green LD4 to LD7, 1=on
  reg  [3:0]    sw  = 4'b0000;    // slide switches
  reg  [3:0]    btn = 4'b0010;    // pushbuttons
  wire [2:0]    RGB0;             // color LEDs
  wire [2:0]    RGB1;
  wire [2:0]    RGB2;
  wire [2:0]    RGB3;
// LCD module with 8-bit bus and internal frame buffer
  wire [7:0]    lcd_d;            // read data
  wire          lcd_rd;           // RDX pin
  wire          lcd_wr;           // WRX pin
  wire          lcd_rs;           // DCX pin
  wire          lcd_cs;           // CSX pin
  wire          lcd_rst;          // RESET pin, active low
// 6-wire connection to SPI flash chip
  wire          qspi_sck;
  wire          qspi_cs;
  wire [3:0]    qspi_dq;

  s25fl064l #(
    .mem_file_name ("app.txt"),
    .secr_file_name ("none")
  ) SPIflash (
    .SCK          (qspi_sck),
    .SO           (qspi_dq[1]),
    .CSNeg        (qspi_cs),
    .IO3_RESETNeg (qspi_dq[3]),
    .WPNeg        (qspi_dq[2]),
    .SI           (qspi_dq[0]),
    .RESETNeg     (rst_n)
  );

  pullup(qspi_dq[0]);                // pullup resistors on all four lines
  pullup(qspi_dq[1]);
  pullup(qspi_dq[2]);
  pullup(qspi_dq[3]);

  mcu_arty u1 (
    .clk_in   (clk_in  ),
    .rst_n    (rst_n   ),
    .led      (led     ),
    .sw       (sw      ),
    .btn      (btn     ),
    .RGB0     (RGB0    ),
    .RGB1     (RGB1    ),
    .RGB2     (RGB2    ),
    .RGB3     (RGB3    ),
    .lcd_d    (lcd_d   ),
    .lcd_rd   (lcd_rd  ),
    .lcd_wr   (lcd_wr  ),
    .lcd_rs   (lcd_rs  ),
    .lcd_cs   (lcd_cs  ),
    .lcd_rst  (lcd_rst ),
    .qspi_sck (qspi_sck),
    .qspi_cs  (qspi_cs ),
    .qspi_dq  (qspi_dq ),
    .uart_rxd (uart_rxd),
    .uart_txd (uart_txd)
  );

  always #(CLKPERIOD / 2) clk_in <= !clk_in;

  // Send a byte: 1 start, 8 data, 1 stop
  task UART_TX;
    input [7:0] i_Data;
    begin
      uart_rxd = 1'b0;
      repeat (10) begin
        #(CLKPERIOD * UBAUD)
        uart_rxd = i_Data[0];
        i_Data = {1'b1, i_Data[7:1]};
      end
    end
  endtask // UART_TX

  // Main Testing:
  initial
    begin
      #17 rst_n <= 1'b1;
      $display("Began booting at %0t", $time);
      @(posedge qspi_cs);
      $display("Finished booting at %0t", $time);
      $display("Time is in units of ns/10 or us/10000");
      repeat (20000) @(posedge clk_in);
      $display("Sending line of text to UART RXD");
      UART_TX(8'h35); // 5 .s
      UART_TX(8'h20);
      UART_TX(8'h2E);
      UART_TX(8'h73);
      UART_TX(8'h0A);
      $display("\"5 .s\" entered at %0t", $time);
      repeat (400000) @(posedge clk_in);
      // Demonstrate ISP by reading the 3-byte JDID (9F command).
      // A more modern method of getting flash characteristics is with the
      // SFDP (5A command), which fixes the mess created by the JDID scheme.
      $display("Activating ISP, trigger ping");
      UART_TX(8'h12);           // activate ISP
      UART_TX(8'hA5);
      UART_TX(8'h5A);
      UART_TX(8'h42);           // ping (4 bytes)
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
      UART_TX(8'h00);
      repeat (2000) @(posedge clk_in);
      $stop();
    end

  // Capture UART data
  reg [7:0] uart_rxdata;
  always @(negedge uart_txd) begin   // wait for start bit
    #(CLKPERIOD * UBAUD / 2)
    uart_rxdata = 8'd0;
    repeat (8) begin
      #(CLKPERIOD * UBAUD)
      uart_rxdata = {uart_txd, uart_rxdata[7:1]};
    end
    #(CLKPERIOD * UBAUD)
    $display("UART: %02Xh = %c at %0t", uart_rxdata, uart_rxdata, $time);
  end

  // Dump signals for EPWave, a free waveform viewer on Github.
  initial
    begin
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
