// Generic synchronous read/write single-port RAM               10/26/2020 BNE

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
    if (re)
      dout <= mem[addr];
  end

endmodule

// Some FPGAs don't like "if (re)".
// If commented out, the `hold` signal in `spif` won't work correctly.
// So, you won't be able to use DMA or hardware I/O hold-off.
// Otherwise, firmware will still run.

// Lattice XP2 (Brevia2), Diamond ISE: Firmware runs but there is a complaint
// about synthesis of EBR. So, I don't know if (re) is being ignored.
// BRAM could be instantiated to avoid the messages.

// Lattice iCE5LP4K: iCEcube2 warns of simulation mismatch but synthesises EBR.

// MAX10 FPGA: Quartus complains that there is a read-during-write behavior that
// might not match simulation. It doesn't apply to Chad's use case.
// Using "else if (re)" rules out BRAM use, making it un-synthesizable.
// Replacing "we,re" controls with "we,en" causes the same problem.

// 7-series Xilinx FPGAs: Vivado doesn't complain.

// In an ASIC, the "if (re)" can be handled by a latch. For example, when not
// enabled bus-hold resistors could keep the tristate read bus in its last state.
