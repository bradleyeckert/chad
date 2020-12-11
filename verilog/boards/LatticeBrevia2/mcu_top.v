// Wrapper for the MCU                           10/18/2020 BNE

// This runs on the Brevia 2 board. FPGA: LFXP2-5E-6TN144C

// Without changing the MCU, the UART baud rate is 1MBPS since Fclk = 50 MHz.
// This is supported by the FTDI chip, port B.

`default_nettype none
module mcu_top
(
  input wire          clk_in,
  input wire          rst_n,
  output wire         led_0,    // test LEDs
  output wire         led_1,
  output wire         led_2,
  output wire         led_3,
  output wire         led_4,
  output wire         led_5,
  output wire         led_6,
  output wire         led_7,
  input wire          sw_4,     // test buttons
  input wire          sw_5,
  input wire          sw_6,
  input wire          sw_7,
// 6-wire connection to SPI flash chip
  output wire         spi_sclk,
  output wire         spi_csn,
  inout wire          spi_mosi, // io0
  inout wire          spi_miso, // io1
  inout wire          wn,       // io2
  inout wire          holdn,    // io3
// UART connection
  input wire          uart_rx,
  output wire         uart_tx
);

  wire clk;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;
  wire locked;

  clkgen pll (.CLK(clk_in), .CLKOP(clk), .LOCK(locked));

  always @(posedge clk) begin
    arst_n <= rst_n1;
    rst_n1 <= rst_n & locked;
  end

  assign led_0 = sw_7;
  assign led_1 = uart_rx ^ ~sw_6;
  assign led_2 = uart_tx ^ ~sw_5;
  assign led_3 = spi_csn ^ ~sw_4;
  assign led_4 = spi_mosi;
  assign led_5 = spi_miso;
  assign led_6 = wn;
  assign led_7 = holdn;

  wire  [3:0]  qdi;
  wire  [3:0]  qdo;
  wire  [3:0]  oe;
  assign qdi = {holdn, wn, spi_miso, spi_mosi};
  assign spi_mosi = (oe[0]) ? qdo[0] : 1'bZ;
  assign spi_miso = (oe[1]) ? qdo[1] : 1'bZ;
  assign wn       = (oe[2]) ? qdo[2] : 1'bZ;
  assign holdn    = (oe[3]) ? qdo[3] : 1'bZ;

  // MCU
  mcu #(24, 31) small_mcu (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .sclk     (spi_sclk),
    .cs_n     (spi_csn ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .oe       (oe      ),
    .rxd      (uart_rx ),
    .txd      (uart_tx )
  );

endmodule
