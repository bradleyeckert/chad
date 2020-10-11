// Generic synchronous read/write single-port RAM               9/30/2020 BNE

`default_nettype none

module spram
#(parameter ADDR_WIDTH = 10,
  parameter DATA_WIDTH = 16
)
( input wire                   clk,
  input wire  [ADDR_WIDTH-1:0] addr,
  input wire  [DATA_WIDTH-1:0] din,
  output wire [DATA_WIDTH-1:0] dout,
  input wire                   we,
  input wire                   re
);

  reg [DATA_WIDTH-1:0] 	tmp_data;
  reg [DATA_WIDTH-1:0] 	mem [2**ADDR_WIDTH-1:0];

  always @ (posedge clk) begin
    if (we)
      mem[addr] <= din;
  end

  always @ (posedge clk) begin
    if (re)
      tmp_data <= mem[addr];
  end
  assign dout = tmp_data;

endmodule
