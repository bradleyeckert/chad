// Serial Flash Controller for Chad                  		11/6/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module spif
#(
  parameter CODE_SIZE = 10,             // log2 of # of 16-bit instruction words
  parameter WIDTH = 18,                 // word size of data memory
  parameter DATA_SIZE = 10,             // log2 of # of cells in data memory
  parameter BASEBLOCK = 0,              // first 64KB sector of user flash
  parameter PRODUCT_ID0 = 0,            // 8-bit key ID for ISP
  parameter PRODUCT_ID1 = 1,            // 16-bit product ID for ISP
  parameter UART_RATE_POR = 868,        // default UART baud rate = Fclk / this
  parameter KEY0 = 32'h0,               // flash cipher key, 0 means no cipher
  parameter KEY1 = 32'h0,               // the ISP host will need the same key
  parameter KEY_LENGTH = 56
)(
  input  wire              clk,
  input  wire              arstn,       // async reset (active low)
// Processor interface (J1, chad, etc)
  input  wire              io_rd,       // I/O read strobe: get io_din
  input  wire              io_wr,       // I/O write strobe: register din
  input  wire              mem_rd,      // Data memory read enable
  input  wire              mem_wr,      // Data memory write enable
  input  wire [14:0]       mem_addr,    // Data memory address
  input  wire [WIDTH-1:0]  din,         // Data memory & I/O in (from N)
  output wire [WIDTH-1:0]  mem_dout,    // Data memory out
  output wire [WIDTH-1:0]  io_dout,     // I/O data out
  input  wire [14:0]       code_addr,   // Code memory address
  output wire [15:0]       insn,        // Code memory data
  output wire              p_hold,      // Processor hold
  output reg               p_reset,     // Processor reset
// UART interface
  input  wire              u_ready,     // Ready for next byte to send
  output reg               u_wr,        // UART transmit strobe
  output reg  [7:0]        u_dout,      // UART transmit data
  input  wire              u_full,      // UART has received a byte
  output reg               u_rd,        // UART received strobe
  input  wire [7:0]        u_din,       // UART received data
  output reg  [15:0]       u_rate,      // UART baud rate divisor
// Flash Memory interface
  input  wire              f_ready,     // Ready for next byte to send
  output reg               f_wr,        // Flash transmit strobe
  output reg               f_who,       // Who is requesting the transfer?
  output reg  [7:0]        f_dout,      // Flash transmit data
  output reg  [2:0]        f_format,    // Flash format
  output reg  [3:0]        f_rate,      // Flash SCLK divisor
  input  wire [7:0]        f_din,       // Flash received data
// Wishbone master
  output wire [14:0]       adr_o,       // address
  output wire [31:0]       dat_o,       // data out
  input wire  [31:0]       dat_i,       // data in
  output wire              we_o,        // 1 = write, 0 = read
  output wire              stb_o,       // strobe
  input wire               ack_i,       // acknowledge
// Interrupt request strobes
  output reg               cyclev       // cycle count overflow
);

// Wishbone bus master

  wire internal = (mem_addr[14:4] == 0);// anything above 0x000F is Wishbone
  assign adr_o = mem_addr;
  assign stb_o = (io_wr | io_rd) & ~internal ;
  assign we_o = io_wr;
  wire wbbusy = stb_o & ~ack_i;         // waiting for wishbone bus
  reg [31:0] wbxo;

  assign dat_o = (WIDTH == 32) ? din : {wbxo, din}; // let it truncate

  reg [31:0] wbxi;
  always @(posedge clk or negedge arstn) begin
    if (!arstn)
      wbxi <= 'b0;
    else
      if ((!internal) && (io_rd) && (stb_o) && (ack_i))
        if (WIDTH != 32)
          wbxi <= dat_i[31:WIDTH];
  end

// Free-running cycles counter readable by the CPU. Rolls over at Fclk*2^-WIDTH
// Hz: 100 MHz, 18-bit -> 1.5 kHz. ISR[1] services the overflow.

  reg [WIDTH-1:0] cycles;
//  reg [7:0] cycles; // shorten counter to demonstrate interrupts faster
  always @(posedge clk or negedge arstn) begin
    if (!arstn)
      {cyclev, cycles} <= 0;
    else
      {cyclev, cycles} <= cycles + 1'b1;
  end

