// UART testbench                                       9/29/2020 BNE

`timescale 1ns/10ps

module uart_tb();

  reg	        clk = 1;
  reg	        rst_n = 0;

  wire          ready;     	// Ready for next byte to send i
  reg           wr = 0;        	// UART transmit strobe        o
  reg  [7:0]    din = 0;      	// UART transmit data          o
  wire          full;      	// UART has received a byte    i
  reg           rd = 0;        	// UART received strobe        o
  wire  [7:0]   dout;        	// UART received data          i
  wire          rxd;            // Async input                 o
  wire          txd;

  assign rxd = txd;             // loopback

  uart u1 (
    .clk        (clk),
    .arstn      (rst_n),
    .ready      (ready),
    .wr	        (wr),
    .din	(din ),
    .full	(full),
    .rd	        (rd),
    .dout	(dout),
    .bitperiod  (16'd868),
    .rxd        (rxd),
    .txd        (txd)
  );

  // Send a byte and wait for it to echo, then read it.
  task UART_WRITE_BYTE;
    input [7:0] i_Data;
    reg   [7:0] o_Data;
    begin
      @(posedge clk);  wr <= 1'b1;  din <= i_Data;
      @(posedge clk);  wr <= 1'b0;
      @(posedge clk);
      @(posedge ready);
      @(posedge clk);  rd <= 1'b1;  o_Data <= dout;
      @(posedge clk);  rd <= 1'b0;
      if (o_Data != i_Data)
        $display("UART loopback mismatch");
    end
  endtask // UART_WRITE_BYTE

  always #5 clk <= !clk;

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      UART_WRITE_BYTE(8'h12);
      UART_WRITE_BYTE(8'h34);
      UART_WRITE_BYTE(8'h56);
      UART_WRITE_BYTE(8'h78);
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
