/*
LCD module simulator

TFT LCD modules with built-in RAM are controlled over a parallel bus by sending
commands and data to a controller chip.
A D/C (or RS) pin distinguishes between commands and data.
There are many different kinds of controllers and LCD modules on the market.
The smallest ones use serial or 8-bit data.
The largest ones use 16-bit or 18-bit data.

This simulator keeps its data in a 24-bit BMP image that can be displayed in any
Windows app. To initialize the module, call TFTLCDsetup with a starting BMP,
controller type, and the data format.

Your hardware will talk to the LCD module by writing to an output port that is
between 9 and 19 bits wide. The MSB of that is the inverse of D/C and the rest
is data. That way, a '1' means command and a '0' means data.

The controller types are:
0 to 3 = ILI9341 (240 x 320 TFT), rotated by (type%4)*90 degrees.
*/

#include <stddef.h>
#include <stdint.h>

#define reverseRGB  /* define to reverse the RGB order for OpenGL */

static int LCDwidth;
static int LCDheight;

static int typeSelect;					// 0 = ILI9341
static uint8_t* bmp = NULL;				// raw image is 24-bit BMP format

static uint16_t colBegin, colEnd, colPtr;
static uint16_t rowBegin, rowEnd, rowPtr;
static uint8_t MX;						// Column Address Order
static uint8_t MY;						// Row Address Order
static uint8_t MV;						// Row / Column Exchange
static uint8_t rotation;				// orientation to BMP

static uint8_t format;					// Pixel format over data bus
#define PACKED16 0
#define WHOLE16  1
#define PACKED18 2
#define WHOLE18  3
#define SERIAL8  4

static void resetLCD(void) {
	colPtr = colBegin = 0;  colEnd = LCDwidth - 1;
	rowPtr = rowBegin = 0;  rowEnd = LCDheight - 1;
	MX = MY = MV = 0;
}

static uint8_t* boilerptr;

static void BoilerWr(uint32_t x) {
	for (int i = 0; i < 4; i++) {
		*boilerptr++ = x & 0xFF;
		x >>= 8; // little endian write
	}
}


// Set up the TFT module
// RETURN = 0 if everything went okay, otherwise an error.

int TFTLCDsetup(uint8_t* BMP, int format, int type, int width, int height) {
	rotation = type & 3;
	typeSelect = type >> 2;
	if (typeSelect) return 1;
	format = format;
	bmp = BMP;
	LCDwidth  = width;
	LCDheight = height;
	uint32_t pixels = width * height;
	boilerptr = BMP;	// populate boilerplate for BMP
	*boilerptr++ = 'B';
	*boilerptr++ = 'M';
	BoilerWr(pixels * 3);  BoilerWr(0);  BoilerWr(54);  BoilerWr(40);
	if (rotation & 1) {
		BoilerWr(height);
		BoilerWr(width);
	}
	else {
		BoilerWr(width);
		BoilerWr(height);
	}
	BoilerWr(0x180001);  BoilerWr(0);  BoilerWr(pixels);
	BoilerWr(0);  BoilerWr(0);  BoilerWr(0);  BoilerWr(0);
	resetLCD();
	return 0;
}

static int cfgstate;
static uint8_t red;						// incoming colors
static uint8_t green;
static uint8_t blue;

static int bumpCol(void) {
	colPtr++;
	if (colPtr > colEnd) {
		colPtr = colBegin;
		return 1;
	}
	return 0;
}

static int bumpRow(void) {
	rowPtr++;
	if (rowPtr > rowEnd) {
		rowPtr = rowBegin;
		return 1;
	}
	return 0;
}

