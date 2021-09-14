// SFLASH testbench                                     10/2/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

// It's a rather sparse test, but it's enough to show waveforms.

`timescale 1ns/10ps

module sflash_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          ready;            // Ready for next byte to send      o
  reg           wr = 0;           // Flash transmit strobe            i
  reg           who = 0;          // Who's asking?                    i
  reg   [7:0]   din = 0;          // Flash transmit data              i
  reg   [2:0]   format = 2;       // Flash format                     i
  reg   [3:0]   prescale = 0;     // Flash configuration setup        i
  wire  [7:0]   dout;             // Flash received data              o

  wire          sclk;
  wire          cs_n;
  reg   [3:0]   qdi;
  wire  [3:0]   qdo;
  wire  [3:0]   oe;               // output enable for qdo

  always @* begin                 // loopback
    case (format[2:1])
    2'b10:   qdi = qdo;
    2'b11:   qdi = qdo;
    default: qdi = {2'b00, qdo[0], 1'b0};
    endcase
  end

  sflash u1 (
    .clk      (clk     ),
    .arstn    (rst_n   ),
    .ready    (ready   ),
    .wr       (wr      ),
    .who      (who     ),
    .din      (din     ),
    .format   (format  ),
    .prescale (prescale),
    .dout     (dout    ),
    .sclk     (sclk    ),
    .cs_n     (cs_n    ),
    .qdi      (qdi     ),
    .qdo      (qdo     ),
    .oe       (oe      )
  );

  // Send a byte and wait for it to echo, then read it.
  task WRITE_BYTE;
    input [7:0] data;
    input [7:0] check;
    begin
      @(posedge clk);  wr <= 1'b1;  din <= data;
      @(posedge clk);  wr <= 1'b0;
      @(posedge clk);
      @(posedge ready);
      if (dout != check)
        $display("Loopback mismatch");
    end
  endtask // WRITE_BYTE

  always #5 clk <= !clk;

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      WRITE_BYTE(8'h12, 8'h09);  format = 4;
      WRITE_BYTE(8'h34, 8'h0D);  format = 6;
      WRITE_BYTE(8'h56, 8'h05);  format = 0;
      WRITE_BYTE(8'h78, 8'h3C);  format = 2;  prescale = 1;
      WRITE_BYTE(8'h99, 8'h4C);
      #50
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
