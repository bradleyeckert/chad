// MCU based on J1-type CPU                             12/15/2020 BNE
// This code is a gift to the divine.

// This is expected to be wrapped by an I/O ring that steers bidirectional
// signals, conditions the reset signal, and supplies a clock.

`default_nettype none
module mcu
#(
  parameter BASEBLOCK = 0,              // First 64K block of flash
  parameter URATE = 32,                 // 96 MHz / 32 = 3MBPS baud rate
  parameter WIDTH = 24,                 // data cell size in bits
  parameter CODE_SIZE = 12,             // log2 of # of 16-bit instruction words
  parameter DATA_SIZE = 10,             // log2 of # of cells in data memory
  parameter IRQS = 2                    // interrupt requests (up to 12)
)(
  input wire               clk,
  input wire               rst_n,
// 6-wire connection to SPI flash chip
  output wire              sclk,
  output wire              cs_n,
  input wire   [3:0]       qdi,
  output wire  [3:0]       qdo,
  output wire  [3:0]       qoe,         // output enable for qdo
// UART connection
  input wire               rxd,         // async input
  output wire              txd,
// Wishbone Alice
  output wire  [14:0]      adr_o,       // address
  output wire  [31:0]      dat_o,       // data out
  input wire   [31:0]      dat_i,       // data in
  output wire              we_o,        // 1 = write, 0 = read
  output wire              stb_o,       // strobe
  input wire               ack_i,       // acknowledge
// Interrupt request strobes
  input wire  [IRQS-1:0]   irqs
);

  localparam PID = 0;                   // product ID
  localparam KEY_LENGTH = 7;

// Processor interface (J1, chad, etc)
  wire                 io_rd;           // I/O read strobe: get io_din    i
  wire                 io_wr;           // I/O write strobe: register din i
  wire                 mem_rd;          // Data memory read enable        i
  wire                 mem_wr;          // Data memory write enable       i
  wire [14:0]          mem_addr;        // Data memory & I/O address      i
  wire [WIDTH-1:0]     din;             // Data memory & I/O in (from N)  i
  wire [WIDTH-1:0]     mem_dout;        // Data memory out                o
  wire [WIDTH-1:0]     io_dout;         // I/O data out                   o
  wire [14:0]          code_addr;       // Code memory address            i
  wire [15:0]          insn;            // Code memory data               o
  wire                 p_hold;          // Processor hold                 o
  wire                 p_reset;         // Processor reset                o
// UART interface
  wire                 u_ready;         // Ready for next byte to send    i
  wire                 u_wr;            // UART transmit strobe           o
  wire [7:0]           u_din;           // UART transmit data             o
  wire                 u_full;          // UART has received a byte       i
  wire                 u_rd;            // UART received strobe           o
  wire [7:0]           u_dout;          // UART received data             i
// Flash Memory interface
  wire                 f_ready;         // Ready for next byte to send    i
  wire                 f_wr;            // Flash transmit strobe          o
  wire [7:0]           f_dout;          // Flash transmit data            o
  wire [2:0]           f_format;        // Flash format                   o
  wire [3:0]           f_rate;          // Flash configuration setup      o
  wire [7:0]           f_din;           // Flash received data            i

  wire p_reset_n = ~p_reset;
  wire                 irq;             // Interrupt request              i
  wire [3:0]           ivec;            // Interrupt vector for irq       i
  wire                 iack;            // Interrupt acknowledge          o

  wire                 copgo;           // Coprocessor trigger            i
  wire [WIDTH-1:0]     cop;             // Coprocessor output             o
  wire [WIDTH-1:0]     copa;            // Coprocessor A input            i
  wire [WIDTH-1:0]     copb;            // Coprocessor B input            i
  wire [WIDTH-1:0]     copc;            // Coprocessor C input            i

// Coprocessor is instantiated outside of the processor

  coproc #(WIDTH) coprocessor (.clk(clk), .arstn(rst_n), .sel(insn[10:0]),
    .go(copgo), .y(cop), .a(copa), .b(copb), .c(copc));

// Boot key
// In an ASIC, you would provide these from a MTP or OTP ROM and associate
// them with a KDF when programming.

  wire [KEY_LENGTH*8-1:0] key = 1;      // demo key
  wire [23:0]          sernum = 0;      // serial number or HW revision

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
    .iack     (iack     ),
    .copgo    (copgo    ),
    .cop      (cop      ),
    .copa     (copa     ),
    .copb     (copb     ),
    .copc     (copc     )
  );

// Memory: In this case, a couple of single-port RAMs.

  wire [DATA_SIZE-1:0] data_a;          // Data RAM read/write address
  wire [WIDTH-1:0]     data_din;        // Data RAM write data
  wire                 data_wr;         // Data RAM write enable
  wire                 data_rd;         // Data RAM read enable

  spram #(DATA_SIZE, WIDTH) data_ram (
    .clk      (clk      ),
    .addr     (data_a   ),
    .din      (data_din ),
    .dout     (mem_dout ),
    .we       (data_wr  ),
    .re       (data_rd  )
  );

  wire [CODE_SIZE-1:0] code_a;          // Code RAM read/write address
  wire [15:0]          code_din;        // Code RAM write data
  wire                 code_wr;         // Code RAM write enable
  wire                 code_rd;         // Code RAM read enable

  spram #(CODE_SIZE, 16) code_ram (
    .clk      (clk      ),
    .addr     (code_a   ),
    .din      (code_din ),
    .dout     (insn     ),
    .we       (code_wr  ),
    .re       (code_rd  )
  );

// Interrupts

  wire cyclev;                          // raw cycle counter overflow
  wire urxirq;                          // UART full strobe
  wire utxirq;                          // UART ready strobe
  reg [15:0] ipending;                  // up to 15 interrupts available

  prio_enc #(4) pe (.a(ipending), .y(ivec));
  assign irq = (ivec != 0);

// Handle interrupt request strobes

  always @(negedge p_reset_n or posedge clk)
  begin
    if (!p_reset_n) begin
      ipending <= 0;
    end else begin
      ipending[1] <= ipending[1] | cyclev;
      ipending[2] <= ipending[2] | utxirq;
      ipending[3] <= ipending[3] | urxirq;
      ipending[IRQS+3:4] <= ipending[IRQS+3:4] | irqs;
      if (iack)   ipending[ivec] <= 1'b0;
    end
  end

// spif is the SPI flash controller and ISP hub
  spif #(CODE_SIZE, WIDTH, DATA_SIZE, BASEBLOCK, PID, KEY_LENGTH) bridge (
    .clk      (clk      ),
    .arstn    (rst_n    ),
    .io_rd    (io_rd    ),
    .io_wr    (io_wr    ),
    .mem_rd   (mem_rd   ),
    .mem_wr   (mem_wr   ),
    .mem_addr (mem_addr ),
    .din      (din      ),
    .io_dout  (io_dout  ),
    .code_addr(code_addr),
    .p_hold   (p_hold   ),
    .p_reset  (p_reset  ),
    .data_a   (data_a   ),
    .data_din (data_din ),
    .data_wr  (data_wr  ),
    .data_rd  (data_rd  ),
    .code_a   (code_a   ),
    .code_din (code_din ),
    .code_wr  (code_wr  ),
    .code_rd  (code_rd  ),
    .key      (key      ),
    .sernum   (sernum   ),
    .ISPenable (1'b1    ),
    .u_ready  (u_ready  ),
    .u_wr     (u_wr     ),
    .u_dout   (u_dout   ),
    .u_full   (u_full   ),
    .u_rd     (u_rd     ),
    .u_din    (u_din    ),
    .f_ready  (f_ready  ),
    .f_wr     (f_wr     ),
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
    .din      (f_dout   ),
    .format   (f_format ),
    .prescale (f_rate   ),
    .dout     (f_din    ),
    .sclk     (sclk     ),
    .cs_n     (cs_n     ),
    .qdi      (qdi      ),
    .qdo      (qdo      ),
    .oe       (qoe      )
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

endmodule
`default_nettype wire
