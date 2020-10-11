// SPI flash interface                                          10/2/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module sflash
(
  input wire          clk,
  input wire          arstn,            // async reset
// Flash Memory interface to spif
  output reg          ready,            // Ready for next byte to send
  input wire          wr,               // Flash transmit strobe
  input wire          who,              // Who's asking?
  input wire  [7:0]   din,              // Flash transmit data
  input wire  [2:0]   format,           // Flash format
  input wire  [3:0]   prescale,         // Flash configuration setup
  output reg  [7:0]   dout,             // Flash received data
// SPI 6-wire connection
  output reg          sclk,             // Freq = Fclk / (2 * (prescale + 1))
  output wire         cs_n,
  input wire  [3:0]   qdi,
  output reg  [3:0]   qdo,
  output reg  [3:0]   oe                // output enable for qdo
);

// The 4-bit prescale value allows for a divisor of 2 to 32 on SCLK.
// for a 50 MHz SPI clock, the maximum module clock is 1.6 GHz.

// `who` is not used because you can't hide SPI bus data anyway.
// One could encrypt and decrypt data in this module, but this not done to keep
// it small and simple.

// format is the bus format of the SPI:
// 00x = inactive (CS# = '1')
// 01x = single data rate send and receive
// 100 = dual data rate send
// 101 = dual data rate receive
// 110 = quad data rate send
// 111 = quad data rate receive

  assign cs_n = (format[2:1]) ? 1'b0 : 1'b1;

  reg [1:0] state;
  localparam SPI_IDLE = 2'b01;
  localparam SPI_RUN  = 2'b10;

// SPI chip pins, GD25Q16C datasheet:
// Standard SPI: SCLK, CS#, SI, SO, WP#, HOLD#
// Dual SPI: SCLK, CS#, IO0, IO1, WP#, HOLD#
// Quad SPI: SCLK, CS#, IO0, IO1, IO2, IO3

  always @* begin
    if (state == SPI_IDLE)
             oe = 4'b0000;
    else
    case (format) // {none, none, sdr, sdr, ddrT, ddrR, qdrT, qdrR}
    3'b010:  oe = 4'b0010;
    3'b011:  oe = 4'b0010;
    3'b100:  oe = 4'b0011;
    3'b110:  oe = 4'b1111;
    default: oe = 4'b0000;
    endcase
  end

  reg [3:0] divider;
  reg [7:0] sr;
  reg [3:0] count;
  reg       phase;

// Outgoing data to the SPI flash is clocked in on the rising edge.
// The controller shifts it out on the falling edge.
// Data from SPI flash clocks out on falling edge, GD25Q16C delay = 0.7 to 8 ns.
// Use SDC constraints to make sure the qdi input can tolerate 0.7ns hold time.
// SCLK starts high and ends high.
// sclk ----------__________----------__________----------__________----------
// qdi  ...........xxxxxxxddddddddddddddd.....................................
// sample qdi here: ------------------^
// qdo  ...........oooooooooooooooooooo.......................................
// register qdo:--^
//      SPI_IDLE  |  SPI_RUN

  always @(posedge clk or negedge arstn)
  if (!arstn) begin
    divider <= 4'd0;  qdo <= 4'd0;  phase <= 1'b0;
    ready <= 1'b1;  state <= SPI_IDLE;
    sr <= 8'd0;  dout <= 8'd0;  count <= 4'd8;  sclk <= 1'b1;
  end else
    case (state)
    SPI_IDLE:
      if (wr) begin
        sr <= din;
        ready <= 1'b0;
        case (format[2:1])
        2'b10:   count <= 4'd4;
        2'b11:   count <= 4'd2;
        default: count <= 4'd8;
        endcase
        state <= SPI_RUN;
      end
    SPI_RUN:
      begin
        if (divider)
          divider <= divider - 4'd1;
        else begin
          divider <= prescale;
          if (!phase) begin
            case (format[2:1])
            2'b10:   {qdo[1:0], sr} <= {sr, qdi[1:0]};
            2'b11:   {qdo, sr}      <= {sr, qdi};
            default: {qdo[0], sr}   <= {sr, qdi[1]};
            endcase
            if (count)
              count <= count - 3'd1;
            else begin
              state <= SPI_IDLE;
              dout <= sr;
              ready <= 1'b1;
            end
          end
          if (count) sclk <= ~sclk;
          else sclk <= 1'b1;
          phase <= ~phase;
        end
      end
    default:
      state <= SPI_IDLE;
    endcase

endmodule

