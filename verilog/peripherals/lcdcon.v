// LCD controller for ST7796, etc.                 12/16/2020 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

// Wishbone to LCD parallel interface and bus cycle controller.
// The maximum allowed `clk` frequency is 200 MHz.

`default_nettype none
module lcdcon(
  input wire                clk,
  input wire                rst_n,
// Wishbone Bob
  input wire  [2:0]         adr_i,      // address
  output reg  [7:0]         dat_o,      // data out
  input wire  [17:0]        dat_i,      // data in
  input wire                we_i,       // 1 = write, 0 = read
  input wire                stb_i,      // strobe
  output reg                ack_o,      // acknowledge
// LCD module with 8-bit bus and internal frame buffer
  input wire  [7:0]         lcd_di,     // read data
  output reg  [7:0]         lcd_do,     // write data
  output reg                lcd_oe,     // lcd_d output enable
  output reg                lcd_rd,     // RDX pin
  output reg                lcd_wr,     // WRX pin
  output reg                lcd_rs,     // D/CX pin
  output reg                lcd_cs,     // CSX pin
  output reg                lcd_rst     // RESET pin, active low
);

// adr  write                   read
//   0  command byte            read with RS=0
//   1  data byte               read with RS=1
//   2  chip select done        -
//   3  data (6:6:6 GRAM)       -
//   4  reserved for backlight  -
//   5  write timing            -
//   6  read timing             -
//   7  reset pin               -

// Controllers ST7796, ILI9341, ILI9488, etc. have similar bus timing in MCU mode.
// Read cycle timing is 6-bit: 320 nsec / 64 = 5ns

  reg [4:0] state;
  localparam IDLE    = 5'b00001;
  localparam WRITE_A = 5'b00010;
  localparam WRITE_B = 5'b00100;
  localparam READ_A  = 5'b01000;
  localparam READ_B  = 5'b10000;

  reg [5:0] count, rltime, rhtime, wltime, whtime;
  reg [1:0] plane;                      // color plane to output next, 0=none
  reg packed;                           // color is packed 5:6:5 16-bit
  reg [11:0] lcd_next;                  // color data for multi-cycle write

  always @(posedge clk, negedge rst_n) begin
    if (!rst_n) begin
      ack_o <= 1'b0;  state <= IDLE;  count <= 0;
      rltime <= 6'h3F;  rhtime <= 6'h3F;  packed <= 1'b0;
      wltime <= 6'h3F;  whtime <= 6'h3F;  plane <= 2'b00;
      {lcd_oe, lcd_rd, lcd_wr, lcd_rs, lcd_cs, lcd_rst} <= 6'b011110;
    end else begin
      dat_o = lcd_di;
      if (state != IDLE)
        ack_o <= ack_o & stb_i;
      if (count)
        count <= count - 1'b1;
      else begin
        case (state)
        IDLE:
          if (stb_i) begin
            ack_o <= 1'b1;
            if (we_i) begin
              if (adr_i[2]) begin
                case (adr_i[1:0])
                2'b00: {lcd_oe, lcd_rd, lcd_wr, lcd_rs, lcd_cs, lcd_rst, lcd_do} <= dat_i[13:0];
                2'b01: {packed, wltime, whtime} <= dat_i[12:0];
                2'b10: {rltime, rhtime} <= dat_i[11:0];
                2'b11: lcd_rst <= dat_i[0];
                endcase
              end else begin
                casez (adr_i[1:0])
                2'b0?:
                  begin
                    lcd_do <= dat_i[7:0];
                    state <= WRITE_A;  count <= wltime;
                    {lcd_cs, lcd_wr, lcd_oe, lcd_rs} <= {3'b001, adr_i[0]};
                  end
                2'b10:
                  lcd_cs <= 1'b1;
                2'b11:
                  begin
                    {lcd_cs, lcd_wr, lcd_oe, lcd_rs} <= 4'b0011;
                    lcd_next <= dat_i[11:0];
                    state <= WRITE_A;  count <= wltime;
                    if (packed) begin
                      lcd_do <= {dat_i[17:13], dat_i[11:9]};
                      plane <= 2'd1;
                    end else begin
                      lcd_do <= {dat_i[17:12], 2'b00};    // red
                      plane <= 2'd2;
                    end
                  end
                endcase
              end
            end else begin
              state <= READ_A;  count <= rltime;
              {lcd_cs, lcd_rd, lcd_oe, lcd_rs} <= {3'b000, adr_i[0]};
            end
          end
            else ack_o <= 1'b0;
        WRITE_A:
          begin
            state <= WRITE_B;  count <= whtime;
            lcd_wr <= 1'b1;
          end
        WRITE_B:
          begin
            if (plane) begin
              state <= WRITE_A;  count <= wltime;
              plane <= plane - 1'b1;  lcd_wr <= 1'b0;
              if (packed)
                lcd_do <= lcd_next[8:1];
              else if (plane == 2)
                lcd_do <= {lcd_next[11:6], 2'b00};
              else
                lcd_do <= {lcd_next[5:0], 2'b00};
            end else state <= IDLE;
          end
        READ_A:
          begin
            state <= READ_B;  count <= rhtime;
            lcd_rd <= 1'b1;
          end
        READ_B:
          state <= IDLE;
        endcase
      end
    end
  end

endmodule
`default_nettype wire
