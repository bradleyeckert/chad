// Chad processor                                               10/17/2021 BNE
// License: This code is a gift to mankind and is dedicated to peace on Earth.

module chad
#(
  parameter WIDTH = 18,                 // cell size, can be 16 to 32
  parameter DEPTH = 20                  // depth of both stacks (16 should be enough)
)(
  input  wire clk,
  input  wire resetq,                   // Processor reset, async active low
  input  wire hold,                     // Processor hold (insert wait states)
  output wire io_rd,                    // I/O read strobe: get io_din
  output wire io_wr,                    // I/O write strobe: register din
  output wire [14:0] mem_addr,          // Data memory address
  output wire mem_rd,                   // Data memory read enable
  output wire mem_wr,                   // Data memory write enable
  output reg [((WIDTH + 7) / 8) - 1:0] memlane,
  output wire [WIDTH-1:0] dout,         // Data memory & I/O out (from N)
  input  wire [WIDTH-1:0] mem_din,      // Data memory in
  input  wire [WIDTH-1:0] io_din,       // I/O data in
  output wire [12:0] code_addr,         // Code memory address
  input  wire [15:0] insn,              // Code memory data
  input  wire irq,                      // Interrupt request
  input  wire [3:0] ivec,               // Interrupt vector that goes with irq
  output wire iack,                     // Interrupt acknowledge
  output wire copgo,                    // Coprocessor trigger, select = insn[10:0]
  input  wire [WIDTH-1:0] cop,          // Coprocessor output
  output wire [WIDTH-1:0] copa,         // Coprocessor A input
  output wire [WIDTH-1:0] copb,         // Coprocessor B input
  output wire [WIDTH-1:0] copc          // Coprocessor C input
);

