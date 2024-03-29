// Wrapper for the MCU                           12/13/2020 BNE

// This synthesizes for a Brevia 2 (LFXP2-5) with 50 MHz clock.

module mcu_top
(
  input wire          clk_in,
  input wire          rst_n,
  output wire [7:0]   led,    			// test LEDs
  input wire  [7:0]   sw,     			// test buttons
// 6-wire connection to SPI flash chip
  output wire         spi_sclk,
  output wire         spi_csn,
  inout wire          spi_mosi, 		// io0
  inout wire          spi_miso, 		// io1
  inout wire          wn,       		// io2
  inout wire          holdn,    		// io3
// UART connection
  input wire          uart_rx,
  output wire         uart_tx
);

  localparam BAUD_DIV = (50 / 3);       // Divisor for 3MBPS UART
  localparam BASEBLOCK = 0;             // External SPI flash

  wire clk = clk_in;
  wire locked = 1'b1;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;

//  clkgen clkgen_inst (
//	.CLK ( clk_in ),
//	.CLKOP ( clk ),
//	.LOCK ( locked )
//	);

  always @(posedge clk) begin
    arst_n <= rst_n1;
    rst_n1 <= rst_n & locked;
  end

  wire  [3:0]  qdi, qdo, qoe;
  assign qdi = {holdn, wn, spi_miso, spi_mosi};
  assign spi_mosi = (qoe[0]) ? qdo[0] : 1'bZ;
  assign spi_miso = (qoe[1]) ? qdo[1] : 1'bZ;
  assign wn       = (qoe[2]) ? qdo[2] : 1'bZ;
  assign holdn    = (qoe[3]) ? qdo[3] : 1'bZ;
  wire [7:0] ledn;
  assign led = ~ledn;

  // Wishbone Alice
  wire  [14:0]  adr_o;
  wire  [31:0]  dat_o, dat_i;
  wire          we_o, stb_o, ack_i;

  // MCU
  mcu #(BASEBLOCK, BAUD_DIV, 24, 12, 10) small_mcu (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .sclk     (spi_sclk),
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

  demo_io #(32, 8, 8) simple_io (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .adr_i    (adr_o   ),
    .dat_o    (dat_i   ),
    .dat_i    (dat_o   ),
    .we_i     (we_o    ),
    .stb_i    (stb_o   ),
    .ack_o    (ack_i   ),
    .gp_o     (ledn    ),
    .gp_i     (sw      )
  );

endmodule
