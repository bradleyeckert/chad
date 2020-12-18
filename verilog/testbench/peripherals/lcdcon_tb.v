// LCDCON testbench                                     12/16/20 BNE

`timescale 1ns/10ps

module lcdcon_tb();

  reg	             clk = 1;
  reg	             rst_n = 0;
// Wishbone Bob
  reg  [2:0]         adr_i = 0;      // address               o
  wire [7:0]         dat_o;          // data out              i
  reg  [17:0]        dat_i = 0;      // data in               o
  reg                we_i = 0;       // 1 = write, 0 = read   o
  reg                stb_i = 0;      // strobe                o
  wire               ack_o;          // acknowledge           i
// LCD module with 8-bit bus and internal frame buffer
  reg  [7:0]         lcd_di = 0;     // read data             o
  wire [17:0]        lcd_do;         // write data            i
  wire               lcd_oe;         // lcd_d output enable   i
  wire               lcd_rd;         // RDX pin               i
  wire               lcd_wr;         // WRX pin               i
  wire               lcd_rs;         // DCX pin               i
  wire               lcd_cs;         // CSX pin               i
  wire               lcd_rst;        // RESET pin, active low i

  lcdcon u1 (
    .clk        (clk   ),
    .rst_n      (rst_n ),
    .adr_i      (adr_i ),
    .dat_o      (dat_o ),
    .dat_i	(dat_i ),
    .we_i 	(we_i  ),
    .stb_i      (stb_i ),
    .ack_o	(ack_o ),
    .lcd_di     (lcd_di),
    .lcd_do     (lcd_do),
    .lcd_oe     (lcd_oe),
    .lcd_rd     (lcd_rd),
    .lcd_wr     (lcd_wr),
    .lcd_rs     (lcd_rs),
    .lcd_cs     (lcd_cs),
    .lcd_rst    (lcd_rst)
  );

  task READ;                            // Wishbone Read
    input [2:0] address;
    begin
      @(posedge clk);
      we_i <= 1'b0;  stb_i <= 1'b1;  adr_i <= address;
      @(posedge ack_o);
      @(posedge clk);  stb_i <= 1'b0;
      $display("Wishbone Read [%Xh] = %Xh at %0t", adr_i, dat_o, $time);
      @(negedge ack_o);
    end
  endtask

  task WRITE;                           // Wishbone Write
    input [2:0] address;
    input [17:0] data;
    begin
      @(posedge clk);
      we_i <= 1'b1;  stb_i <= 1'b1;  adr_i <= address;  dat_i <= data;
      @(posedge ack_o);
      @(posedge clk);  stb_i <= 1'b0;
      $display("Wishbone Write %Xh to [%Xh] at %0t", dat_i, adr_i, $time);
      @(negedge ack_o);
    end
  endtask

  always #5 clk <= !clk;

  // Main Testing:
  initial
    begin
      #7
      rst_n <= 1'b1;
      $display("Register Setup");
      WRITE(5, 12'o0403);       // write timing
      WRITE(6, 12'o1705);       // read timing
      WRITE(7, 1);              // release reset
      $display("Write to MADCTL");
      WRITE(1, 8'h36);          // control byte
      WRITE(0, 8'h55);          // data byte
      lcd_di = 8'hA5;
      $display("Read from RDDPM");
      WRITE(2, 0);
      WRITE(1, 8'h0A);          // control byte
      READ(0);
      READ(0);
      WRITE(2, 0);
      $display("Write GRAM");
      WRITE(3, 18'o767574);
      WRITE(2, 0);
      WRITE(4, 0);              // direct drive all pins off
      repeat (200) @(posedge clk);
      $stop();
    end

  initial
    begin
      // Required to dump signals to EPWave
      $dumpfile("dump.vcd");
      $dumpvars(0);
    end

endmodule