// `define LOGGING

  reg  [4:0] dsp, rsp;                  // Stack depth tracking
  reg  [WIDTH-1:0] st0;                 // Top of data stack
  reg  [WIDTH-1:0] st0N;
  reg  dstkW;                           // D stack write

  reg  [12:0] pc, pcN;
  reg  rstkW;                           // R stack write
  wire [WIDTH-1:0] rstkD;               // R stack write value
  reg  reboot;
  wire [12:0] pc_plus_1 = pc + 13'd1;
  reg  [WIDTH-1:0] areg;                // W and carry registers
  reg  carry, co;
  reg  [WIDTH-13:0] lex;

  assign mem_addr = (WIDTH == 32) ? st0[16:2] : st0[15:1];
  assign code_addr = pcN;
  reg [1:0] dspI, rspI;

  // The D and R stacks
  wire [WIDTH-1:0] st1, rst0;
  stack #(WIDTH, DEPTH) dstack (.clk(clk), .hold(hold),
    .rd(st1), .we(dstkW), .wd(st0), .delta(dspI));
  stack #(WIDTH, DEPTH) rstack (.clk(clk), .hold(hold),
    .rd(rst0), .we(rstkW), .wd(rstkD), .delta(rspI));

  // Coprocessor
  assign copgo = (insn[15:11] == 5'b10110);
  assign copa = st0;
  assign copb = st1;
  assign copc = areg;

  wire [WIDTH:0] sum  = st1 + st0;	// N + T

  always @*
  begin // carry out
    case (insn[11:8])
    4'b0011: co = st0[WIDTH-1];
    4'b0100: co = sum[WIDTH];
    default: co = st0[0];
    endcase
  end

  wire [WIDTH-1:0] st3 = (insn[12]) ? {WIDTH{1'b1}} : st1;
  wire msbin = (insn[12]) ? carry : st0[WIDTH-1];
  wire lsbin = (insn[12]) ? carry : 1'b0;
  wire [31:0] t32 = st0; // full 32-bit swaps, prune later
  wire [31:0] swapw = {t32[15:0], t32[31:16]};
  wire [31:0] swapb = {t32[23:16], t32[31:24], t32[7:0], t32[15:8]};
  wire [WIDTH-13:0] lsign = (insn[12]) ? {(WIDTH-12){1'b1}} : lex;

  always @*
  begin // Compute the new value of st0
    casez (insn[15:13])
    3'b000: begin
      case (insn[11:8])
      4'b0000: st0N = (insn[12]) ? cop : st0;           // T, COP
      4'b0001: st0N = (insn[12]) ? carry : {WIDTH{st0[WIDTH-1]}}; // 0<, C
      4'b0010: st0N = {msbin, st0[WIDTH-1:1]};		// T2/, cT2/
      4'b0011: st0N = {st0[WIDTH-2:0], lsbin};		// T2*, T2*c
      4'b0100: st0N = sum[WIDTH-1:0];
      4'b0101: st0N = st0 & st1;			// T&N
      4'b0110: st0N = st0 ^ st3;			// T^N, ~T
      4'b1000: st0N = (insn[12]) ? swapw[WIDTH-1:0] : swapb[WIDTH-1:0];
      4'b1001: st0N = (insn[12]) ? areg : st1;		// N, W
      4'b1010: st0N = rst0;                             // R
      4'b1011: st0N = rst0 + {WIDTH{1'b1}};             // R-1
      4'b1100: st0N = io_din;
      4'b1101: st0N = mem_din;
      4'b1110: st0N = (st0) ? {WIDTH{1'b0}} : {WIDTH{1'b1}}; // 0=
      4'b1111: st0N = {{(WIDTH - 13){1'b0}}, rsp, 3'b0, dsp};
      default: st0N = {WIDTH{1'bx}};                    // abnormal
      endcase
    end
    3'b01?:  st0N = {lsign, insn[11:0]};	        // literal or trap
    3'b100:  st0N = st1;          			// conditional jump
    default: st0N = st0;                                // other
    endcase
  end

  wire isALU =      (insn[15:13] == 3'b0);
  wire func_T_N =   (insn[7:4] == 1);                   // T->N
  wire func_T_R =   (insn[7:4] == 2);                   // T->R
  wire func_iow =   (insn[7:4] == 3) & isALU;           // N->io[T]
  wire func_rd =    (insn[7:4] == 4) & isALU;           // _MEMRD_
  wire func_wr =    (insn[7:4] == 5) & isALU;           // N->[T]
  wire func_wr_b =  (insn[7:4] == 6) & isALU;           // N->[T]B
  wire func_wr_h =  (insn[7:4] == 7) & isALU;           // N->[T]S
  wire func_co =    (insn[7:4] == 10) & isALU;          // co
  wire func_ior =   (insn[7:4] == 13) & isALU;          // _IORD_
  wire func_T_A =   (insn[7:4] == 15) & isALU;          // T->A

  assign mem_rd = !reboot & func_rd;
  assign mem_wr = !reboot & (func_wr | func_wr_b | func_wr_h);
  assign dout = st1;
  assign io_wr =  !reboot & func_iow;
  assign io_rd =  !reboot & func_ior;

  always @*
  begin
    if (WIDTH == 32) begin
      casez({insn[7:4], st1[1:0], isALU})
      7'b????_??_0: memlane = 4'b1111;
      7'b0110_00_1: memlane = 4'b0001;
      7'b0110_01_1: memlane = 4'b0010;
      7'b0110_10_1: memlane = 4'b0100;
      7'b0110_11_1: memlane = 4'b1000;
      7'b0111_00_1: memlane = 4'b0011;
      7'b0111_10_1: memlane = 4'b1100;
      default:      memlane = 4'b1111;
      endcase
    end else begin
      casez({insn[7:4], st1[0], isALU})
      6'b????_?_0: memlane = 4'b1111;
      6'b0110_0_1: memlane = 4'b0001;
      6'b0110_1_1: memlane = 4'b0010;
      6'b0111_0_1: memlane = 4'b0011;
      default:     memlane = 4'b1111;
      endcase
    end
  end

  assign rstkD = isALU ? st0 : {{(WIDTH - 13){1'b0}}, pc_plus_1};
  wire return = isALU & (insn[3:2] == 2'b10);
  wire ack =       rst0[WIDTH-1:13] ? 1'b0 : irq & return;
  wire exception = rst0[WIDTH-1:13] ? return : 1'b0;
  assign iack = ack & ~hold;

  always @*
  begin
    casez ({insn[15:13]})               // adjust data stack pointer
    3'b000:  {dstkW, dspI} = {func_T_N, insn[1:0]};     // ALU
    3'b100:  {dstkW, dspI} = {1'b0,     2'b11};         // if
    3'b01?:  {dstkW, dspI} = {1'b1,     2'b01};         // imm, trap
    default: {dstkW, dspI} = {1'b0,     2'b00};
    endcase

    casez ({insn[15:13], ack | exception})
    6'b000_0: {rstkW, rspI} = {func_T_R, insn[3:2]};    // ALU
    6'b?11_?: {rstkW, rspI} = {1'b1,     2'b01};        // trap, call
    default:  {rstkW, rspI} = {1'b0,     2'b00};
    endcase

    casez ({reboot, insn[15:13], insn[3:2], ack, exception, |st0})
    9'b1_???_??_?_?_?: pcN = 0;
    9'b0_000_10_0_0_?: pcN = rst0[12:0];                // ret
    9'b0_000_10_1_0_?: pcN = ivec;
    9'b0_000_10_?_1_?: pcN = 13'd18;                    // exception
    9'b0_011_??_?_?_?: pcN = {12'd8, insn[12]};         // trap
    9'b0_100_??_?_?_0,                                  // if
    9'b0_11?_??_?_?_?: pcN = insn[12:0];                // jump|call
    default:           pcN = pc_plus_1;
    endcase
  end

`ifdef LOGGING
  reg [WIDTH-1:0] nos;
  integer f, i, j;
`endif

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      reboot <= 1'b1;
      { pc, st0 } <= 0;
      { dsp, rsp } <= 0;
      { carry, areg } <= 0;
      lex <= 0;
    end else begin
`ifdef LOGGING
      if (reboot) begin
        f = $fopen("simlog.txt","w");
        i = 10000;
      end else
      if ((i) && (!hold)) begin
        for (j = 0; j < WIDTH; j = j + 1)
          nos[j] = (st1[j] === 1'b1) ? 1'b1 : 1'b0; // alias x to 0
        $fwrite(f,"PC=%h,insn=%h,T=%h,N=%h,R=%h,sp=%x,rp=%x\n", pc, insn, st0, nos, rst0, dsp, rsp);
        if (i == 1) $fclose(f);
        i = i - 1;
      end
`endif
      reboot <= 0;
      if (!hold) begin
        { pc, st0 } <= { pcN, st0N };
        dsp <= dsp + {{4{dspI[1]}}, (dspI[1] | dspI[0])};
        rsp <= rsp + {{4{rspI[1]}}, (rspI[1] | rspI[0])};
        if (func_co)
          carry <= co;
        if (func_T_A)
          areg <= st0;
        if (insn[15:12] == 4'b1010)
          lex <= {lex, insn[11:0]};
        else
          lex <= 0;
      end
    end
  end
endmodule
