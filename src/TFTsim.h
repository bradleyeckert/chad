#ifndef  __TFTSIM_H__
#define  __TFTSIM_H__
// Header file for TFTsim.c

// Target BMP = 24-bit W x H if even type, H x W if odd type
// format = bus width {8, 16, 9, 18, 8} and words/pixel: {2, 1, 2, 1, 3}
// Type: 0=portrait, 1=landscape
// width (W) must be a multiple of 4.
int TFTLCDsetup(uint8_t* BMP, int format, int type, int width, int height);

// Send data to the controller.
void TFTLCDwrite(uint32_t n);


#endif
