// Serial Flash Controller for Chad                  		9/30/2020 BNE
// License: This code is a gift to the divine.

`default_nettype none
module spif
#(
  parameter CODE_SIZE = 10,   // log2 of # of 16-bit instruction words
  parameter WIDTH = 18,       // word size of data memory
  parameter DATA_SIZE = 10,   // log2 of # of cells in data memory
  parameter BASEBLOCK = 0,    // which 64KB sector to start user flash at
  parameter PRODUCT_ID0 = 1,  // product ID for ISP
  parameter PRODUCT_ID1 = 2,
  parameter UART_RATE_POR = 868
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
  output reg  [WIDTH-1:0]  io_dout,     // I/O data out
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
  input  wire [7:0]        f_din        // Flash received data
);

//==============================================================================
// UART input FSM
// Received data goes to uartRXbyte and uartRXfull.
// The processor can read the received character to clear uartRXfull.
//==============================================================================

  reg [7:0] uartRXbyte, ISPbyte;        // Received UART byte
  reg uartRXfull;                       // Indicate that UART is full
  reg ispActive;                        // Indicate that ISP mode is active
  reg ISPfull, ISPack;                  // Indicate ISP byte was received

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
        ISPbyte <= 8'h00;     r_state <= UART_RX_IDLE;
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
          case (mem_addr[2:0])          // io read clears UART receive flag
          3'b000: uartRXfull <= 1'b0;
          endcase
        if (io_wr)
          case (mem_addr[2:0])
          3'b010: u_rate <= din[15:0];  // set UART baud rate
          3'b100:                       // jam an ISP byte
            {ISPbyte, ISPfull} <= {din[7:0], 1'b1};
          endcase
      end

  reg  [2:0] b_state;                   // boot FSM state
  wire booting = (b_state) ? 1'b1 : 1'b0;

  always @* begin                       // i/o read mux
    case (mem_addr[2:0])                // Verilog zero-extends smaller vectors
    3'b000:    io_dout = uartRXbyte;    // char
    3'b001:    io_dout = uartRXfull;    // char is in the buffer
    3'b010:    io_dout = u_ready;       // okay to EMIT
    3'b011:    io_dout = f_din;         // flash SPI result
    3'b100:    io_dout = ISPfull;       // jammed byte is still pending
    3'b101:    io_dout = booting;       // still reading flash?
    default:   io_dout = 1'b0;
    endcase
  end

  reg [1:0] i_usel;
  always @* begin                       // UART output mux
    if (ispActive)
      case (i_usel)
      2'b00:   u_dout <= f_din;
      2'b01:   u_dout <= PRODUCT_ID1[7:0];
      2'b10:   u_dout <= PRODUCT_ID0[7:0];
      default: u_dout <= BASEBLOCK[7:0];
      endcase
    else       u_dout <= din[7:0];
  end

//==============================================================================
// Boot Loader and ISP FSM
// The boot loader can be disabled by forcing CS# high with a jumper so it
// reads blank.
//==============================================================================

  localparam FAST_READ = 8'h0B;
  reg [15:0] b_count;                   // length of byte run
  reg [15:0] b_dest;                    // address register for bootup
  reg [11:0] i_count;
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
  wire f_ok = f_ready & ~f_wr;
  reg init;                             // init memory
  reg [CODE_SIZE-1:0] init_cnt;

// Boot mode FSM
  always @(posedge clk or negedge arstn)
    if (!arstn) begin                   // async reset
      f_dout <= 8'h00;    f_wr <= 1'b0;      f_who <= 1'b0;
      b_dest <= 16'd0;    f_rate <= 4'h7;    i_state <= ISP_IDLE;
      b_count <= 16'd0;   b_data <= 0;       ISPack <= 1'b0;
      b_mode <= 3'd0;     bumpDest <= 1'b0;
      bytes  <= 2'd0;     dataWr <= 1'b0;    i_usel <= 2'b00;
      bytecount <= 2'd0;  codeWr <= 1'b0;
      b_state <= 3'd1;    f_format <= 3'd0;  // start in boot mode
      p_reset <= 1'b1;    u_wr <= 1'b0;
      init <= 1'b1;       i_count <= (1 << CODE_SIZE) - 1;
    end else begin
      codeWr <= 1'b0;
      dataWr <= 1'b0;
      bumpDest <= 1'b0;
      if (init) begin
        codeWr <= 1'b1;
        dataWr <= 1'b1;
        bumpDest <= 1'b1;
        if (i_count) i_count <= i_count - 1;
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
              f_wr <= 1'b0; // ========== Interpret ISP bytes ==========
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
                        b_state <= 3'd1;  // reboot from flash
                    end
                  2'b10:          	// send a run of bytes to flash
                    begin
                      i_state <= ISP_UPLOAD;
                      f_format <= ISPbyte[2:0];
                    end
                  2'b11:          	// read a run of bytes from flash
                    begin
                      i_state <= ISP_DNLOAD;
                      f_format <= ISPbyte[2:0];
                      f_wr <= 1'b1;
                    end
                  endcase
                end
              ISP_UPLOAD:
                if (b_rxok) begin
                  ISPack <= 1'b1;
                  f_wr <= 1'b1; 	        // UART --> flash
                  if (i_count) i_count <= i_count - 12'd1;
                  else i_state <= ISP_IDLE;
                end
              ISP_DNLOAD:
                if (b_txok) begin
                  u_wr <= 1'b1;           // flash --> UART
	  	i_usel <= 2'b00;
                  f_wr <= 1'b1;
                  if (i_count) i_count <= i_count - 12'd1;
                  else i_state <= ISP_IDLE;
                end
              ISP_PING:
                if (b_txok) begin
                  u_wr <= 1'b1;
	  	i_usel <= i_count[1:0];
                  if (i_count) i_count <= i_count - 12'd1;
                  else i_state <= ISP_IDLE;
                end
              default:
                i_state <= ISP_IDLE;
              endcase
            end
          3'b111: // ========== Interpret flash bytes ==========
            begin
              case (b_mode[2:1])          // what kind of byte is it?
              2'b00:                      // 00x = command
                case (f_din[7:6])
                2'b11:               	// blank = "end"
                  begin
                    if (f_din[5]) begin
                      f_wr <= 1'b0;
                      f_format <= 3'd0;	// raise CS#
                      p_reset  <= f_din[4];
                      b_state  <= 3'd0; 	// reset FSM
                    end else
                      b_mode <= {1'b1, f_din[1:0]};
                  end
                2'b10:               	// SCLK frequency
                  begin
	  	  f_rate <= f_din[3:0];
                  end
                default:             	// data mode
                  begin
                    b_mode <= {2'b01, f_din[2]};
                    bytes <= f_din[1:0];
                    bytecount <= f_din[1:0];
                  end
                endcase
              2'b01:                      // 01x = write to memory
                begin
                  b_data <= {b_data[WIDTH-9:0], f_din};
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
              2'b10:                      // 10x = set destination address
                if (b_mode[0]) begin
                  b_dest[15:8] <= f_din;   b_mode[0] <= 1'b0;
                end else begin
                  b_dest[7:0] <= f_din;    b_mode <= 3'd0;
                end
              default:                    // 11x = set data length
                if (b_mode[0]) begin
                  b_count[15:8] <= f_din;  b_mode[0] <= 1'b0;
                end else begin
                  b_count[7:0] <= f_din;   b_mode <= 3'd0;
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
        case (mem_addr[2:0])
        3'b000: u_wr <= 1'b1;           // write to UART
	3'b011: b_state <= 3'd6;        // interpret flash byte stream
        endcase
    end

// The Data and Code RAMs are accessed via DMA by the boot process.
// The bootloader writes to either code or data RAM.

  assign p_hold = codeWr | dataWr;
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
