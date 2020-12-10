// Unbuffered UART with FIFO-compatible interface               11/6/2020 BNE
// License: This code is a gift to the divine.

module uart
(
  input wire            clk,
  input wire            arstn,          // async reset (active low)
  output wire           ready,     	// Ready for next byte to send
  input wire            wr,        	// UART transmit strobe
  input wire  [7:0]     din,      	// UART transmit data
  output reg            full,      	// UART has received a byte
  input wire            rd,        	// UART received strobe (clears full)
  output reg  [7:0]     dout,        	// UART received data
  input wire  [15:0]    bitperiod,      // Clocks per serial bit
  input wire            rxd,            // Must be externally synchronized
  output reg            txd
);

// Baud rate is BPS = clk/bitperiod. Example: 100M/868 = 115200 BPS.
  reg [11:0] baudint;
  reg [3:0] baudfrac;
  reg tick;
  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    baudint <= 12'd0;  tick <= 1'b0;
    baudfrac <= 4'd0;
  end else begin
    tick <= 1'b0;
    if (baudint)
      baudint <= baudint - 1'b1;
    else begin
      tick <= 1'b1;
      if (bitperiod[3:0] > baudfrac)    // fractional divider:
           baudint <= bitperiod[15:4];  // stretch by Frac/16 clocks
      else baudint <= bitperiod[15:4] - 1'b1;
      baudfrac <= baudfrac + 1'b1;      // 16 ticks/bit
    end
  end

  reg tnext, error;
  wire startbit = ~rxd & ~error;
  reg [7:0] inreg;                      // pending transmit byte
  reg pending;

  assign ready = ~pending;

// UART
  reg [7:0] txstate, rxstate, txreg, rxreg;
  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    txstate <= 8'd0;  txreg <= 8'd0;  tnext <= 1'b1;  txd <= 1'b1;
    rxstate <= 8'd0;  rxreg <= 8'd0;  error <= 1'b0;  pending <= 1'b0;
    dout <=    8'd0;  inreg <= 8'd0;  full <= 1'b0;
  end else begin
    if (tick) begin
// Transmitter
      txd <= tnext;
      if (txstate) begin
        if (!txstate[3:0])
          {txreg, tnext} <= {1'b1, txreg[7:0]};
        txstate <= txstate - 1'b1;
      end else begin
        if (pending) begin
          pending <= 1'b0;   txreg <= inreg;
          txstate <= 8'h9F;  tnext <= 1'b0;   // n,8,1
        end
      end
// Receiver
      if (rxstate) begin
        if (rxstate[3:0] == 4'd1)
          case (rxstate[7:4])
          4'b1001:
            if (rxd) rxstate <= 8'd0;   // false start
          4'b0000:
            if (rxd) {dout, full} <= {rxreg, 1'b1};
            else      error <= 1'b1;    // '0' at the stop bit (or BREAK)
          default:
            rxreg <= {rxd, rxreg[7:1]};
          endcase
        rxstate <= rxstate - 1'b1;
      end else begin
        error <= error & ~rxd;          // stop or mark ('1') clears error
        if (startbit) rxstate <= 8'h98; // will be sampled mid-bit
      end
    end
    if (rd) full <= 1'b0;               // reading clears full
// Transmit input register gives firmware an entire character period to respond
// to ready with the next byte to elimnate character spacing.
    if (wr)
      if (!pending) begin               // retrigger transmission
        inreg <= din;  pending <= 1'b1;
      end
  end
endmodule
