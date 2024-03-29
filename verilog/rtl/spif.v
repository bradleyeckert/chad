// Serial Flash Controller for Chad                  		9/14/2021 BNE
// This code is a gift to all mankind.

// SPIF is an I/O processor that loads memories from SPI flash at boot time,
// decrypts flash data on the fly, provides a Wishbone Bus for peripherals,
// processes a UART stream, and provides ISP-over-UART functionality.

// The processor interface is for J1-type CPUs. Study that if you need to port
// SPIF to something sexy like a RISC V.

`default_nettype none
module spif
#(
  parameter CODE_SIZE = 12,             // log2 of # of 16-bit instruction words
  parameter WIDTH = 24,                 // word size of data memory
  parameter DATA_SIZE = 11,             // log2 of # of cells in data memory
  parameter BASEBLOCK = 0,              // first 64KB sector of user flash
  parameter PRODUCT_ID = 1,             // 16-bit product ID for ISP
  parameter KEY_LENGTH = 7,             // Length of boot key
  parameter RAM_INIT = 1                // Initialize RAM by default
)(
  input  wire                 clk,
  input  wire                 arstn,    // async reset (active low)
// Processor interface (J1, chad, etc)
  input  wire                 io_rd,    // I/O read strobe: get io_din
  input  wire                 io_wr,    // I/O write strobe: register din
  input  wire                 mem_rd,   // Data memory read enable
  input  wire                 mem_wr,   // Data memory write enable
  input  wire [((WIDTH + 7) / 8) - 1:0] memlane,
  input  wire [14:0]          mem_addr, // Data memory address
  input  wire [WIDTH-1:0]     din,      // Data memory & I/O in (from N)
  output wire [WIDTH-1:0]     io_dout,  // I/O data out
  input  wire [12:0]          code_addr,// Code memory address
  output wire                 p_hold,   // Processor hold
  output reg                  p_reset,  // Processor reset
// Memory write ports and read/write control
  output wire [DATA_SIZE-1:0] data_a,   // Data RAM read/write address
  output wire [WIDTH-1:0]     data_din, // Data RAM write data
  output wire                 data_wr,  // Data RAM write enable
  output wire                 data_rd,  // Data RAM read enable
  output wire [((WIDTH + 7) / 8) - 1:0] data_lane, // write enables
  output wire [CODE_SIZE-1:0] code_a,   // Code RAM read/write address
  output wire [15:0]          code_din, // Code RAM write data
  output wire                 code_wr,  // Code RAM write enable
  output wire                 code_rd,  // Code RAM read enable
// Boot key
  input wire [KEY_LENGTH*8-1:0] key,    // Boot code decrypt key, 0 if plaintext
  input wire [23:0]           sernum,   // Serial number or boot key ID
  input wire [47:0]           isppass,  // ISP password, 6 bytes
// Enable ISP
  input wire                  ISPenable,
// UART interface
  input  wire                 u_ready,  // Ready for next byte to send
  output reg                  u_wr,     // UART transmit strobe
  output reg  [7:0]           u_dout,   // UART transmit data
  input  wire                 u_full,   // UART has received a byte
  output reg                  u_rd,     // UART received strobe
  input  wire [7:0]           u_din,    // UART received data
// Flash Memory interface
  input  wire                 f_ready,  // Ready for next byte to send
  output reg                  f_wr,     // Flash transmit strobe
  output reg  [7:0]           f_dout,   // Flash transmit data
  output reg  [2:0]           f_format, // Flash format
  output reg  [3:0]           f_rate,   // Flash SCLK divisor
  input  wire [7:0]           f_din,    // Flash received data
// Wishbone Alice
  output reg  [14:0]          adr_o,    // address
  output reg  [31:0]          dat_o,    // data out
  input wire  [31:0]          dat_i,    // data in
  output reg                  we_o,     // 1 = write, 0 = read
  output reg                  stb_o,    // strobe
  input wire                  ack_i,    // acknowledge
// Interrupt requests
  output reg                  cyclev,   // cycle count overflow strobe
  output wire                 urxirq,   // UART full strobe
  output wire                 utxirq,   // UART ready strobe
// Other status
  output reg                  badboot   // Boot code has bad signature
);

// Wishbone bus Alice (connects to Bob)

  wire internal = (mem_addr[14:4] == 0);// anything above 0x000F is Wishbone
  wire wbbusy = stb_o;                  // waiting for wishbone bus
  wire wbreq = (~internal) & (io_wr | io_rd);
`ifndef IS32BIT
  reg [31-WIDTH:0] wbxo;
