#ifndef  __GUI_H__
#define  __GUI_H__
// Header file for gui.c

// A receiver for chars sent when a button is pressed or released.
static void GUIbuttonHandler(char c);

// LED status input is by calling a function:
void GUIsetStatusLEDs(uint16_t sr);

// Launch and run the gui window, user closes it.
void GUIrun(void);

// Load a test bitmap from a file "lcdimage.bmp".
void GUILCDload(char* s);

// LCDwrite uses a RS (cmd/data) select on bit 8 and data on bits 7:0 in:
void GUILCDwrite(uint16_t n);

#endif
