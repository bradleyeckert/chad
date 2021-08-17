// Generic synchronous read/write single-port RAM               8/16/2021 BNE

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
    else if (re)
      dout <= mem[addr];
  end

endmodule

// This is supported by typical FPGAs and also OpenRAM.
// The "if (re)" can be removed for FPGA convenience.

// OpenRAM usually has a bi-directional bus whose direction is determined by
// we_b and cs_b. The logic for this would be:
// we_b = ~we
// ce_b = ~we & ~re
// BusDirection = we, arrange delay for bus switching to and from Z