`endif
  reg [31:0] wbxi;
  always @(posedge clk or negedge arstn) begin
    if (!arstn) begin
      wbxi <= 0;
      {stb_o, we_o, dat_o, adr_o} <= 1'b0;
    end else begin
      if (stb_o) begin                  // waiting for ack_i
        if (ack_i) begin
          stb_o <= 1'b0;
          if (!we_o)                    // capture read data
            wbxi <= dat_i;
        end
      end else if (wbreq) begin
        {stb_o, we_o} <= {1'b1, io_wr};
        dat_o <= (WIDTH == 32) ? din : {wbxo, din};
        adr_o <= mem_addr;
      end
    end
  end

// Free-running cycles counter readable by the CPU. Rolls over at Fclk*2^-WIDTH.

  reg [WIDTH-1:0] cycles;
  always @(posedge clk or negedge arstn) begin
    if (!arstn)
      {cyclev, cycles} <= 0;
    else
      {cyclev, cycles} <= cycles + 1'b1;
  end

//==============================================================================
// UART output FSM
// Output bytes get translated into escape sequences here
//==============================================================================

  reg           uo_escaped;             // Escape sequence in progress
  reg  [1:0]    uo_lower;               // LSBs
  reg           uo_wr;                  // UART transmit strobe
  reg  [7:0]    uo_dout;                // UART transmit data
  wire uo_ready = u_ready & ~uo_escaped & ~u_wr;

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      {uo_escaped, u_wr, u_dout, uo_lower} <= 1'b0;
    end else begin
      u_wr <= 1'b0;
      if (uo_escaped) begin
        if (u_ready & ~u_wr) begin
          u_wr <= 1'b1;
          u_dout <= {6'b000000, uo_lower};
          uo_escaped <= 1'b0;
        end
      end if (uo_wr) begin
        u_wr <= 1'b1;
        if (uo_dout[7:2] == 6'b000100) begin
          uo_lower <= uo_dout[1:0];     // 10h to 13h ==> 10h, 0 to 3
          uo_escaped <= 1'b1;
          u_dout <= 8'h10;
        end else
          u_dout <= uo_dout;
      end
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
  wire txbusy = ~uo_ready | ispActive;  // tell CPU that TX is busy

  reg [2:0] r_state;                    // UART receive state
  reg [2:0] unlock_cnt, unlock_ok;
  reg [7:0] unlock;                     // unlock byte
  localparam UART_RX_IDLE = 3'b001;
  localparam UART_RX_ESC  = 3'b010;
  localparam UART_UNLOCK  = 3'b100;

  wire u_rxok = u_full & ~u_rd;         // ok to get raw data from UART
  wire u_rxready = (ispActive) ? ~ISPfull : ~uartRXfull;
  reg uartRXfull_d;
  assign urxirq = uartRXfull & ~uartRXfull_d;

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      uartRXfull <= 1'b0;     u_rd <= 1'b0;
      {unlock_cnt, unlock_ok} <= 1'b0;
      ISPfull <= 1'b0;   ispActive <= 1'b0;
      uartRXbyte <= 8'h00;   uartRXfull_d <= 1'b0;
      ISPbyte <= 8'h00;    r_state <= UART_RX_IDLE;
    end else begin
      uartRXfull_d <= uartRXfull;
      u_rd <= 1'b0;
      case (unlock_cnt)                 // big endian password
      3'd0: unlock <= isppass[47:40];
      3'd1: unlock <= isppass[46:32];
      3'd2: unlock <= isppass[31:24];
      3'd3: unlock <= isppass[23:16];
      3'd4: unlock <= isppass[15:8];
      default: unlock <= isppass[7:0];
      endcase
      if (u_rxok)
        case (r_state)
        UART_RX_IDLE:
          if (u_din[7:2] == 6'b000100) begin
            u_rd <= 1'b1;
            case (u_din[1:0])
            2'b00: r_state <= UART_RX_ESC;
            2'b10: begin
                r_state <= UART_UNLOCK;
                {unlock_cnt, unlock_ok} <= 1'b0;
                ispActive <= 1'b0;      // any bad unlock sequence clears this
              end
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
          if (u_rxready) begin          // 2-byte escape sequence: 10h, 0xh
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
            u_rd <= 1'b1;
            if (u_din == unlock) begin
              unlock_ok <= unlock_ok + 1'd1;
              if (unlock_ok == 3'd5)
                ispActive <= ISPenable;
            end
            unlock_cnt <= unlock_cnt + 1'd1;
            if (unlock_cnt == 3'd5)
              r_state <= UART_RX_IDLE;
          end
        default:
          r_state <= UART_RX_IDLE;
        endcase
      if (ISPack == 1'b1)
        ISPfull <= 1'b0;
      if (io_rd & internal & ~p_hold)
        case (mem_addr[3:0])            // io read clears UART receive flag
        4'h0: uartRXfull <= 1'b0;
        endcase
      if (io_wr & internal & ~p_hold)
        case (mem_addr[3:0])
        4'h4:                           // jam an ISP byte
          {ISPbyte, ISPfull} <= {din[7:0], 1'b1};
        endcase
    end

  reg [2:0] i_usel;                     // UART output select for ISP
  reg [WIDTH-1:0] outword;              // general purpose output word
  always @* begin                       // UART output mux
    if (ispActive)
      case (i_usel[2:0])                // ping response:
      3'b000:  uo_dout <= 8'hAA;        // format byte: AA = this one
      3'b001:  uo_dout <= sernum[23:16];
      3'b010:  uo_dout <= sernum[15:8];
      3'b011:  uo_dout <= sernum[7:0];
      3'b100:  uo_dout <= PRODUCT_ID[15:8];
      3'b101:  uo_dout <= PRODUCT_ID[7:0];
      3'b110:  uo_dout <= BASEBLOCK[7:0];
      default: uo_dout <= f_din;
      endcase
    else  uo_dout <= outword[7:0];
  end

  always @* begin                       // insert i/o wait states
    if (io_wr & internal) begin
      case (mem_addr[3:0])
      4'h0:  iobusy = txbusy;           // UART output
      4'h4:  iobusy = ISPfull;          // SPI flash byte-banging
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

// To do:
// When loading a key, don't block the start of a read sequence

  reg [KEY_LENGTH*8-1:0] widekey;       // 0 = no cypher
  reg [3:0] key_index;
  reg g_init;                           // reset hard key

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      key_index <= KEY_LENGTH - 1;
	  widekey <= 1'b0;
    end else begin
      if (g_init)
        widekey <= key;
      else if (g_load)                  // shift in a key digit:
        widekey <= {widekey[KEY_LENGTH*8 - (WIDTH+1) : 0], outword};
      else if (key_index)               // shift out a byte
        widekey <= {8'b0, widekey[KEY_LENGTH*8 - 1 : 8]};

      if (g_reset_n == 1'b0)            // re-key strobe `)gkey`
        key_index <= KEY_LENGTH - 1;    // sync reset
      else if (key_index)
        key_index <= key_index - 1'b1;
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
// CRC32 logic (crc32.v)
//==============================================================================

  reg [31:0] crcIn;
  wire [31:0] crcOut;
  reg [3:0]  b_state;                   // boot FSM state
  reg signing, testsig, sig_ok, sig_last;         // test signature

  crc32 signature (
    .crcIn      (crcIn),
    .data       (plain),
    .crcOut     (crcOut)
  );

  always @(posedge clk or negedge arstn)
    if (!arstn) begin
      crcIn <= 32'hFFFFFFFF;
    end else begin
      if (b_state[2:0] == 3'd2)
        crcIn <= 32'hFFFFFFFF;
      else if (!signing)
        if (g_next)
          crcIn <= crcOut;
    end

//==============================================================================
// Boot Loader and ISP FSM
// The boot loader can be disabled by forcing CS# high with a jumper so it
// reads blank.
//==============================================================================

  localparam SNGLREAD_CMD = 8'h0B;      // SPI commands
  localparam DUALREAD_CMD = 8'h3B;
  localparam SINGLE_RATE = 3'd2;        // SPI rate for commands and address
  localparam DUAL_RATE = 3'd5;          // format for dual-rate SPI read
  localparam BOOT_RATE = DUAL_RATE;     // either SINGLE_RATE or DUAL_RATE

  reg [15:0] b_count;                   // length of byte run
  reg [15:0] b_dest;                    // address register for boot load destination
  reg [2:0]  rd_format;                 // boot load SPI mode
  reg [23:0] rd_addr;                   // flash read address
  reg [1:0]  rd_bytes, rd_bcnt;         // byte count for multibyte read

  reg [WIDTH-1:0] b_data;               // plaintext boot data
  reg [31:0] fr_data;                   // flash read data word
  reg codeWr, dataWr;
  reg [1:0]  b_bytes, b_bcnt;           // bytes per b_data word
  reg bumpDest;                         // trigger address bump
  reg [3:0]  b_mode;                    // boot interpreter mode

  reg [3:0] i_state;
  localparam ISP_IDLE =   4'b0001;
  localparam ISP_UPLOAD = 4'b0010;
  localparam ISP_DNLOAD = 4'b0100;
  localparam ISP_PING =   4'b1000;

  wire b_rxok = ISPfull & ~ISPack;      // okay to process UART input
  wire b_txok = uo_ready & ~uo_wr;      // okay to send to UART
  wire f_ok = f_ready & ~f_wr & g_ready;
  reg init;                             // initialize memory at POR
  reg [7:0] sig_ex;                     // signature byte to check
  reg cold;                             // cold boot

// Strobes to trigger writes

  wire codeAddrS = (mem_addr[3:0] == 4'h1) & io_wr & internal & ~p_hold;
  wire codeDataS = (mem_addr[3:0] == 4'h2) & io_wr & internal & ~p_hold;

// Boot mode FSM
  always @(posedge clk or negedge arstn)
    if (!arstn) begin                   // async reset
      f_dout <= 8'h00;    f_wr <= 1'b0;      sig_ok <= 1'b0;
      b_dest <= 16'd0;    f_rate <= 4'h7;    wbxo <= 0;
      b_count <= 16'd0;   b_data <= 0;       ISPack <= 1'b0;
      b_mode <= 4'd0;     bumpDest <= 1'b0;  signing <= 1'b0;
      b_bytes  <= 2'd0;   dataWr <= 1'b0;    i_usel <= 3'd7;
      b_bcnt <= 2'd0;     codeWr <= 1'b0;    g_next <= 1'b0;
      b_state <= 4'd1;    g_init <= 1'b1;    g_load <= 1'b0;
      p_reset <= 1'b1;    uo_wr <= 1'b0;     g_reset_n <= 1'b0;
      {testsig, sig_last, sig_ex} <= 1'b0;
      {rd_bytes, rd_bcnt, fr_data} <= 1'b0;
      rd_format <= BOOT_RATE;
      f_format <= 3'd0;
      rd_addr <= 0;       cold <= 1'b1;      badboot <= 1'b0;
      i_state <= ISP_PING;              // spit out a char on POR
      outword <= 91;                    // power-up output character
      init <= RAM_INIT;
      if (RAM_INIT)
        i_count <= (1 << CODE_SIZE) - 1;
      else
        i_count <= 0;
    end else begin
      codeWr <= 1'b0;                   // strobes
      dataWr <= 1'b0;
      bumpDest <= 1'b0;
      g_next <= 1'b0;
      g_load <= 1'b0;
      g_reset_n <= 1'b1;
      g_init <= 1'b0;
      testsig <= 1'b0;
      sig_last <= 1'b0;
      if (init) begin
        codeWr <= 1'b1;                 // clear RAMs
        dataWr <= 1'b1;
        bumpDest <= 1'b1;
        if (i_count) i_count <= i_count - 12'd1;
        else init <= 1'b0;
      end else begin
        uo_wr <= 1'b0;
        case (b_state[2:0])
          3'b000:  f_dout <= ISPbyte;
          3'b001:  f_dout <= rd_format[2] ? DUALREAD_CMD : SNGLREAD_CMD ;
          3'b010:  f_dout <= rd_addr[23:16] + BASEBLOCK[7:0];
          3'b011:  f_dout <= rd_addr[15:8];
          3'b100:  f_dout <= rd_addr[7:0];
          default: f_dout <= 8'h00;
        endcase
        ISPack <= 1'b0;
        f_wr <= 1'b0;
        if (f_ok) begin
          f_wr <= 1'b1;
          case (b_state)                // read sequencing FSM
          4'h0:                         // is idle:
            begin
              f_wr <= 1'b0;             // ========== Interpret ISP bytes
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
                        i_count <= 12'd6;
                      end
                      if (ISPbyte[2]) begin
                        b_state <= 4'h1; // reboot from flash
                        f_format <= SINGLE_RATE;
                        rd_format <= BOOT_RATE;
                        rd_addr <= {i_count, 8'd0};
                        g_reset_n <= 1'b0;
                        g_init <= 1'b1;
                      end
                      else g_reset_n <= ~ISPbyte[3]; // load key
                      if (ISPbyte[4])   // change flash bus rate
                        f_rate <= i_count[3:0];
                      f_wr <= ISPbyte[5];
                      g_next <= ISPbyte[5];
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
                  if (i_count) i_count <= i_count - 1'b1;
                  else i_state <= ISP_IDLE;
                end
              ISP_DNLOAD:
                if (b_txok) begin
                  uo_wr <= 1'b1;        // flash --> UART
          	  i_usel <= 3'd7;
                  if (i_count) begin
                    i_count <= i_count - 12'd1;
                    f_wr <= 1'b1;
                  end
                  else i_state <= ISP_IDLE;
                end
              ISP_PING:
                if (b_txok) begin
                  uo_wr <= 1'b1;
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
          4'h1, 4'h9:                   // begin fast read, boot or flash-read
            begin
              f_format <= SINGLE_RATE;
              b_state <= b_state + 1'b1;
            end
          4'h6:
            begin
              f_format <= rd_format;
              b_state <= b_state + 1'b1;
            end
          4'h7:                         // ========== Interpret flash bytes
            begin
              g_next <= 1'b1;
              case (b_mode[3:1])        // what kind of byte is it?
              3'b000,                   // 000x = command
              3'b001:
                case (plain[7:6])
                2'b11:               	// blank = "end"
                  begin
                    if (plain[5]) begin
                      if (plain[4]) begin
                        f_wr <= 1'b0;   // 1111xxxx = end interpret
                        f_format <= 3'd0; // raise CS#
                        rd_format <= SINGLE_RATE; // ???
                        b_state  <= 4'd0;
                      end else begin    // 1110xxxx = finish booting
                        b_count <= 16'd4;
                        rd_bcnt <= 2'd3;
                        b_state <= 4'hF;
                        signing <= 1'b1;
                        sig_ok  <= 1'b1;
                      end
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
                    b_bytes <= plain[1:0];
                    b_bcnt <= plain[1:0];
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
                  if (b_bcnt)
                    b_bcnt <= b_bcnt - 2'd1;
                  else
                    begin               // write to 1 of 8 sinks
                      b_bcnt <= b_bytes;
                      case (b_mode[2:0])
                      3'd0: codeWr <= 1'b1;
                      3'd1: dataWr <= 1'b1;
                      endcase
                      bumpDest <= 1'b1;
                      if (b_count)  b_count <= b_count - 16'd1;
                      else          b_mode <= 3'd0;
                    end
                end
              endcase
            end
          4'hE:                         // clear fr_data before shifting in bytes
            begin
              fr_data <= 0;
              f_format <= rd_format;
              b_state <= b_state + 1'b1;
              g_next <= 1'b1;           // get keystream before the read
              rd_bcnt <= rd_bytes;
            end
          4'hF:                         // ========== Read a word
            begin
              testsig <= signing;
              case (rd_bcnt)
              2'b11: sig_ex <= crcIn[31:24];
              2'b10: sig_ex <= crcIn[23:16];
              2'b01: sig_ex <= crcIn[15:8];
              2'b00: begin
                  sig_ex <= crcIn[7:0];
                  if (signing) begin    // end of signature testing
                    f_format <= 3'd0;   // raise CS# after signature
                    rd_format <= SINGLE_RATE;  // ???
                    sig_last <= 1'b1;
                    signing <= 1'b0;
                  end
                end
              endcase
              fr_data <= {fr_data[23:0], plain};
              if (rd_bcnt) begin
                rd_bcnt <= rd_bcnt - 2'd1;
                g_next <= 1'b1;
              end else begin
                b_state <= b_state + 1'b1;
                f_wr <= 1'b0;
              end
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
      if (io_wr & internal & ~p_hold)   // write to register:
        case (mem_addr[3:0])
        4'h0: begin
            uo_wr <= 1'b1;              // UART output byte
       	    i_usel <= 3'd7;
            outword <= din;
          end
        4'h3: begin
            b_state <= 4'h1;            // interpret flash byte stream
            f_format <= SINGLE_RATE;
            rd_format <= BOOT_RATE;
            rd_addr <= din;
          end
        4'h5: begin
            g_load <= 1'b1;             // load key
            outword <= din;
          end
        4'h6: begin
            rd_format <= din[4:2];
            rd_bytes <= din[1:0];       // Set up flash read parameters
          end
        4'h7:                           // upper bits of outgoing Wishbone
          if (WIDTH != 32)
            wbxo <= din[31-WIDTH:0];
        4'hA: begin
            b_state <= 4'hE;            // read next from flash to b_data
          end
        4'hB: begin
            b_state <= 4'h9;            // read a word from flash to b_data
            f_format <= SINGLE_RATE;
            rd_addr <= din;
          end
        endcase
      if (testsig) begin                // test the boot signature bytes
        if (fr_data[7:0] != sig_ex)
          sig_ok <= 1'b0;
        if (sig_last) begin
          badboot <= ~sig_ok & cold;
          p_reset <= 1'b0;              // first boot run deasserts reset
          cold <= 1'b0;
        end
      end
    end

  wire booting = (b_state) ? 1'b1 : 1'b0;
  reg [WIDTH-1:0] spif_dout;
  wire jammin = ISPfull | ~f_ok | booting;

  always @* begin                       // i/o read mux
    case (mem_addr[3:0])                // Verilog zero-extends smaller vectors
    4'h0:    spif_dout = uartRXbyte;    // char
    4'h1:    spif_dout = uartRXfull;    // char is in the buffer
    4'h2:    spif_dout = txbusy;        // EMIT is busy?
    4'h3:    spif_dout = plain;         // flash SPI result
    4'h4:    spif_dout = jammin;        // jammed byte is still pending
    // change 5 to reserved, address 4 means flash is busy
    4'h5:    spif_dout = booting;       // still reading flash?
    4'h6:    spif_dout = cycles;        // free-running counter
`ifndef IS32BIT
    4'h7:    spif_dout = wbxi[31:WIDTH];// Wishbone bus extra input bits
    4'hA:    spif_dout = fr_data[31:WIDTH]; // flash read word
