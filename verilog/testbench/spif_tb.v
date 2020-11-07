// spif testbench

`timescale 1ns / 1ns

module spif_tb();

    reg	 clk = 1;
    reg	 rst_n = 0;

    // Processor interface (J1, chad, etc)
    reg			 io_rd = 0;	// I/O read strobe: get io_din	  i
    reg			 io_wr = 0;	// I/O write strobe: register din i
    reg			 mem_rd = 0;	// Data memory read enable	  i
    reg			 mem_wr = 0;	// Data memory write enable	  i
    reg	 [14:0]		 mem_addr = 0;	// Data memory address		  i
    reg	 [17:0]		 din = 0;	// Data memory & I/O in (from N)  i
    wire [17:0]		 mem_dout;	// Data memory out		  o
    wire [17:0]		 io_dout;	// I/O data out			  o
    reg	 [14:0]		 code_addr = 0;	// Code memory address		  i
    wire [15:0]		 insn;		// Code memory data		  o
    wire		 p_hold;	// Processor hold		  o
    wire		 p_reset;	// Processor reset		  o
    //	UART interface
    wire		 u_ready;	// Ready for next byte to send	  i
    wire		 u_wr;		// UART transmit strobe		  o
    wire [7:0]		 u_din;		// UART transmit data		  o
    wire		 u_full;	// UART has received a byte	  i
    wire		 u_rd;		// UART received strobe		  o
    wire [7:0]		 u_dout;	// UART received data		  i
    wire [15:0]          u_rate;        // UART baud rate divisor         o
    //	Flash Memory interface
    wire		 f_ready;	// Ready for next byte to send	  i
    wire		 f_wr;		// Flash transmit strobe	  o
    wire                 f_who;         // Who is requesting the transfer?o
    wire [7:0]		 f_dout;	// Flash transmit data		  o
    wire [2:0]		 f_format;	// Flash format			  o
    wire [3:0]		 f_rate;	// Flash configuration setup	  o
    wire [7:0]		 f_din;		// Flash received data		  i

    reg uart_rst_n = 0;  // release UART reset later than global reset

    // 100 MHz clock
    always #5 clk = ~clk;

    // spif is the SPI flash controller for the chad processor
    spif #(11, 18, 10, 0, 3, 4, 868) u0 (
	.clk(clk),
	.arstn(rst_n),
	.io_rd	  (io_rd    ),
	.io_wr	  (io_wr    ),
	.mem_rd	  (mem_rd   ),
	.mem_wr	  (mem_wr   ),
	.mem_addr (mem_addr ),
	.din	  (din	    ),
	.mem_dout (mem_dout ),
	.io_dout  (io_dout  ),
	.code_addr(code_addr),
	.insn	  (insn	    ),
	.p_hold	  (p_hold   ),
	.p_reset  (p_reset  ),
	.u_ready  (u_ready  ),
	.u_wr	  (u_wr	    ),
	.u_dout	  (u_dout   ),
	.u_full	  (u_full   ),
	.u_rd	  (u_rd	    ),
	.u_din	  (u_din    ),
	.u_rate	  (u_rate   ),
	.f_ready  (f_ready  ),
	.f_wr	  (f_wr	    ),
	.f_who	  (f_who    ),
	.f_dout	  (f_dout   ),
	.f_format (f_format ),
	.f_rate   (f_rate   ),
	.f_din	  (f_din    )
    );

    // flash simulator reads bytes from a file
    flashsim #("fdata.bin") u1 (
	.clk(clk),
	.arstn(rst_n),
	.ready	  (f_ready  ),
	.wr	  (f_wr	    ),
	.who	  (f_who    ),
	.din	  (f_dout   ),
	.format	  (f_format ),
	.prescale (f_rate   ),
	.dout	  (f_din    )
    );

    // UART simulator reads bytes from a file
    uartsim #("udata.bin") u2 (
	.clk(clk),
	.arstn(uart_rst_n),
	.ready	  (u_ready ),
	.wr	  (u_wr	   ),
	.din	  (u_dout  ),
	.full	  (u_full  ),
	.rd	  (u_rd	   ),
	.dout	  (u_din   ),
	.bitperiod(u_rate  )
    );

    // Write to i/o space
    task IO_WRITE;
      input [17:0] data;
      input  [2:0] addr;
      begin
        @(posedge clk);  io_wr <= 1'b1;  din <= data;  mem_addr <= addr;
        @(posedge clk);  io_wr <= 1'b0;
      end
    endtask // IO_WRITE

    // poll the busy flag until it's not busy
    task WAIT;
      input [2:0] addr;
      integer busy;
      begin
        busy = 1;
        while (busy) begin
          @(posedge clk);  io_rd <= 1'b1;  mem_addr <= addr;
          @(posedge clk);  io_rd <= 1'b0;
          @(posedge clk);  io_rd <= 1'b0;  busy <= io_dout[0];
        end
      end
    endtask // WAIT

    initial
    begin
	$display("Bootup started %t", $time);
	#7 rst_n = 1;
        @(negedge p_reset); // wait for boot to finish
	$display("Bootup finished %t", $time);
        mem_rd = 1;  @(posedge clk);
        mem_rd = 0;  @(posedge clk);
        IO_WRITE(42, 0);  // send a byte to the UART

        IO_WRITE(4, 4);      WAIT(4);  // 5-byte sequence to flash
        IO_WRITE(8'h81, 4);  WAIT(4);  // start SPI sequence, single rate
        IO_WRITE(8'h0B, 4);  WAIT(4);
        IO_WRITE(8'h00, 4);  WAIT(4);
        IO_WRITE(8'h00, 4);  WAIT(4);
        IO_WRITE(8'h80, 4);  WAIT(4);
        IO_WRITE(8'h00, 4);  WAIT(4);
        IO_WRITE(8'h11, 3);   // start the flash interpreter
        WAIT(5);              // wait until interpreter is finished

        uart_rst_n <= 1;
//	$display("status: %t done reset", $time);
//
//	@(posedge clk);
//
//	$display("\n\nstatus: %t Testbench done", $time);
//	$finish;
    end

endmodule

