// Dummy module for exercising I/Os for PCB debugging

module mcu_top
(
  input wire          clk_in,
  output wire [7:0]   led,    		// test LEDs
  input wire  [4:0]   sw,     		// test buttons
// 6-wire connection to SPI flash chip
  output wire         spi_csn,
  inout wire          spi_mosi, 	// io0
  inout wire          spi_miso, 	// io1
  inout wire          spi_fd2,       	// io2
  inout wire          spi_fd3,    	// io3
  output wire         spi_sclk,         // copy of SCLK for simulation (see USRMCLK)
// UART connection
  input wire          uart_rx,
  output wire         uart_tx
);

// The FPGA starts with reset registers generating a clean reset, so rst_n
// is not needed. Good thing, because it's not on the FPGA board.

  wire clk = clk_in;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;
  reg [23:0] count = 24'd0;

  always @(posedge clk) begin
    arst_n <= rst_n1;
    rst_n1 <= 1'b1;
    count <= count + 1'b1;
  end

  assign uart_tx = uart_rx;     // loop back UART
  assign led[0] = ~uart_rx;
  assign led[1] = count[23];
  assign led[2] = count[22];
  assign led[7:3] = sw[4:0];

  assign spi_csn = count[23];
  assign spi_mosi = count[17];
  assign spi_miso = count[18];
  assign spi_fd2  = count[19];
  assign spi_fd3  = count[20];

// The SPI flash is shared by bitstream and application.
// MCLK is usually not a user mode pin, but the ECP5 has a workaround: USRMCLK
// This kills JTAG programming of the flash so you would want direct SPI connection
// to program the flash.

// Apparently, USRMCLK is being optimized away by Synplicity

  wire sclk_int = count[16];
  assign spi_sclk = sclk_int;

  USRMCLK u1 (.USRMCLKI(sclk_int), .USRMCLKTS(spi_csn)) /* synthesis syn_noprune=1 */;
  //                                            ^--- can't be a constant

endmodule
