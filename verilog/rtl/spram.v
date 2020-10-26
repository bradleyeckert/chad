// Generic synchronous read/write single-port RAM               10/18/2020 BNE

`default_nettype none

module spram
#(parameter ADDR_WIDTH = 10,
  parameter DATA_WIDTH = 16
)
( input wire                   clk,
  input wire  [ADDR_WIDTH-1:0] addr,
  input wire  [DATA_WIDTH-1:0] din,
  output reg  [DATA_WIDTH-1:0] dout,
  input wire                   we,
  input wire                   re
);

  reg [DATA_WIDTH-1:0] 	mem [2**ADDR_WIDTH-1:0];

  always @ (posedge clk) begin
    if (we)
      mem[addr] <= din;
//  if (re)
      dout <= mem[addr];
  end

endmodule

// Some FPGAs don't like (re).
// If commented out, the `hold` signal in `spif` won't work correctly.
// So, you won't be able to use DMA or hardware I/O hold-off.
// Otherwise, firmware will still run.
