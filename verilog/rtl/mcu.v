// Minimal MCU based on J1-type CPU                             10/29/2020 BNE
// License: This code is a gift to the divine.

// This is expected to be wrapped by an I/O ring that steers bidirectional
// signals, conditions the reset signal, and supplies a clock.

`default_nettype none
module mcu
#(
  parameter WIDTH = 18,
  parameter URATE = 32                  // 96 MHz / 32 = 3MBPS baud rate
)(
  input wire               clk,         // target frequency is 96 MHz
  input wire               rst_n,
// 6-wire connection to SPI flash chip
  output wire              sclk,
  output wire              cs_n,
  input wire   [3:0]       qdi,
  output wire  [3:0]       qdo,
  output wire  [3:0]       oe,          // output enable for qdo
// UART connection
  input wire               rxd,         // Async input
  output wire              txd
);

  // Processor interface (J1, chad, etc)
  wire                io_rd;            // I/O read strobe: get io_din    i
  wire                io_wr;            // I/O write strobe: register din i
  wire                mem_rd;           // Data memory read enable        i
  wire                mem_wr;           // Data memory write enable       i
  wire [14:0]         mem_addr;         // Data memory & I/O address      i
  wire [WIDTH-1:0]    din;              // Data memory & I/O in (from N)  i
  wire [WIDTH-1:0]    mem_dout;         // Data memory out                o
  wire [WIDTH-1:0]    io_dout;          // I/O data out                   o
  wire [14:0]         code_addr;        // Code memory address            i
  wire [15:0]         insn;             // Code memory data               o
  wire                p_hold;           // Processor hold                 o
  wire                p_reset;          // Processor reset                o
  // UART interface
  wire                u_ready;          // Ready for next byte to send    i
  wire                u_wr;             // UART transmit strobe           o
  wire [7:0]          u_din;            // UART transmit data             o
  wire                u_full;           // UART has received a byte       i
  wire                u_rd;             // UART received strobe           o
  wire [7:0]          u_dout;           // UART received data             i
  // Flash Memory interface
  wire                f_ready;          // Ready for next byte to send    i
  wire                f_wr;             // Flash transmit strobe          o
  wire                f_who;            // Who is requesting the transfer?o
  wire [7:0]          f_dout;           // Flash transmit data            o
  wire [2:0]          f_format;         // Flash format                   o
  wire [3:0]          f_rate;           // Flash configuration setup      o
  wire [7:0]          f_din;            // Flash received data            i

  wire p_reset_n = ~p_reset;
  wire                irq;              // Interrupt request              i
  wire [3:0]          ivec;             // Interrupt vector for irq       i
  wire                iack;             // Interrupt acknowledge          o


// chad processor
  chad #(WIDTH) CPU (
    .clk      (clk      ),
    .resetq   (p_reset_n),
    .hold     (p_hold   ),
    .io_rd    (io_rd    ),
    .io_wr    (io_wr    ),
    .mem_rd   (mem_rd   ),
    .mem_wr   (mem_wr   ),
    .mem_addr (mem_addr ),
    .dout     (din      ),
    .mem_din  (mem_dout ),
    .io_din   (io_dout  ),
    .code_addr(code_addr),
    .insn     (insn     ),
    .irq      (irq      ),
    .ivec     (ivec     ),
    .iack     (iack     )
  );

// Interrupts

  wire cyclev;                          // raw cycle counter overflow
  wire urxirq;                          // UART full strobe
  wire utxirq;                          // UART ready strobe
  reg [15:0] ipending;                  // up to 15 interrupts available

  prio_enc #(4) pe (.a(ipending), .y(ivec));
  assign irq = (ivec != 0);

// Handle interrupt request strobes, edges, etc.
  always @(negedge p_reset_n or posedge clk)
  begin
    if (!p_reset_n) begin
      ipending <= 0;
    end else begin
      ipending[1] <= ipending[1] | cyclev;
      ipending[2] <= ipending[2] | utxirq;
      ipending[3] <= ipending[3] | urxirq;
      if (iack)   ipending[ivec] <= 1'b0;
    end
  end

// Wishbone master
  wire [14:0] adr_o;
  wire [31:0] dat_o, dat_i;
  wire we_o, stb_o, ack_i;

  wire io_spif = (mem_addr[6:3] == 0);
  wire s_iord = io_spif & io_rd;
  wire s_iowr = io_spif & io_wr;
  wire [WIDTH-1:0] s_io_dout;

  assign io_dout = s_io_dout;           // spif is the only I/O device

// spif is the SPI flash controller for the chad processor
// 2048 words of code, 2048 words of data
  spif #(11, WIDTH, 11, 0, 0, 0) bridge (
  // spif #(11, WIDTH, 11, 0, 1, 0, 24'h123456, 32'h87654321) u1 (
    .clk      (clk      ),
    .arstn    (rst_n    ),
    .io_rd    (s_iord   ),
    .io_wr    (s_iowr   ),
    .mem_rd   (mem_rd   ),
    .mem_wr   (mem_wr   ),
    .mem_addr (mem_addr ),
    .din      (din      ),
    .mem_dout (mem_dout ),
    .io_dout  (s_io_dout),
    .code_addr(code_addr),
    .insn     (insn     ),
    .p_hold   (p_hold   ),
    .p_reset  (p_reset  ),
    .u_ready  (u_ready  ),
    .u_wr     (u_wr     ),
    .u_dout   (u_dout   ),
    .u_full   (u_full   ),
    .u_rd     (u_rd     ),
    .u_din    (u_din    ),
    .f_ready  (f_ready  ),
    .f_wr     (f_wr     ),
    .f_who    (f_who    ),
    .f_dout   (f_dout   ),
    .f_format (f_format ),
    .f_rate   (f_rate   ),
    .f_din    (f_din    ),
    .adr_o    (adr_o    ),
    .dat_o    (dat_o    ),
    .dat_i    (dat_i    ),
    .we_o     (we_o     ),
    .stb_o    (stb_o    ),
    .ack_i    (ack_i    ),
    .cyclev   (cyclev   ),
    .urxirq   (urxirq   ),
    .utxirq   (utxirq   )
  );

// Convert SPI flash connection to a byte stream
  sflash SPIflash (
    .clk      (clk      ),
    .arstn    (rst_n    ),
    .ready    (f_ready  ),
    .wr       (f_wr     ),
    .who      (f_who    ),
    .din      (f_dout   ),
    .format   (f_format ),
    .prescale (f_rate   ),
    .dout     (f_din    ),
    .sclk     (sclk     ),
    .cs_n     (cs_n     ),
    .qdi      (qdi      ),
    .qdo      (qdo      ),
    .oe       (oe       )
  );

  wire rxd_s;

// synchronize UART input
  cdc rxd_cdc (.clk(clk), .a(rxd), .y(rxd_s));

// Convert 2-wire UART connection to a byte stream
  uart UART (
    .clk      (clk     ),
    .arstn    (rst_n   ),
    .ready    (u_ready ),
    .wr       (u_wr    ),
    .din      (u_dout  ),
    .full     (u_full  ),
    .rd       (u_rd    ),
    .dout     (u_din   ),
    .bitperiod(URATE[15:0]),
    .rxd      (rxd_s   ),
    .txd      (txd     )
  );

// Put your Wishbone peripherals here.
// For testing, we loop back stb_o to ack_i.

  reg [31:0] wbreg;
  reg stb_od;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wbreg <= 'b0;
    else begin
      if ((stb_o) && (we_o))
        wbreg <= dat_o;
      stb_od <= stb_o; // delayed stb
    end
  end

  assign dat_i = wbreg;
  assign ack_i = stb_od;

endmodule
