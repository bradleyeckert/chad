#include <stdio.h>
#include <stdint.h>
#include <string.h>

/*
Encrypt the "chad" format boot file using a hex 56-bit key.
The PRODUCT_ID0 byte is expected to be 0 for the plaintext input file.
It is replaced by a key ID associated with the key.
*/

#define MemorySize  (1024*1024)

uint8_t s[31];         // NFSR1
uint8_t b[90];         // NFSR2
uint8_t x, y, a;
#define KEY_LENGTH 56

void logic(void) {
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

void shift_s(uint8_t s30, uint8_t b89) {
    memmove(s, &s[1], 30);
    s[30] = s30;
    memmove(b, &b[1], 89);
    b[89] = b89;
}

/*
void HexDigit(uint8_t* p, int bits) {   // hex digit primitive
    int n = 0;
    for (int i = 0; i < bits; i++) {
        n = n << 1;
        if (*p--) n++;
    }
    if (n > 9) n += 7;
    printf("%c", n + '0');
}
void HexDigits(uint8_t* p, int digits) {
    for (int i = 0; i < digits; i++) {
        HexDigit(p, 4);
        p -= 4;
    }
}
void Dump(void) {                       // dump s and b in hex
    printf("s = ");
    HexDigit(&s[30], 3);
    HexDigits(&s[27], 7);
    printf(", b = ");
    HexDigit(&b[89], 2);
    HexDigits(&b[87], 22);
    printf("\n");
}
*/

void loadkey(uint64_t key) {            // load the key
    for (int i = 0; i < 122; i++) {
        uint8_t k;
        if (i < KEY_LENGTH)
            k = (key >> i) & 1;
        else
            k = b[120 - KEY_LENGTH];
        shift_s(k, s[0]);
    }
}

void diffuse(void) {                    // diffuse the key
    for (int i = 0; i < 128; i++) {
        logic();
        shift_s(x ^ a, y ^ a);
    }
}

uint8_t nextbyte(void) {                // next PRNG byte
    uint8_t r = 0;
    for (int i = 0; i < 8; i++) {
        logic();
        shift_s(x, y);
        r = (r << 1) + a;
    }
    return r;
}

uint32_t crc32b(uint8_t* message, size_t length) {
    uint32_t crc = 0xFFFFFFFF;			// compute CRC32
    while (length--) {
        crc = crc ^ (*message++);		// Get next byte.
        for (int j = 7; j >= 0; j--) {	// Do eight times.
            uint32_t mask = -(signed)(crc & 1);
            crc = (crc >> 1) ^ (0xEDB88320 & mask);
        }
    }
    return ~crc;
}

// Convert string to a hex uint64_t without error checking.

uint64_t ToHex(char* s) {
    uint64_t x = 0;
    char c;
    while ((c = *s++)) {
        if (c >= 'a') c -= 0x20;        // uppercase
        c -= '0';                       // 0-9, etc.
        if (c > 9) c -= 7;              // A-F
        x = (x << 4) + (c & 0x0F);
    }
    return x;
}

uint8_t mem[MemorySize];                // raw data to program

int main(int argc, char *argv[])
{
    if (argc < 5) {
	printf("Usage: 'key in_filename out_filename keyhex keyID <options>'\n\n");
	return 1;
    }
    uint32_t options = 0;
    if (argc > 5) {
    options = (uint32_t)ToHex(argv[5]);
    }
	FILE* inf = fopen(argv[1], "rb");
	if (!inf) {
		printf("Input file <%s> not found\n", argv[1]);
		return 1;
	}
	FILE* outf = fopen(argv[2], "wb");
	if (!outf) {
		printf("Output file <%s> can't be created\n", argv[2]);
        fclose(inf);
		return 1;
	}
    uint64_t key = ToHex(argv[3]);
    int keyID = (uint32_t)ToHex(argv[4]);
    loadkey(key);
    diffuse();

    char str[4];
    fread(str, 1, 4, inf);
    if (memcmp(str, "chad", 4)) {
        printf("Not a firmware file\n");
        fclose(inf);
        return 2;
    }
    if (keyID > 0xFF) {
        printf("keyID must be less than 256\n");
        fclose(inf);
        return 2;
    }

    uint32_t pid, length, crc;

    fread(&pid, 1, 4, inf);
    fread(&length, 1, 4, inf);
    fread(&crc, 1, 4, inf);
    size_t oal = fread(mem, 1, MemorySize, inf);
    fclose(inf);
    if ((length != oal) || (crc != crc32b(mem, oal))) {
        printf("Corrupted file (bad CRC)\n");
        return 2;
    }
    if ((pid >> 8) & 0xFF) {
        printf("Input keyID is not 0. File is probably already encrypted.\n");
        return 2;
    }
    pid += (keyID << 8);
    for (int i = 0; i < length; i++) {
        mem[i] ^= nextbyte();
    }

    if (options & 1) {
        printf("Format = Hex Flash\n");
        fwrite("@000000\r\n", 1, 9, outf);
        for (int i = 0; i < length; i++) {
            fprintf(outf, "%02X\r\n", mem[i]);
        }
    } else {
        fwrite("chad", 1, 4, outf);
        fwrite(&pid, 1, 4, outf);
        fwrite(&length, 1, 4, outf);
        crc = crc32b(mem, length);
        fwrite(&crc, 1, 4, outf);
        fwrite(mem, 1, length, outf);
    }
    fclose(outf);

    uint32_t keyLO = (uint32_t)key;
    uint32_t keyHI = key >> 32;
    printf("%s --> %s, key = %06X%08X, keyID = %d\n",
           argv[1], argv[2], keyHI, keyLO, keyID);

}