`endif
    4'hB:    spif_dout = fr_data[WIDTH-1:0];
    4'hC:    spif_dout = {sig_ok, ISPenable}; // other status bits
    4'hE:    spif_dout = PRODUCT_ID;    // basic versioning boilerplate
    4'hF:    spif_dout = {DATA_SIZE[3:0], CODE_SIZE[3:0], BASEBLOCK[7:0]};
    default: spif_dout = outword;
    endcase
  end

  assign io_dout = (internal) ? spif_dout : wbxi[WIDTH-1:0];

// The Data and Code RAMs are accessed via DMA by the boot process.
// The bootloader writes to either code or data RAM.
// p_hold inhibits reads to keep the read streams in sync with their addresses.
// It's stretched when writing to code RAM to re-sync the instruction stream.

  assign p_hold = codeWr | dataWr | iobusy | wbbusy;
  assign code_rd = ~codeWr;
  assign code_wr = codeWr;
  assign code_a = (codeWr) ? b_dest[CODE_SIZE-1:0] : code_addr[CODE_SIZE-1:0];
  assign data_rd = mem_rd & ~dataWr;
  assign data_wr = mem_wr | dataWr;
  assign data_lane = (dataWr) ? ~(1'b0) : memlane;
  assign data_a = (dataWr) ? b_dest[DATA_SIZE-1:0] : mem_addr[DATA_SIZE-1:0];
  assign data_din = (dataWr) ? b_data : din;
  assign code_din = b_data[15:0];

endmodule
`default_nettype wire
