// A trimmed version of the LIZARD stream cipher
// refer to https://eprint.iacr.org/2016/926.pdf
// The key length is 56 bits for export control reasons.

// Key loading is weaker than with a LIZARD implementation, so you need random keys.
// The key is loaded immediately after reset. Use clken to sync with the key data.
// If the key is all zeros, dout will stay at 8'd0 which disables decryption.
// This is not a problem: loading a 0 key just makes decryption not work.
// Matching "key.c" uses the same algorithm in C.

// It takes 8 cycles to get the next byte unless the key is 0, in which `dout`
// stays stuck at 0 and `ready` is always set. With a 0 key, plaintext can stream faster.

module gecko
#(
  parameter KEY_LENGTH = 7      // in bytes
)(
  input wire clk,
  input wire rst_n,             // async reset, active low
  input wire clken,             // clock enable
  output reg ready,             // byte is ready
  input wire [7:0] key,         // randomized key byte
  input wire next,              // trigger next byte
  output reg [7:0] dout         // PRNG output
);

  reg [30:0] s;                 // NFSR1
  reg [89:0] b;                 // NFSR2

  wire x = s[0] ^ s[2] ^ s[5] ^ s[6] ^ s[15] ^ s[17] ^ s[18] ^ s[20] ^ s[25]  // x is next s[30]
         ^ (s[8] & s[18]) ^ (s[8] & s[20]) ^ (s[12] & s[21]) ^ (s[14] & s[19]) ^ (s[17] & s[21]) ^ (s[20] & s[22])
         ^ (s[4] & s[12] & s[22])  ^  (s[4] & s[19] & s[22]) ^  (s[7] & s[20] & s[21])  ^  (s[8] & s[18] & s[22])
         ^ (s[8] & s[20] & s[22])  ^ (s[12] & s[19] & s[22]) ^ (s[20] & s[21] & s[22]) ^ (s[4] & s[7] & s[12] & s[21])
         ^ (s[4] & s[7]  & s[19] & s[21])  ^  (s[4] & s[12] & s[21] & s[22])  ^  (s[4] & s[19] & s[21] & s[22])
         ^ (s[7] & s[8]  & s[18] & s[21])  ^  (s[7] & s[8]  & s[20] & s[21])  ^  (s[7] & s[12] & s[19] & s[21])
         ^ (s[8] & s[18] & s[21] & s[22])  ^  (s[8] & s[20] & s[21] & s[22])  ^  (s[12] & s[19] & s[21] & s[22]);

  wire y = s[0] ^ b[0] ^ b[24] ^ b[49] ^ b[79] ^ b[84] ^ (b[3] & b[59]) ^ (b[10] & b[12])  // y is next b[89]
         ^ (b[15] & b[16]) ^ (b[25] & b[53]) ^ (b[35] & b[42])  ^  (b[55] & b[58]) ^ (b[60] & b[74])
         ^ (b[20] & b[22] & b[23])  ^  (b[62] & b[68] & b[72])  ^  (b[77] & b[80] & b[81] & b[83]);

  wire a = b[7] ^ b[11] ^ b[30] ^ b[40] ^ b[45] ^ b[54] ^ b[71]  // a is output bit
         ^ (b[4] & b[21])  ^  (b[9] & b[52])  ^  (b[18] & b[37])  ^  (b[44] & b[76])
         ^ b[5] ^ (b[8] & b[82])  ^  (b[34] & b[67] & b[73])  ^  (b[2] & b[28] & b[41] & b[65])
         ^ (b[13] & b[29] & b[50] & b[64] & b[75])  ^  (b[6] & b[14] & b[26] & b[32] & b[47] & b[61])
         ^ (b[1] & b[19] & b[27] & b[43] & b[57] & b[66] & b[78])
         ^ s[23] ^ (s[3] & s[16])  ^  (s[9] & s[13] & b[48])  ^  (s[1] & s[24] & b[38] & b[63]);

  reg [3:0] state;
  localparam WAIT    = 4'b0001;
  localparam LOAD    = 4'b0010;
  localparam DIFFUSE = 4'b0100;
  localparam RUN     = 4'b1000;
  reg [4:0] count;

  // Recycle the key after KEY_LENGTH bytes
  wire recycle = (count > (15 - KEY_LENGTH));
  wire [7:0] inkey = (recycle) ? key : b[(16 - KEY_LENGTH)*8 : (16 - KEY_LENGTH)*8 - 7];
  reg keyed;                    // key detected

  always @(posedge clk or negedge rst_n)
    if (!rst_n) begin
      state <= LOAD;  keyed <= 1'b0;
      ready <= 1'b0;  dout <= 8'd0;
      count <= 5'd15;
    end else if (clken) begin
      case (state)
      LOAD:                     // load the key into s and b
        begin
          s <= {inkey, s[30:8]};
          b <= {s[7:0], b[89:8]};
          if (count)            // after KEY_LENGTH bits, the key is looped
            count <= count - 1'b1; // to fill out the internal state
          else begin
            count <= 5'd31;
            if (keyed)
              state <= DIFFUSE;
            else if (inkey)
              state <= DIFFUSE;
            else begin          // zero key detected, nothing to do
              state <= WAIT;
              ready <= 1'b1;
            end
          end
          if (inkey)            // detect non-zero key
            keyed <= 1'b1;
        end
      DIFFUSE:                  // diffuse the key using 32 iterations
        begin
          s <= {x ^ a, s[30:1]};
          b <= {y ^ a, b[89:1]};
          if (count)
            count <= count - 1'b1;
          else begin
            state <= RUN;
            count <= 5'd7;
          end
        end
      RUN:                      // one pseudorandom bit per clock
        begin
          s <= {x, s[30:1]};
          b <= {y, b[89:1]};
          dout <= {dout[6:0], a};
          if (count)
            count <= count - 1'b1;
          else begin
            state <= WAIT;
            ready <= 1'b1;
          end
        end
      WAIT:                     // wait for the next byte trigger
        if (next & keyed) begin
          count <= 5'd7;
          ready <= 1'b0;
          state <= RUN;
        end
      endcase
    end

endmodule
