// Wrapper for the MCU                           9/2/2021 BNE

// This synthesizes for a iCESugar-Pro (ECP5) SODIMM module.
// Synplify Pro gives much better timing results than LSE.
// It wants at least 14ns cycle time, so clk (from clk_in) is:
// 25MHz --> 62.5 MHz
// 26MHz --> 65 MHz

// The iCELink chip crashes with a 3M BPS baud rate, so use 1M BPS instead.

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

  localparam BAUD_DIV = (63 / 1);       // Divisor for 1MBPS UART
  localparam BASEBLOCK = 32;            // SPI flash application at 2MB addr

  wire rst_n = 1'b1;                    // no reset pin

// The FPGA starts with reset registers generating a clean reset, so rst_n
// is not needed. Good thing, because it's not on the FPGA board.

  wire clk;
  wire locked;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;

  clkgen clkgen_inst (                  // PLL
        .CLKI ( clk_in ),               // 25 MHz input
        .CLKOP ( clk ),
        .LOCK ( locked )
        );

  always @(posedge clk) begin
    arst_n <= rst_n1;
    rst_n1 <= rst_n & locked;
  end

// The SPI flash is shared by bitstream and application.
// MCLK is usually not a user mode pin, but the ECP5 has a workaround: USRMCLK
// This kills JTAG programming of the flash so you would want direct SPI connection
// to program the flash.

// USRMCLK tends to get pruned by Synplicity (thereby losing MCLK) is you're not careful.

  wire sclk_int;
  assign spi_sclk = sclk_int;

  USRMCLK u1 (.USRMCLKI(sclk_int), .USRMCLKTS(spi_csn)) /* synthesis syn_noprune=1 */;
  //                                            ^--- can't be a constant

  wire  [3:0]  qdi, qdo, qoe;
  assign qdi = {spi_fd3, spi_fd2, spi_miso, spi_mosi};
  assign spi_mosi = (qoe[0]) ? qdo[0] : 1'bZ;
  assign spi_miso = (qoe[1]) ? qdo[1] : 1'bZ;
  assign spi_fd2  = (qoe[2]) ? qdo[2] : 1'bZ;
  assign spi_fd3  = (qoe[3]) ? qdo[3] : 1'bZ;

  // Wishbone Alice
  wire  [14:0]  adr_o;
  wire  [31:0]  dat_o, dat_i;
  wire          we_o, stb_o, ack_i;

  // MCU
  mcu #(BASEBLOCK, BAUD_DIV, 24, 12, 11)
  small_mcu (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .sclk     (sclk_int),
    .cs_n     (spi_csn ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .qoe      (qoe     ),
    .rxd      (uart_rx ),
    .txd      (uart_tx ),
    .adr_o    (adr_o   ),
    .dat_o    (dat_o   ),
    .dat_i    (dat_i   ),
    .we_o     (we_o    ),
    .stb_o    (stb_o   ),
    .ack_i    (ack_i   ),
    .irqs     (2'b00   )
  );

  demo_io #(32, 8, 5)
  simple_io (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .adr_i    (adr_o   ),
    .dat_o    (dat_i   ),
    .dat_i    (dat_o   ),
    .we_i     (we_o    ),
    .stb_i    (stb_o   ),
    .ack_o    (ack_i   ),
    .gp_o     (led     ),
    .gp_i     (sw      )
  );

endmodule
