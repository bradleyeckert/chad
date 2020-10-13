// Modified J1

module chad
#(
  parameter WIDTH = 18,                 // cell size, can be 16 to 32
  parameter DEPTH = 16                  // depth of both stacks
)(
  input  wire clk,
  input  wire resetq,                   // Processor reset, async active low
  input  wire hold,                     // Processor hold (insert wait states)
  output wire io_rd,                    // I/O read strobe: get io_din
  output wire io_wr,                    // I/O write strobe: register din
  output wire [14:0] mem_addr,          // Data memory address
  output wire mem_rd,                   // Data memory read enable
  output wire mem_wr,                   // Data memory write enable
  output wire [WIDTH-1:0] dout,         // Data memory & I/O out (from N)
  input  wire [WIDTH-1:0] mem_din,      // Data memory in
  input  wire [WIDTH-1:0] io_din,       // I/O data in
  output wire [14:0] code_addr,         // Code memory address
  input  wire [15:0] insn               // Code memory data
);

  reg  [4:0] dsp, rsp;                  // Stack depth tracking
  reg  [WIDTH-1:0] st0;                 // Top of data stack
  reg  [WIDTH-1:0] st0N;
  reg  dstkW;                           // D stack write

  reg  [14:0] pc, pcN;
  reg  rstkW;                           // R stack write
  wire [WIDTH-1:0] rstkD;               // R stack write value
  reg  reboot;
  wire [14:0] pc_plus_1 = pc + 15'd1;

  assign mem_addr = (WIDTH == 32) ? st0[16:2] : st0[15:1];
  assign code_addr = pcN;
  reg [1:0] dspI, rspI;

  // The D and R stacks
  wire [WIDTH-1:0] st1, rst0;
  stack #(WIDTH, DEPTH) dstack (.clk(clk), .hold(hold),
    .rd(st1), .we(dstkW), .wd(st0), .delta(dspI));
  stack #(WIDTH, DEPTH) rstack (.clk(clk), .hold(hold),
    .rd(rst0), .we(rstkW), .wd(rstkD), .delta(rspI));

