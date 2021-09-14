
`timescale 1ns / 1ns

module uartsim
#(
parameter FILENAME = "udata.hex"
)
(
  input wire          	clk,
  input wire    	arstn,  	// async reset
// Simulated UART for spif
  output reg            ready,     	// Ready for next byte to send
  input wire            wr,        	// UART transmit strobe
  input wire  [7:0]     din,      	// UART transmit data
  output reg            full,      	// UART has received a byte
  input wire            rd,        	// UART received strobe
  output reg  [7:0]     dout,        	// UART received data
  input wire  [15:0]    bitperiod       // Clocks per serial bit
);

  parameter CHAR_TX_PERIOD = 4;
  parameter CHAR_RX_PERIOD = 4;
  wire ischar = (din[6:5]) ? ~din[7] : 1'b0;

  integer txdelay;
  always @(posedge clk, negedge arstn)
    if (!arstn) begin
      ready <= 1'b1;
      txdelay <= 0;
    end else begin
      if (wr)
	if (ready) begin
	  ready <= 1'b0;
	  txdelay <= CHAR_TX_PERIOD;
	  if (ischar)
            $display("uout:%c", din);
	  else
	    case (din)
            8'h0A: $display("\r");
            8'h0D: $display("\n");
            default: $display("[%x]", din);
	    endcase
	end else begin
          $display("\nERROR: Writing to a not-ready UART at %0t", $time);
	  $stop;
	end
      else if (txdelay) txdelay <= txdelay - 1;
      else ready <= 1'b1;
    end

  integer file;
  initial
    begin
      file <= $fopen(FILENAME, "rb");
    end

  integer rxdelay;
  integer rdnext;
  always @(posedge clk, negedge arstn)
    if (!arstn) begin
      full <= 1'b0;
      rxdelay <= CHAR_RX_PERIOD;
      dout <= 8'h00;  rdnext <= 1;
    end else begin
      if (rd)
	if (!full) begin
          $display("\nERROR: UART receive underflow at %0t", $time);
	  $stop;
	end else begin
	  full <= 1'b0;
	  rdnext <= 1;
	  rxdelay <= CHAR_RX_PERIOD;
	end
      else if (rxdelay)
        rxdelay <= rxdelay - 1;
      else if (rdnext)
        if (file) begin
          dout <= $fgetc(file);
          if ($feof(file)) begin
              $fclose(file);
              file <= 0;
          end else begin
	    full <= 1'b1;
            $display("uin:%X at %0t", dout, $time);
	    rdnext <= 0;
	  end
	end
    end

endmodule
