// Wrapper for the MCU                           12/13/2020 BNE

// Efinix version
// The T20 part in 256BGA has a bitstream size of up to 10.4 64KB blocks.
// The MCU is ported to the Xyloni board which has a T8F81.
// Efinix uses an XML file managed by an Interface Editor to assign pins
// and connections (such as tri-state buffers) to the design.

`default_nettype none
module mcu_top
(
  input wire          clk,
  input wire          rst_n,
  output wire [3:0]   leds,
  input wire          btn,
// 4-wire connection to SPI flash chip
  output wire         spi_sck,
  output wire         spi_cs,
  input wire          spi_di0,
  input wire          spi_di1,
  output wire         spi_do0,
  output wire         spi_do1,
  output wire         spi_oe0,
  output wire         spi_oe1,
// UART connection
  input wire          uart_rxd,
  output wire         uart_txd
);

  localparam BAUD_DIV = (34 / 2);       // Divisor for 2MBPS UART
  localparam BASEBLOCK = 11;            // for T20

  reg reset_n = 1'b0;
  reg rst_n1 = 1'b0;
  always @(posedge clk or negedge rst_n)
  if (!rst_n) {reset_n, rst_n1} <= 2'b00;
  else        {reset_n, rst_n1} <= {rst_n1, 1'b1};

  wire [3:0] qdo, qoe;
  wire [3:0] qdi = {2'b00, spi_di1, spi_di0};
  assign {spi_do1, spi_do0} = qdo[1:0];
  assign {spi_oe1, spi_oe0} = qoe[1:0];
  wire [1:0] btns = {1'b0, btn};

    // Wishbone Alice
  wire  [14:0]  adr_o;
  wire  [31:0]  dat_o, dat_i;
  wire          we_o, stb_o, ack_i;

  // MCU
  mcu #(BASEBLOCK, BAUD_DIV, 24, 12, 10) small_mcu (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .sclk     (spi_sck ),
    .cs_n     (spi_cs  ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .qoe      (qoe     ),
    .rxd      (uart_rxd),
    .txd      (uart_txd),
    .adr_o    (adr_o   ),
    .dat_o    (dat_o   ),
    .dat_i    (dat_i   ),
    .we_o     (we_o    ),
    .stb_o    (stb_o   ),
    .ack_i    (ack_i   ),
    .irqs     (2'b00   )
  );

  demo_io #(32, 4, 2) simple_io (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .adr_i    (adr_o   ),
    .dat_o    (dat_i   ),
    .dat_i    (dat_o   ),
    .we_i     (we_o    ),
    .stb_i    (stb_o   ),
    .ack_o    (ack_i   ),
    .gp_o     (leds    ),
    .gp_i     (btns    )
  );

endmodule
`default_nettype wire