// 0xpppppR xwwwrrss = ALU instruction
//     x = unused
//     p = 5-bit ALU operation select
//     R = return
//     w = strobe select
//     r = return stack displacement
//     s = data stack displacement
// 100nnnnn nnnnnnnn = jump
//     PC = (lex<<13) | n
// 101nnnnn nnnnnnnn = conditional jump
// 110nnnnn nnnnnnnn = call, same as jump but pushes PC.
// 11100nnn nnnnnnnn = literal extension
//     lex = (lex<<11) | n;  Any other instruction clears lex.
// 11101nnn nnnnnnnn = reserved for user's coprocessor
// 1111nnnR nnnnnnnn = unsigned literal (imm)
//     T = (lex<<13) | n
//     R = return

  reg [WIDTH-1:0] wreg;
  reg [WIDTH-12:0] lex;
  reg carry, co;

  wire [WIDTH:0] sum  = st1 + st0;	// N + T
  wire [WIDTH:0] diff = st1 - st0;	// N - T

  always @*
  begin // carry out
    case (insn[12:9])
    4'b0010: co = st0[0];
    4'b0011: co = st0[WIDTH-1];
    4'b1000: co = sum[WIDTH];
    4'b1001: co = diff[WIDTH];
    default: co = 1'b0;
    endcase
  end

  wire [WIDTH-1:0] st3 = (insn[13]) ? {WIDTH{1'b1}} : st1;
  wire msbin = (insn[13]) ? carry : st0[WIDTH-1];
  wire lsbin = (insn[13]) ? carry : 1'b0;
  wire [31:0] t32 = st0; // full 32-bit swaps, prune later
  wire [31:0] swapw = {t32[15:0], t32[31:16]};
  wire [31:0] swapb = {t32[23:16], t32[31:24], t32[7:0], t32[15:8]};

  always @*
  begin // Compute the new value of st0
    if (insn[15])
      casez (insn[14:12])
      3'b00?:  st0N = st0;          			// jump
      3'b01?:  st0N = st1;          			// conditional jump
      3'b10?:  st0N = st0;          			// call
      3'b110:  st0N = st0;          			// litx
      default: st0N = {lex, insn[11:9], insn[7:0]};	// literal
      endcase
    else // ALU operations, insn[14] not currently used
      case (insn[12:9])
      4'b0000: st0N = (insn[13]) ? {WIDTH{1'b0}} : st0; // T, COP
      4'b0001: st0N = (insn[13]) ? carry : {WIDTH{st0[WIDTH-1]}}; // 0<, C
      4'b0010: st0N = {msbin, st0[WIDTH-1:1]};		// T2/, cT2/
      4'b0011: st0N = {st0[WIDTH-2:0], lsbin};		// T2*, T2*c
      4'b0100: st0N = (insn[13]) ? wreg : st1;		// N, W
      4'b0101: st0N = st0 ^ st3;			// T^N, ~T
      4'b0110: st0N = st0 & st1;			// T&N
      4'b0111: st0N = (insn[13]) ? swapw[WIDTH-1:0] : swapb[WIDTH-1:0];
      4'b1000: st0N = sum[WIDTH-1:0];
      4'b1001: st0N = diff[WIDTH-1:0];
      4'b1010: st0N = rst0;                             // R
      4'b1011: st0N = rst0 + {WIDTH{1'b1}};             // R-1
      4'b1100: st0N = io_din;
      4'b1101: st0N = mem_din;
      4'b1110: st0N = (st0) ? {WIDTH{1'b1}} : {WIDTH{1'b0}}; // 0=
      4'b1111: st0N = {{(WIDTH - 13){1'b0}}, rsp, 3'b000, dsp};
      default: st0N = {WIDTH{1'bx}};                    // abnormal
      endcase
  end

  wire func_T_N =   (insn[6:4] == 1);                   // T->N
  wire func_T_R =   (insn[6:4] == 2);                   // T->R
  wire func_write = (insn[6:4] == 3) & ~insn[15];       // N->[T]
  wire func_read =  (insn[6:4] == 4) & ~insn[15];       // _MEMRD_
  wire func_iow =   (insn[6:4] == 5) & ~insn[15];       // N->io[T]
  wire func_ior =   (insn[6:4] == 6) & ~insn[15];       // _IORD_
  wire func_co =    (insn[6:4] == 7) & ~insn[15];       // co
  wire islex =      (insn[15:12] == 4'b1111);

  assign mem_rd = !reboot & func_read;
  assign mem_wr = !reboot & func_write;
  assign dout = st1;
  assign io_wr =  !reboot & func_iow;
  assign io_rd =  !reboot & func_ior;

  assign rstkD = (insn[15]) ? {{(WIDTH - 16){1'b0}}, pc_plus_1, 1'b0} : st0;

  always @*
  begin
    casez ({insn[15:12]})
    4'b0???: {dstkW, dspI} = {func_T_N,  insn[1:0]};
    4'b101?: {dstkW, dspI} = {1'b0,      2'b11};        // if
    4'b1111: {dstkW, dspI} = {1'b1,      2'b01};        // imm
    default: {dstkW, dspI} = {1'b0,      2'b00};
    endcase

    casez ({insn[15:12], insn[8]})
    5'b0???_?: {rstkW, rspI} = {func_T_R,  insn[3:2]};
    5'b110?_?: {rstkW, rspI} = {1'b1,      2'b01};      // call
    5'b1111_1: {rstkW, rspI} = {1'b0,      2'b11};      // lit+ret
    default:   {rstkW, rspI} = {1'b0,      2'b00};
    endcase

    casez ({reboot, insn[15:12], insn[8], |st0})
    7'b1_????_?_?: pcN = 0;
    7'b0_100?_?_?, // jump, call, if
    7'b0_110?_?_?,
    7'b0_101?_?_0: pcN = {2'd0, insn[12:0]};
    7'b0_1111_1_?, // lit+ret
    7'b0_0???_1_?: pcN = rst0[15:1];
    default:       pcN = pc_plus_1;
    endcase
  end

  always @(negedge resetq or posedge clk)
  begin
    if (!resetq) begin
      reboot <= 1'b1;
      { pc, st0 } <= 0;
      { dsp, rsp } <= 0;
      { carry, wreg } <= 0;
      lex <= 0;
    end else begin
      reboot <= 0;
      if (!hold) begin
        { pc, st0 } <= { pcN, st0N };
        dsp <= dsp + {dspI[1], dspI[1], dspI[1], dspI};
        rsp <= rsp + {rspI[1], rspI[1], rspI[1], rspI};
        if (func_co)
          { carry, wreg } <= { co, st0 };
        if (WIDTH < 23)
          if (islex) lex <= insn[WIDTH-12:0];
          else lex <= 0;
        else
          if (islex) lex <= {lex[WIDTH-1:WIDTH-11], insn[10:0]};
          else lex <= 0;
      end
    end
  end
endmodule
