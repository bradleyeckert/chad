
`timescale 1ns / 1ns

module flashsim
#(
parameter FILENAME = "fdata.hex"
)
(
  input wire          clk,
  input wire          arstn,            // async reset
// Flash Memory interface to spif
  output reg          ready,            // Ready for next byte to send
  input wire          wr,               // Flash transmit strobe
  input wire          who,              // Who's asking
  input wire  [7:0]   din,              // Flash transmit data
  input wire  [2:0]   format,           // Flash format
  input wire  [3:0]   prescale,         // Flash configuration setup
  output reg  [7:0]   dout              // Flash received data
);

// format is the bus format of the SPI:
// 000 = inactive (CS# = '1')
// other = active, various sizes and bus drives: SDR, DDR, QDR

  integer file;
  integer fstate;
  integer delay;
  parameter FLASH_PERIOD = 2;
  reg [23:0] faddr;

  initial
  begin
    fstate = 1;
    delay = FLASH_PERIOD;
    faddr = 24'h000000;
    ready = 1'b0;
    dout = 8'h00;
    file = $fopen(FILENAME, "rb");
  end

  always @(posedge clk) begin
    if (wr) begin
      if (ready) begin
        delay <= FLASH_PERIOD;
        ready <= 1'b0;
        case (fstate)
        0:  if (!format)              	// wait for CS# = '1'
            begin
                fstate <= 1;
                dout <= 8'hFF;
            end
        1:  if (format)               	// wait for CS# = '0'
                if (din == 8'h0B)    	// "fast read" command
                    fstate <= 2;
                else if (din == 8'h05) 	// "status" command
                    fstate <= 7;
                else
                    fstate <= 0;
        2:  begin
                faddr[23:16] <= din;
                fstate <= 3;
            end
        3:  begin
                faddr[15:8] <= din;
                fstate <= 4;
            end
        4:  begin
                faddr[7:0] <= din;
                fstate <= 5;
            end
        5:  begin
                fstate <= 6;
                if (file == 0) begin
                    $display("\nCan't open file %s\n", FILENAME);
                    fstate <= 0;
                end else begin
                    if ($fseek(file, faddr, 0) == -1) begin
                        $display("ERROR: fseek failed");
                        fstate <= 0;
                    end
                end
            end
        6:  if (!format)
                fstate <= 1;
            else begin
                dout <= $fgetc(file);
                if ($feof(file))  fstate <= 1;
            end
        7:  if (!format)
                fstate <= 1;
            else
	        dout <= 8'h00;
        default: fstate <= 0;
        endcase
      end else begin
        $display("\nERROR: Writing to a not-ready FLASH");
	$stop;
      end
    end
    else begin
      if (delay) delay <= delay - 1;
      else begin
          ready <= 1'b1;
          if (!format)  fstate <= 1;
      end
    end
  end

endmodule
