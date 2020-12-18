// Peripherals for a Wishbone Bus, Arty A7 version        12/15/2020 BNE
// This code is a gift to the divine.

// This subsystem encapsulates the application's peripherals.
// It connects to a Wishbone Bus controller such as an MCU or testbench.
// Peripherals are put here to facilitate testing without an MCU.

`default_nettype none
module demo_io
#(
  parameter WIDTH = 32,                 // Wishbone bus size
  parameter GPO_BITS = 16,              // bits of general purpose output
  parameter GPI_BITS = 4                // bits of general purpose input
)(
  input wire                clk,
  input wire                rst_n,
// Wishbone Bob
  input wire  [14:0]        adr_i,      // address
  output reg  [WIDTH-1:0]   dat_o,      // data out
  input wire  [WIDTH-1:0]   dat_i,      // data in
  input wire                we_i,       // 1 = write, 0 = read
  input wire                stb_i,      // strobe
  output reg                ack_o,      // acknowledge
// LCD module with 8-bit bus and internal frame buffer
  input wire  [7:0]         lcd_di,     // read data
  output wire [7:0]         lcd_do,     // write data
  output wire               lcd_oe,     // lcd_d output enable
  output wire               lcd_rd,     // RDX pin
  output wire               lcd_wr,     // WRX pin
  output wire               lcd_rs,     // DCX pin
  output wire               lcd_cs,     // CSX pin
  output wire               lcd_rst,    // RESET pin, active low
// GPIO
  output reg [GPO_BITS-1:0] gp_o,
  input wire [GPI_BITS-1:0] gp_i
);

// Instantiate an LCD controller

  wire lcd_sel = (adr_i[14:3] == 2);    // 10h to 17h
  wire lcd_stb = stb_i & lcd_sel;
  wire lcd_ack;
  wire [7:0] lcd_dat;

  lcdcon u1(
    .clk      (clk        ),
    .rst_n    (rst_n      ),
    .adr_i    (adr_i[2:0] ),
    .dat_o    (lcd_dat    ),
    .dat_i    (dat_i[17:0]),
    .we_i     (we_i       ),
    .stb_i    (lcd_stb    ),
    .ack_o    (lcd_ack    ),
    .lcd_di   (lcd_di     ),
    .lcd_do   (lcd_do     ),
    .lcd_oe   (lcd_oe     ),
    .lcd_rd   (lcd_rd     ),
    .lcd_wr   (lcd_wr     ),
    .lcd_rs   (lcd_rs     ),
    .lcd_cs   (lcd_cs     ),
    .lcd_rst  (lcd_rst    )
  );

// A simple peripheral for LEDs and switches

  wire led_sel = (adr_i[14:0] == 24);   // 18h
  wire led_stb = stb_i & led_sel;

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      gp_o <= 0;
    end else begin
      if (led_sel & we_i) begin
        gp_o <= dat_i[GPO_BITS-1:0];    // GP out
      end
    end
  end

// Wishbone return signals
// ack is '1' by default so that accessing unused I/O doesn't hang.

  always @* begin
    if (lcd_sel) ack_o = lcd_ack;
    else ack_o = 1'b1;
  end

  always @* begin
    if (lcd_sel) dat_o = lcd_dat;
    else dat_o = gp_i;
  end

endmodule
`default_nettype wire
