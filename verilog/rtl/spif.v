// Serial Flash Controller for Chad                  		11/15/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module spif
#(
  parameter CODE_SIZE = 10,             // log2 of # of 16-bit instruction words
  parameter WIDTH = 18,                 // word size of data memory
  parameter DATA_SIZE = 10,             // log2 of # of cells in data memory
  parameter BASEBLOCK = 0,              // first 64KB sector of user flash
  parameter PRODUCT_KEY = 0,            // 8-bit key ID for ISP
  parameter PRODUCT_ID = 1,             // 16-bit product ID for ISP
  parameter STWIDTH = 9,                // Width of outgoing stream data
  parameter BKEY_HI = 0,                // flash cypher key, 0 means no cypher
  parameter BKEY_LO = 0,                // the ISP host will need the same key
  parameter KEY_LENGTH = 7
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
// User stream output (from flash or processor)
  output reg [STWIDTH-1:0] st_o,        // stream output data
  output wire              st_stb,      // stream strobe
  input wire               st_busy,     // 1 = not ready for st_stb
// Interrupt requests
  output reg               cyclev,      // cycle count overflow strobe
  output wire              urxirq,      // UART full strobe
  output wire              utxirq       // UART ready strobe
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
  wire txbusy = ~u_ready | ispActive;   // tell CPU that TX is busy

  reg [3:0] r_state;                    // UART receive state
  localparam unlockbyte0  = 8'hA5;
  localparam unlockbyte1  = 8'h5A;
  localparam UART_RX_IDLE = 4'b0001;
  localparam UART_RX_ESC  = 4'b0010;
  localparam UART_UNLOCK  = 4'b0100;
  localparam UART_UNLOCK1 = 4'b1000;

  wire u_rxok = u_full & ~u_rd;         // ok to get raw data from UART
  wire u_rxready = (ispActive) ? ~ISPfull : ~uartRXfull;
  reg uartRXfull_d;
  assign urxirq = uartRXfull & ~uartRXfull_d;

  always @(posedge clk or negedge arstn)
    if (!arstn)
      begin
        uartRXfull <= 1'b0;     u_rd <= 1'b0;
        ISPfull <= 1'b0;   ispActive <= 1'b0;
        uartRXbyte <= 8'h00;   uartRXfull_d <= 1'b0;
        ISPbyte <= 8'h00;    r_state <= UART_RX_IDLE;
      end
    else
      begin
        uartRXfull_d <= uartRXfull;
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
            3'b100:                     // jam an ISP byte
              {ISPbyte, ISPfull} <= {din[7:0], 1'b1};
            endcase
      end

  reg [2:0] b_state;                    // boot FSM state
  reg [2:0] i_usel;                     // UART output select for ISP
  reg [WIDTH-1:0] outword;              // general purpose output word
  always @* begin                       // UART output mux
    if (ispActive)
      case (i_usel[2:0])                // ping response:
      3'b000:  u_dout <= 8'hAA;         // 'tis a ping
      3'b001:  u_dout <= PRODUCT_ID[15:8];
      3'b010:  u_dout <= PRODUCT_ID[7:0];
      3'b011:  u_dout <= PRODUCT_KEY[7:0];
      3'b100:  u_dout <= BASEBLOCK[7:0];
      default: u_dout <= f_din;
      endcase
    else  u_dout <= outword[7:0];
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

  reg txbusy_d;
  assign utxirq = ~txbusy & txbusy_d;   // falling txbusy

  always @(posedge clk or negedge arstn)
    if (!arstn)
      txbusy_d <= 1'b0;
    else
      txbusy_d <= txbusy;

//==============================================================================
// Shared variables between ISP and gecko
//==============================================================================

  reg [11:0] i_count;                   // ISP repeat counter
  reg g_load, g_reset_n;                // gecko control strobes

//==============================================================================
// Key generation for gecko.v cypher
// The cypher secures code and data in off-chip SPI flash if you use it right.
// "I know what you're thinking: Why, oh why, didn't I take the blue pill?"
//==============================================================================

  reg [KEY_LENGTH*8-1:0] widekey;       // 0 = no cypher
  reg [3:0] key_index;

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      key_index <= KEY_LENGTH - 1;
      widekey <= {BKEY_HI[KEY_LENGTH*8-33:0], BKEY_LO[31:0]};
    end else begin
      if (g_reset_n) begin
        if (g_load)                     // shift in a key digit:
          widekey <= {widekey[KEY_LENGTH*8 - (WIDTH+1) : 0], outword};
        else if (key_index) begin       // shift out a byte
          key_index <= key_index - 1'b1;
          widekey <= {8'b0, widekey[KEY_LENGTH*8 - 1 : 8]};
        end
      end else
        key_index <= KEY_LENGTH - 1;    // sync reset
    end

  wire g_ready;                         // g_dout is ready
  wire [7:0] g_dout;                    // gecko PRNG byte
  reg g_next;                           // trigger next byte
  wire [7:0] plain = f_din ^ g_dout;    // plaintext version of SPI flash

  gecko #(KEY_LENGTH) cypher (
    .clk        (clk),
    .rst_n      (g_reset_n),
    .clken      (1'b1),
    .ready      (g_ready),
    .next       (g_next),
    .key        (widekey[7:0]),
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
  reg [3:0] b_mode;                     // boot interpreter mode
  reg [1:0] st_new;                     // stream triggers
  assign st_stb = st_new[0];

  reg [3:0] i_state;
  localparam ISP_IDLE =   4'b0001;
  localparam ISP_UPLOAD = 4'b0010;
  localparam ISP_DNLOAD = 4'b0100;
  localparam ISP_PING =   4'b1000;

  wire b_rxok = ISPfull & ~ISPack;      // okay to process UART input
  wire b_txok = u_ready & ~u_wr;        // okay to send to UART
  wire st_ready = ~(st_busy & (bytecount == 0)); // blocked on last flash byte
  wire f_ok = f_ready & ~f_wr & g_ready & st_ready;
  reg init;                             // initialize memory at POR

// Strobes to trigger writes

  wire codeAddrS = (mem_addr[2:0] == 3'b001) & io_wr & internal & ~p_hold;
  wire codeDataS = (mem_addr[2:0] == 3'b010) & io_wr & internal & ~p_hold;

// Boot mode FSM
  always @(posedge clk or negedge arstn)
    if (!arstn) begin                   // async reset
      f_dout <= 8'h00;    f_wr <= 1'b0;      f_who <= 1'b0;
      b_dest <= 16'd0;    f_rate <= 4'h7;    wbxo <= 0;
      b_count <= 16'd0;   b_data <= 0;       ISPack <= 1'b0;
      b_mode <= 4'd0;     bumpDest <= 1'b0;  i_state <= ISP_PING;
      bytes  <= 2'd0;     dataWr <= 1'b0;    i_usel <= 3'd5;
      bytecount <= 2'd0;  codeWr <= 1'b0;    g_next <= 1'b0;
      b_state <= 3'd1;    f_format <= 3'd0;  g_load <= 1'b0;
      p_reset <= 1'b1;    u_wr <= 1'b0;      g_reset_n <= 1'b0;
      outword <= 91;  // power-up output character
      init <= 1'b1;       i_count <= (1 << CODE_SIZE) - 1;
      st_new <= 2'b00;
    end else begin
      codeWr <= 1'b0;                   // strobes
      dataWr <= 1'b0;
      bumpDest <= 1'b0;
      g_next <= 1'b0;
      g_load <= 1'b0;
      g_reset_n <= 1'b1;
      st_new <= 2'b00;
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
                        b_state <= 3'b001; // reboot from flash
                      g_reset_n <= ~ISPbyte[3];
                      f_wr <= ISPbyte[5];
                      g_next <= 1'b1;   // single write and read
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
              if (codeAddrS)            // CPU sets code start address
                b_dest <= din[15:0];
              if (codeDataS) begin      // CPU writes next code word
                b_data <= din[15:0];
                codeWr <= 1'b1;
                bumpDest <= 1'b1;
              end
            end
          3'b001:                       // begin fast read, single rate SPI
            begin
              f_format <= 3'b010;
              b_state <= b_state + 1'b1;
            end
          3'b111:                       // ========== Interpret flash bytes
            begin
              g_next <= 1'b1;
              case (b_mode[3:1])        // what kind of byte is it?
              3'b000,                   // 000x = command
              3'b001:
                case (plain[7:6])
                2'b11:               	// blank = "end"
                  begin
                    if (plain[5]) begin
                      f_wr <= 1'b0;
                      f_format <= 3'd0;	// raise CS#
                      p_reset  <= plain[4];
                      b_state  <= 3'd0; // reset FSM
                    end else
                      b_mode <= {2'b01, plain[1:0]};
                  end
                2'b10:               	// SCLK frequency
                  begin
          	  f_rate <= plain[3:0];
                  end
                default:             	// data mode
                  begin
                    b_mode <= {1'b1, plain[4:2]};
                    bytes <= plain[1:0];
                    bytecount <= plain[1:0];
                  end
                endcase
              3'b010:                   // 010x = set destination address
                if (b_mode[0]) begin
                  b_dest[15:8] <= plain;   b_mode[0] <= 1'b0;
                end else begin
                  b_dest[7:0] <= plain;    b_mode <= 3'd0;
                end
              3'b011:                   // 011x = set data length
                if (b_mode[0]) begin
                  b_count[15:8] <= plain;  b_mode[0] <= 1'b0;
                end else begin
                  b_count[7:0] <= plain;   b_mode <= 3'd0;
                end
              default:                  // 1mmx = write to memory
                begin
                  b_data <= {b_data[WIDTH-9:0], plain};
                  if (bytecount)
                    bytecount <= bytecount - 2'd1;
                  else
                    begin               // write to 1 of 8 sinks
                      bytecount <= bytes;
                      case (b_mode[2:0])
                      3'd0: codeWr <= 1'b1;
                      3'd1: dataWr <= 1'b1;
                      3'd2: st_new <= 2'b11;
                      endcase
                      bumpDest <= 1'b1;
                      if (b_count)  b_count <= b_count - 16'd1;
                      else          b_mode <= 3'd0;
                    end
                end
              endcase
            end
          default:
            b_state <= b_state + 1'b1;
          endcase
        end
      end
      if (bumpDest) begin
        b_dest <= b_dest + 16'd1;
        b_data <= 0;
      end
      if (io_wr)
        if (!p_hold)
          if (internal)                 // write to register:
            case (mem_addr[2:0])
            3'b000: begin
                u_wr <= 1'b1;           // UART output byte
       	        i_usel <= 3'd5;
                outword <= din;
              end
            3'b011: b_state <= 3'd6;    // interpret flash byte stream
            3'b101: begin
                g_load <= 1'b1;         // load key
                outword <= din;
              end
            3'b110: begin
                st_o <= din[STWIDTH-1:0];
                st_new <= 2'b01;
              end
            3'b111:                     // upper bits of outgoing Wishbone
              if (WIDTH != 32)
                wbxo <= din[31-WIDTH:0];
            endcase
      if (st_new == 2'b11)
        st_o <= b_data[STWIDTH-1:0];
    end

  wire booting = (b_state) ? 1'b1 : 1'b0;
  reg [WIDTH-1:0] spif_dout;
  wire jammin = ISPfull | ~f_ok;

  always @* begin                       // i/o read mux
    case (mem_addr[2:0])                // Verilog zero-extends smaller vectors
    3'b000:  spif_dout = uartRXbyte;    // char
    3'b001:  spif_dout = uartRXfull;    // char is in the buffer
    3'b010:  spif_dout = txbusy;        // EMIT is busy?
    3'b011:  spif_dout = plain;         // flash SPI result
    3'b100:  spif_dout = jammin;        // jammed byte is still pending
    3'b101:  spif_dout = booting;       // still reading flash?
    3'b110:  spif_dout = cycles;        // free-running counter
    3'b111:  spif_dout = wbxi;          // Wishbone bus extra input bits
    endcase
  end

  assign io_dout = (internal) ? spif_dout : dat_i[WIDTH-1:0];


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