//==============================================================================
// UART input FSM
// Received data goes to uartRXbyte and uartRXfull.
// The processor can read the received character to clear uartRXfull.
//==============================================================================

  reg [7:0] uartRXbyte, ISPbyte;        // Received UART byte
  reg uartRXfull;                       // Indicate that UART is full
  reg ispActive;                        // Indicate that ISP mode is active
  reg ISPfull, ISPack;                  // Indicate ISP byte was received
  reg iobusy;

  reg [3:0] r_state;                    // UART receive state
  localparam unlockbyte0  = 8'hA5;
  localparam unlockbyte1  = 8'h5A;
  localparam UART_RX_IDLE = 4'b0001;
  localparam UART_RX_ESC  = 4'b0010;
  localparam UART_UNLOCK  = 4'b0100;
  localparam UART_UNLOCK1 = 4'b1000;

  wire u_rxok = u_full & ~u_rd;         // ok to get raw data from UART
  wire u_rxready = (ispActive) ? ~ISPfull : ~uartRXfull;

  always @(posedge clk or negedge arstn)
    if (!arstn)
      begin
        uartRXfull <= 1'b0;     u_rd <= 1'b0;
        ISPfull <= 1'b0;   ispActive <= 1'b0;
        uartRXbyte <= 8'h00;  u_rate <= UART_RATE_POR[15:0];
        ISPbyte <= 8'h00;    r_state <= UART_RX_IDLE;
      end
    else
      begin
        u_rd <= 1'b0;
        if (u_rxok)
          case (r_state)
          UART_RX_IDLE:
            if (u_din[7:2] == 6'b000100) begin
              u_rd <= 1'b1;
              case (u_din[1:0])
              2'b00: r_state <= UART_RX_ESC;
              2'b10: r_state <= UART_UNLOCK;
              endcase
            end
            else if (u_rxready) begin
              u_rd <= 1'b1;
              if (ispActive) begin
                ISPbyte <= u_din;
                ISPfull <= 1'b1;
              end else begin
                uartRXbyte <= u_din;
                uartRXfull <= 1'b1;
              end
            end
          UART_RX_ESC:
            if (u_rxready) begin        // 2-byte escape sequence: 10h, 0xh
              u_rd <= 1'b1;
              r_state <= UART_RX_IDLE;
              if (ispActive) begin
                ISPbyte <= {6'b000100, u_din[1:0]};
                ISPfull <= 1'b1;
              end else begin
                uartRXbyte <= {6'b000100, u_din[1:0]};
                uartRXfull <= 1'b1;
              end
            end
          UART_UNLOCK:
            begin
              ispActive <= 1'b0;        // any bad unlock sequence clears this
              u_rd <= 1'b1;
              if (u_din == unlockbyte0)
                r_state <= UART_UNLOCK1;
              else
                r_state <= UART_RX_IDLE;
            end
          UART_UNLOCK1:
            begin
              u_rd <= 1'b1;
              if (u_din == unlockbyte1)
                ispActive <= 1'b1;
              r_state <= UART_RX_IDLE;
            end
          default:
            r_state <= UART_RX_IDLE;
          endcase
        if (ISPack == 1'b1)
          ISPfull <= 1'b0;
        if (io_rd)
          if (!p_hold)
            case (mem_addr[2:0])        // io read clears UART receive flag
            3'b000: uartRXfull <= 1'b0;
            endcase
        if (io_wr)
          if (!p_hold)
            case (mem_addr[2:0])
            3'b010: u_rate <= din[15:0];// set UART baud rate
            3'b100:                     // jam an ISP byte
              {ISPbyte, ISPfull} <= {din[7:0], 1'b1};
            endcase
      end

  reg  [2:0] b_state;                   // boot FSM state
  wire booting = (b_state) ? 1'b1 : 1'b0;
  wire txbusy = ~u_ready;
  reg [WIDTH-1:0] spif_dout;

  always @* begin                       // i/o read mux
    case (mem_addr[2:0])                // Verilog zero-extends smaller vectors
    3'b000:  spif_dout = uartRXbyte;    // char
    3'b001:  spif_dout = uartRXfull;    // char is in the buffer
    3'b010:  spif_dout = txbusy;        // EMIT is busy?
    3'b011:  spif_dout = f_din;         // flash SPI result
    3'b100:  spif_dout = ISPfull;       // jammed byte is still pending
    3'b101:  spif_dout = booting;       // still reading flash?
    3'b110:  spif_dout = cycles;        // free-running counter
    3'b111:  spif_dout = wbxi;          // Wishbone bus extra input bits
    endcase
  end

  assign io_dout = (internal) ? spif_dout : dat_i[WIDTH-1:0];

  reg [2:0] i_usel;                     // UART output select for ISP
  reg [7:0] u_txbyte;                   // manual UART output
  always @* begin                       // UART output mux
    if (ispActive)
      case (i_usel[2:0])
      3'b000:  u_dout <= 8'hAA;         // sanity check
      3'b001:  u_dout <= PRODUCT_ID1[15:8];
      3'b010:  u_dout <= PRODUCT_ID1[7:0];
      3'b011:  u_dout <= PRODUCT_ID0[7:0];
      3'b100:  u_dout <= BASEBLOCK[7:0];
      default: u_dout <= f_din;
      endcase
    else  u_dout <= u_txbyte;
  end

  always @* begin                       // insert i/o wait states
    if (io_wr) begin
      case (mem_addr[2:0])
      3'b000:  iobusy = txbusy;         // UART output
      3'b100:  iobusy = ISPfull;        // SPI flash byte-banging
      default: iobusy = 1'b0;
      endcase
    end else
      iobusy = 1'b0;
  end

//==============================================================================
// Shared variables between ISP and gecko
//==============================================================================

  reg [11:0] i_count;                   // ISP repeat counter
  reg g_load, g_reset_n;                // gecko control strobes

//==============================================================================
// Key generation for gecko.v cipher
// The cipher secures code and data in off-chip SPI flash to some degree.
//==============================================================================

  reg [KEY_LENGTH-1:0] widekey;         // 0 = no cipher
  reg [5:0] key_index;

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      key_index <= KEY_LENGTH - 1;
      widekey <= {KEY0[KEY_LENGTH-33:0], KEY1[31:0]};
    end else begin
      if (g_reset_n) begin
        if (g_load)                     // shift in a key digit:
          widekey <= {widekey[KEY_LENGTH - 13 : 0], i_count};
        else if (key_index) begin
          key_index <= key_index - 1'b1;
          widekey <= {1'b0, widekey[KEY_LENGTH - 1 : 1]};
        end
      end else
        key_index <= KEY_LENGTH - 1;
    end

  wire g_ready;                         // g_dout is ready
  wire [7:0] g_dout;                    // gecko PRNG byte
  reg g_next;                           // trigger next byte
  wire [7:0] plain = f_din ^ g_dout;    // plaintext version of SPI flash

  gecko #(KEY_LENGTH) cipher (
    .clk        (clk),
    .rst_n      (g_reset_n),
    .clken      (1'b1),
    .ready      (g_ready),
    .next       (g_next),
    .key        (widekey[0]),
    .dout	(g_dout)
  );

//==============================================================================
// Boot Loader and ISP FSM
// The boot loader can be disabled by forcing CS# high with a jumper so it
// reads blank.
//==============================================================================

  localparam FAST_READ = 8'h0B;
  reg [15:0] b_count;                   // length of byte run
  reg [15:0] b_dest;                    // address register for bootup
  reg [WIDTH-1:0] b_data;
  reg codeWr, dataWr;
  reg [1:0] bytes, bytecount;           // bytes per b_data word
  reg bumpDest;                         // trigger address bump
  reg [2:0] b_mode;                     // boot interpreter mode

  reg [3:0] i_state;
  localparam ISP_IDLE =   4'b0001;
  localparam ISP_UPLOAD = 4'b0010;
  localparam ISP_DNLOAD = 4'b0100;
  localparam ISP_PING =   4'b1000;

  wire b_rxok = ISPfull & ~ISPack;
  wire b_txok = u_ready & ~u_wr;
  wire f_ok = f_ready & ~f_wr & g_ready;
  reg init;                             // init memory

// Boot mode FSM
  always @(posedge clk or negedge arstn)
    if (!arstn) begin                   // async reset
      f_dout <= 8'h00;    f_wr <= 1'b0;      f_who <= 1'b0;
      b_dest <= 16'd0;    f_rate <= 4'h7;    wbxo <= 0;
      b_count <= 16'd0;   b_data <= 0;       ISPack <= 1'b0;
      b_mode <= 3'd0;     bumpDest <= 1'b0;  i_state <= ISP_PING;
      bytes  <= 2'd0;     dataWr <= 1'b0;    i_usel <= 3'd5;
      bytecount <= 2'd0;  codeWr <= 1'b0;    g_next <= 1'b0;
      b_state <= 3'd1;    f_format <= 3'd0;  g_load <= 1'b0;
      p_reset <= 1'b1;    u_wr <= 1'b0;      g_reset_n <= 1'b0;
      u_txbyte <= 8'h5B;  // power-up output character
      init <= 1'b1;       i_count <= (1 << CODE_SIZE) - 1;
    end else begin
      codeWr <= 1'b0;                   // strobes
      dataWr <= 1'b0;
      bumpDest <= 1'b0;
      g_next <= 1'b0;
      g_load <= 1'b0;
      g_reset_n <= 1'b1;
      if (init) begin
        codeWr <= 1'b1;                 // clear RAMs
        dataWr <= 1'b1;
        bumpDest <= 1'b1;
        if (i_count) i_count <= i_count - 12'd1;
        else init <= 1'b0;
      end else begin
        u_wr <= 1'b0;
        case (b_state)
          3'b000 : f_dout <= ISPbyte;
          3'b001 : f_dout <= FAST_READ;
          3'b010 : f_dout <= BASEBLOCK[7:0];
          default: f_dout <= 8'h00;
        endcase
        ISPack <= 1'b0;
        f_wr <= 1'b0;
        if (f_ok) begin
          f_wr <= 1'b1;
          f_who <= 1'b0;
          if (b_state == 3'd1)  f_format <= 3'b010;
          case (b_state)
          3'b000:
            begin
              f_wr <= 1'b0;             // ========== Interpret ISP bytes
              f_who <= 1'b1;
              case (i_state)
              ISP_IDLE:
                if (b_rxok) begin
                  ISPack <= 1'b1;
                  case (ISPbyte[7:6])
                  2'b00:          	// set 12-bit run length
                    i_count <= {i_count[5:0], ISPbyte[5:0]};
                  2'b01:          	// various strobes
                    begin
                      p_reset <= ISPbyte[0];
                      if (ISPbyte[1]) begin
                        i_state <= ISP_PING;
                        i_count <= 12'd3;
                      end
                      if (ISPbyte[2])
                        b_state <= 3'd1;// reboot from flash
                      g_load <= ISPbyte[3];
                      g_reset_n <= ~ISPbyte[4];
                    end
                  2'b10:          	// send a run of bytes to flash
                    begin
                      if (ISPbyte[2:0]) // upload if there is a format
                        i_state <= ISP_UPLOAD;
                      f_format <= ISPbyte[2:0];
                    end
                  2'b11:          	// read a run of bytes from flash
                    begin
                      i_state <= ISP_DNLOAD;
                      f_format <= ISPbyte[2:0];
                      f_wr <= 1'b1;     // start a transfer by sending 0xC2
                    end
                  endcase
                end
              ISP_UPLOAD:
                if (b_rxok) begin
                  ISPack <= 1'b1;
                  f_wr <= 1'b1; 	// UART --> flash
                  if (i_count) i_count <= i_count - 12'd1;
                  else i_state <= ISP_IDLE;
                end
              ISP_DNLOAD:
                if (b_txok) begin
                  u_wr <= 1'b1;         // flash --> UART
          	  i_usel <= 3'd5;
                  if (i_count) begin
                    i_count <= i_count - 12'd1;
                    f_wr <= 1'b1;
                  end
                  else i_state <= ISP_IDLE;
                end
              ISP_PING:
                if (b_txok) begin
                  u_wr <= 1'b1;
          	  i_usel <= i_count[2:0];
                  if (i_count) i_count <= i_count - 12'd1;
                  else i_state <= ISP_IDLE;
                end
              default:
                i_state <= ISP_IDLE;
              endcase
            end
          3'b111:                       // ========== Interpret flash bytes
            begin
              g_next <= 1'b1;
              case (b_mode[2:1])        // what kind of byte is it?
              2'b00:                    // 00x = command
                case (plain[7:6])
                2'b11:               	// blank = "end"
                  begin
                    if (plain[5]) begin
                      f_wr <= 1'b0;
                      f_format <= 3'd0;	// raise CS#
                      p_reset  <= plain[4];
                      b_state  <= 3'd0; // reset FSM
                    end else
                      b_mode <= {1'b1, plain[1:0]};
                  end
                2'b10:               	// SCLK frequency
                  begin
          	  f_rate <= plain[3:0];
                  end
                default:             	// data mode
                  begin
                    b_mode <= {2'b01, plain[2]};
                    bytes <= plain[1:0];
                    bytecount <= plain[1:0];
                  end
                endcase
              2'b01:                    // 01x = write to memory
                begin
                  b_data <= {b_data[WIDTH-9:0], plain};
                  if (bytecount)
                    bytecount <= bytecount - 2'd1;
                  else
                    begin
                      bytecount <= bytes;
                      codeWr <= ~b_mode[0];
                      dataWr <=  b_mode[0];
                      bumpDest <= 1'b1;
                      if (b_count)  b_count <= b_count - 16'd1;
                      else          b_mode <= 3'd0;
                    end
                end
              2'b10:                    // 10x = set destination address
                if (b_mode[0]) begin
                  b_dest[15:8] <= plain;   b_mode[0] <= 1'b0;
                end else begin
                  b_dest[7:0] <= plain;    b_mode <= 3'd0;
                end
              default:                  // 11x = set data length
                if (b_mode[0]) begin
                  b_count[15:8] <= plain;  b_mode[0] <= 1'b0;
                end else begin
                  b_count[7:0] <= plain;   b_mode <= 3'd0;
                end
              endcase
            end
          default:
            b_state <= b_state + 3'd1;
          endcase
        end
      end
      if (bumpDest)
        b_dest <= b_dest + 16'd1;
      if (io_wr)
        if (!p_hold)
          if (internal)
            case (mem_addr[2:0])
            3'b000: begin
                u_wr <= 1'b1;             // write to UART
       	        i_usel <= 3'd5;
                u_txbyte <= din[7:0];
              end
            3'b011: b_state <= 3'd6;      // interpret flash byte stream
            3'b111:
              if (WIDTH != 32) wbxo <= din[31-WIDTH:0];
            endcase
    end

// The Data and Code RAMs are accessed via DMA by the boot process.
// The bootloader writes to either code or data RAM.
// p_hold inhibits reads to keep the read streams in sync with their addresses.

  assign p_hold = codeWr | dataWr | iobusy | wbbusy;
  wire code_rd = ~p_hold;
  wire [CODE_SIZE-1:0] code_ia =
       (codeWr) ? b_dest[CODE_SIZE-1:0] : code_addr[CODE_SIZE-1:0];

  wire data_rd = mem_rd & ~p_hold;
  wire data_wr = mem_wr | dataWr;
  wire [DATA_SIZE-1:0] data_ia = (dataWr) ? b_dest[DATA_SIZE-1:0]
                                          : mem_addr[DATA_SIZE-1:0];
  wire [WIDTH-1:0]    data_din = (dataWr) ? b_data : din;

//=======================================
// Data RAM
//=======================================
spram
#(
  .ADDR_WIDTH (DATA_SIZE),
  .DATA_WIDTH (WIDTH)
) data_ram
(
  .clk  ( clk      ),
  .addr ( data_ia  ),
  .din  ( data_din ),
  .dout ( mem_dout ),
  .we   ( data_wr  ),
  .re   ( data_rd  )
);

//=======================================
// Code RAM
//=======================================
spram
#(
  .ADDR_WIDTH (CODE_SIZE),
  .DATA_WIDTH (16)
) code_ram
(
  .clk  ( clk      ),
  .addr ( code_ia  ),
  .din  ( b_data[15:0]),
  .dout ( insn     ),
  .we   ( codeWr   ),
  .re   ( code_rd  )
);

endmodule
