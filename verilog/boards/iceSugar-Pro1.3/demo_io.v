// Peripherals for a Wishbone Bus              12/15/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

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
// GPIO
  output reg [GPO_BITS-1:0] gp_o,
  input wire [GPI_BITS-1:0] gp_i
);

// Route stb_i and ack_o to the individual peripherals.

  reg [3:0] wbstb;
  always @*
    casez (adr_i[7:2])
    6'b000101: {wbstb, ack_o} <= {3'b000, stb_i, 1'b1};
    default:   {wbstb, ack_o} <= {4'b0000, 1'b1};
    endcase

  always @*
    casez (adr_i[7:0])
    default:   dat_o <= gp_i;
    endcase

// A simple peripheral for GPIO

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      gp_o <= 0;
    end else begin
      if (wbstb[0] & we_i) begin
        if (adr_i[0] == 0)
          gp_o <= dat_i[GPO_BITS-1:0];  // GP out
      end
    end
  end

endmodule
`default_nettype wire
