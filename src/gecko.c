#include <stdio.h>
#include <stdint.h>
#include <string.h>

/*
Bit-wise simulation of the gecko stream cypher.
*/

static uint8_t s[31];                   // NFSR1
static uint8_t b[90];                   // NFSR2
static uint8_t x, y, a;
#define KEY_LENGTH 7

static uint8_t* p = s;

static void nybl(int bits) {
    int n = 0;
    for (int i = 0; i < bits; i++)      // hex digit
        n = (n << 1) + *--p;
    printf("%X", n);
}
static void nybls(int digits) {
    for (int i = 0; i < digits; i++)
        nybl(4);
}

void GeckoState(void) {                 // dump internal state in hex format
    printf("s = ");    p = &s[31];  nybl(3); nybls(7);
    printf(", b = ");  p = &b[90];  nybl(2); nybls(22);
    printf("\n");
}

static void logic(void) {
  x = s[0] ^ s[2] ^ s[5] ^ s[6] ^ s[15] ^ s[17] ^ s[18] ^ s[20] ^ s[25]  // x is next s[30]
    ^ (s[8] & s[18]) ^ (s[8] & s[20]) ^ (s[12] & s[21]) ^ (s[14] & s[19]) ^ (s[17] & s[21]) ^ (s[20] & s[22])
    ^ (s[4] & s[12] & s[22])  ^  (s[4] & s[19] & s[22]) ^  (s[7] & s[20] & s[21])  ^  (s[8] & s[18] & s[22])
    ^ (s[8] & s[20] & s[22])  ^ (s[12] & s[19] & s[22]) ^ (s[20] & s[21] & s[22]) ^ (s[4] & s[7] & s[12] & s[21])
    ^ (s[4] & s[7]  & s[19] & s[21])  ^  (s[4] & s[12] & s[21] & s[22])  ^  (s[4] & s[19] & s[21] & s[22])
    ^ (s[7] & s[8]  & s[18] & s[21])  ^  (s[7] & s[8]  & s[20] & s[21])  ^  (s[7] & s[12] & s[19] & s[21])
    ^ (s[8] & s[18] & s[21] & s[22])  ^  (s[8] & s[20] & s[21] & s[22])  ^  (s[12] & s[19] & s[21] & s[22]);

  y = s[0] ^ b[0] ^ b[24] ^ b[49] ^ b[79] ^ b[84] ^ (b[3] & b[59]) ^ (b[10] & b[12])  // y is next b[89]
    ^ (b[15] & b[16]) ^ (b[25] & b[53]) ^ (b[35] & b[42])  ^  (b[55] & b[58]) ^ (b[60] & b[74])
    ^ (b[20] & b[22] & b[23])  ^  (b[62] & b[68] & b[72])  ^  (b[77] & b[80] & b[81] & b[83]);

  a = b[7] ^ b[11] ^ b[30] ^ b[40] ^ b[45] ^ b[54] ^ b[71]
    ^ (b[4] & b[21])  ^  (b[9] & b[52])  ^  (b[18] & b[37])  ^  (b[44] & b[76])
    ^ b[5] ^ (b[8] & b[82])  ^  (b[34] & b[67] & b[73])  ^  (b[2] & b[28] & b[41] & b[65])
    ^ (b[13] & b[29] & b[50] & b[64] & b[75])  ^  (b[6] & b[14] & b[26] & b[32] & b[47] & b[61])
    ^ (b[1] & b[19] & b[27] & b[43] & b[57] & b[66] & b[78])
    ^ s[23] ^ (s[3] & s[16])  ^  (s[9] & s[13] & b[48])  ^  (s[1] & s[24] & b[38] & b[63]);
}

static void shift_s(uint8_t s30, uint8_t b89) {
    memmove(s, &s[1], 30);
    s[30] = s30;
    memmove(b, &b[1], 89);
    b[89] = b89;
}

uint8_t GeckoByte(void) {               // next PRNG byte
    uint8_t r = 0;
    for (int i = 0; i < 8; i++) {
        logic();
        shift_s(x, y);
        r = (r << 1) + a;
    }
    return r;
}

void GeckoLoad(uint64_t key) {          // load the key
    for (int i = 0; i < 128; i++) {
        uint8_t k;
        if (i < (KEY_LENGTH*8))
            k = (key >> i) & 1;
        else
            k = b[121 - KEY_LENGTH*8];
        shift_s(k, s[0]);
    }
    for (int i = 0; i < 32; i++) {      // diffuse the key
        logic();
        shift_s(x ^ a, y ^ a);
    }
}

