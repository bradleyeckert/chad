// Wrapper for the MCU                           10/18/2020 BNE

// This synthesizes for a MAX10. It uses clkgen.v PLL IP.

module mcu_top
(
  input wire          clk_in,
  input wire          rst_n,
  output wire [3:0]   led,      // test LEDs, red LD4 to LD7, 1=on
  input  wire [3:0]   sw,       // slide switches
  input  wire [3:0]   btn,      // pushbuttons
  output wire [2:0]   RGB0,     // color LEDs
  output wire [2:0]   RGB1,
  output wire [2:0]   RGB2,
  output wire [2:0]   RGB3,
// 6-wire connection to SPI flash chip
  output wire         qspi_sck,
  output wire         qspi_cs,
  inout wire [3:0]    qspi_dq,
// UART connection
  input wire          uart_rxd,
  output wire         uart_txd
);

  localparam BAUD_DIV = (96 / 3);       // Divisor for 3MBPS UART
  localparam BASEBLOCK = 0;             // External SPI flash

  wire clk, locked;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;

  clkgen clkgen_inst (
	.inclk0 ( clk_in ),
	.c0 ( clk ),
	.locked ( locked )
	);

  always @(posedge clk) begin
    arst_n <= rst_n1;
    rst_n1 <= rst_n & locked;
  end

  assign led[0] =             sw[0];    // sanity checks
  assign led[1] = uart_rxd ^ ~sw[1];
  assign led[2] = uart_txd ^ ~sw[2];
  assign led[3] = qspi_cs ^  ~sw[3];

  wire  [3:0]  qdi = qspi_dq;           // tri-state QSPI bus
  wire  [3:0]  qdo, qoe;
  assign qspi_dq[0] = (qoe[0]) ? qdo[0] : 1'bZ;
  assign qspi_dq[1] = (qoe[1]) ? qdo[1] : 1'bZ;
  assign qspi_dq[2] = (qoe[2]) ? qdo[2] : 1'bZ;
  assign qspi_dq[3] = (qoe[3]) ? qdo[3] : 1'bZ;

  wire [11:0] gp_o;
  wire [3:0] gp_i = btn;
  assign {RGB0, RGB1, RGB2, RGB3} = gp_o;

  // Wishbone Alice
  wire  [14:0]  adr_o;
  wire  [31:0]  dat_o, dat_i;
  wire          we_o, stb_o, ack_i;

  // MCU
  mcu #(BASEBLOCK, BAUD_DIV, 24, 13, 10) small_mcu (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .sclk     (qspi_sck),
    .cs_n     (qspi_cs ),
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

  demo_io #(32, 16, 4) simple_io (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .adr_i    (adr_o   ),
    .dat_o    (dat_i   ),
    .dat_i    (dat_o   ),
    .we_i     (we_o    ),
    .stb_i    (stb_o   ),
    .ack_o    (ack_i   ),
    .gp_o     (gp_o    ),
    .gp_i     (gp_i    )
  );

endmodule