// Plot the pixel to the BMP at (colPtr, rowPtr) and bump to the next position
static void plotColor(void) {
	int x = colPtr;
	int y = rowPtr;
	int w = LCDwidth;
	int h = LCDheight;
	if (MX)
		x = w - x;
	if (MY)
		y = h - y;
	int t;
	switch (rotation) {
	case 1:
		t = w;  w = h;  h = t;			// swap w and h
		t = x;  x = y;  y = (h - t - 1);// rotate (x,y) left 90 degrees
		break;
	case 2:
		x = w - x - 1;  y = h - y - 1;	// rotate 180 degrees
	case 3:
		t = w;  w = h;  h = t;			// swap w and h
		t = x;  x = (w - y - 1);  y = t;// rotate (x,y) right 90 degrees
	}
	if (bmp != NULL) {					// ignore if not initialized
		uint8_t* p = &bmp[54 + 3 * (w * (h - y - 1) + x)];
#ifdef reverseRGB
		* p++ = red;  *p++ = green;  *p++ = blue;
#else
		* p++ = blue;  *p++ = green;  *p++ = red;
#endif
		if (MV) {
			int bump = bumpRow();
			if (bump) bumpCol();
		}
		else {
			int bump = bumpCol();
			if (bump) bumpRow();
		}
	}
	cfgstate = 9;
}

static const uint32_t RSpos[] = {
	(1 << 8),
	(1 << 16),
	(1 << 9),
	(1 << 18),
	(1 << 8) };

// Raw LCD write:
// In the controller, when RS = �1�, data is selected. When RS = �0�, command.
// This bit is inverted for the convenience of application code.
// see RSpos for which bit of n is used as a function of format.
void TFTLCDwrite(uint32_t n) {
	if (n & RSpos[format]) {			// command
		cfgstate = 0;
		switch (n & 0xFF) {
		case 0x2A: cfgstate = 1; break; // Column Address Set
		case 0x2B: cfgstate = 5; break; // Row Address Set
		case 0x2C: cfgstate = 9;        // Memory Write
			colPtr = colBegin;
			rowPtr = rowBegin;
			break;
		case 0x36:						// Memory Access Control
			MY = n & 0x80;  MX = n & 0x40;  MV = 0x20;  break;
		default: break;
		}
	}
	else {								// data
		switch (cfgstate++) {
		case 1: colBegin  = n << 8;  break;
		case 2: colBegin |= n & 0xFF;  break;
		case 3: colEnd  = n << 8;  break;
		case 4: colEnd |= n & 0xFF;  cfgstate = 0;  break;
		case 5: rowBegin  = n << 8;  break;
		case 6: rowBegin |= n & 0xFF;  break;
		case 7: rowEnd  = n << 8;  break;
		case 8: rowEnd |= n & 0xFF;  cfgstate = 0;  break;
		case 9:
			switch (format) {
			case PACKED16:				// RRRRRGGG
				red = n & 0xF8;
				green = (n & 7) << 5;  break;
			case WHOLE16:				// RRRRRGGG_GGGBBBBB
				red = (n >> 9) & 0xF8;
				green = (n >> 3) & 0xFC;
				blue = (n << 3) & 0xF8;
				plotColor();  break;
			case PACKED18:				// RRRRRRGGG
				red = (n >> 1) & 0xFC;
				green = (n & 7) << 5;  break;
			case WHOLE18:				// RRRRRRGGG_GGGBBBBBB
				red = (n >> 10) & 0xFC;
				green = (n >> 4) & 0xFC;
				blue = (n << 2) & 0xFC;
				plotColor();  break;
			default: red = n & 0xF8;  break;
			} break;
		case 10:
			switch (format) {
			case PACKED16:				// GGGBBBBB
				green |= (n >> 3) & 0x1C;
				blue = (n << 3) & 0xF8;
				plotColor();  break;
			case PACKED18:				// GGGBBBBBB
				green |= (n >> 4) & 0x1C;
				blue = (n << 2) & 0xFC;
				plotColor();  break;
			default: green = n & 0xF8;  break;
			} break;
		case 11:
			blue = n & 0xFC;
			plotColor();  break;
		default:						// idle
			cfgstate = 0;
		}
	}
}


