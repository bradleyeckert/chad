// Wrapper for the MCU                           10/18/2020 BNE

// This synthesizes for a MAX10. It uses clkgen.v PLL IP.

`default_nettype none
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
  wire  [3:0]  qdo, oe;
  assign qspi_dq[0] = (oe[0]) ? qdo[0] : 1'bZ;
  assign qspi_dq[1] = (oe[1]) ? qdo[1] : 1'bZ;
  assign qspi_dq[2] = (oe[2]) ? qdo[2] : 1'bZ;
  assign qspi_dq[3] = (oe[3]) ? qdo[3] : 1'bZ;

  wire [11:0] gp_o;
  wire [3:0] gp_i = btn;
  assign {RGB0, RGB1, RGB2, RGB3} = gp_o;

  // MCU
  mcu #(BASEBLOCK, BAUD_DIV, 24, 13, 10, 12, 4) small_mcu (
    .clk      (clk     ),
    .rst_n    (arst_n  ),
    .sclk     (qspi_sck),
    .cs_n     (qspi_cs ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .oe       (oe      ),
    .rxd      (uart_rxd),
    .txd      (uart_txd),
    .gp_o     (gp_o    ),
    .gp_i     (gp_i    )
  );

endmodule
