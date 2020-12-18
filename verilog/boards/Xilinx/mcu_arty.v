// Wrapper for the MCU                           12/1/2020 BNE

// This runs on a Digilent Arty-A7-35 board
// FPGA p/n XC7A35T-1CSG324C

// Arty-A7 shorting block factory settings: JP1 and JP2 are ON.
// JP1 = boot mode: ON = SPIflash, OFF = JTAG.
// JP2 = reset over USB: ON = connect FT2232H (BDBUS4) to FPGA reset.
//       JP2 causes the FPGA to be reset when the COM port is opened.

// An Artix-7 35T bitstream is typically 17,536,096 bits, 21728Ch bytes.
// The BASEBLOCK for user flash is 22h.
// The Arty A7 has a S25FL128SAGMFI00 (16MB) flash, which is mostly 64K sectors.

`default_nettype none
module mcu_arty
(
  input wire          clk_in,
  input wire          rst_n,
  output wire [3:0]   led,              // test LEDs, green LD4 to LD7, 1=on
  input  wire [3:0]   sw,               // slide switches
  input  wire [3:0]   btn,              // pushbuttons
  output wire [2:0]   RGB0,             // color LEDs
  output wire [2:0]   RGB1,
  output wire [2:0]   RGB2,
  output wire [2:0]   RGB3,
// LCD module with 8-bit bus and internal frame buffer
  inout wire  [7:0]   lcd_d,            // read data
  wire                lcd_rd,           // RDX pin
  wire                lcd_wr,           // WRX pin
  wire                lcd_rs,           // DCX pin
  wire                lcd_cs,           // CSX pin
  wire                lcd_rst,          // RESET pin, active low
// 6-wire connection to SPI flash chip
  output wire         qspi_sck,
  output wire         qspi_cs,
  inout wire [3:0]    qspi_dq,
// UART connection
  input wire          uart_rxd,
  output wire         uart_txd
);

  localparam BAUD_DIV = (100 / 3);      // Divisor for 3MBPS UART
  localparam BASEBLOCK = 34;            // for Artix-7 35T

// The STARTUPE2 primitive can, in theory, supply CCLK to the SPI flash so that
// the qspi_sck pin is not needed. I couldn't make it work, but Arty supplies the pin.

  wire clk, locked;
  reg arst_n = 1'b0;
  reg rst_n1 = 1'b0;

  assign clk = clk_in;                  // No PLL, the oscillator input is 100 MHz
  assign locked = 1'b1;

  always @(posedge clk) begin           // provide a synced reset at power-up
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
  assign {RGB0, RGB1, RGB2, RGB3} = gp_o;

  wire  [7:0]  lcd_do;
  wire         lcd_oe;
  assign lcd_d = (lcd_oe) ? lcd_do : 8'bZ;

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

  demo_io #(32, 12, 4) simple_io (
    .clk      (clk     ),
    .rst_n    (rst_n   ),
    .adr_i    (adr_o   ),
    .dat_o    (dat_i   ),
    .dat_i    (dat_o   ),
    .we_i     (we_o    ),
    .stb_i    (stb_o   ),
    .ack_o    (ack_i   ),
    .lcd_di   (lcd_d   ),
    .lcd_do   (lcd_do  ),
    .lcd_oe   (lcd_oe  ),
    .lcd_rd   (lcd_rd  ),
    .lcd_wr   (lcd_wr  ),
    .lcd_rs   (lcd_rs  ),
    .lcd_cs   (lcd_cs  ),
    .lcd_rst  (lcd_rst ),
    .gp_o     (gp_o    ),
    .gp_i     (btn     )
  );

endmodule
`default_nettype wire
