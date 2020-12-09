// GLUT-based GUI

#include "glut.h"
#include <stdio.h>
#include <stdint.h>
#include "TFTsim.h"
#include <windows.h>
#define MORESAFE

#define BUTTONS  8                  /* Number of buttons in the system       */
#define BTSIZE   0.14f              /* Button size (half of width or height) */
#define BTCOLOR1 0.3f, 0.3f, 0.3f   /* Color for button not pressed          */
#define BTCOLOR0 0.6f, 0.6f, 0.6f   /* Color for button pressed              */
#define LANEPITCH 0.24f
#define AACENTER -0.32f             /* center of LCD AA in X                 */
#define AAWIDTH  0.55f
#define AAHEIGHT (AAWIDTH * 1.33f)
#define WSIZE    (int)(0.5f + 320.0 / AAWIDTH) // for 1:1 display of LCD

#define LEDCOLOR0 0.5f, 0.5f, 0.5f   /* LED color when off                   */
#define LEDCOLORR 1.0f, 0.0f, 0.0f   /* LED color when red                   */
#define LEDCOLORG 0.0f, 1.0f, 0.0f   /* LED color when green                 */
#define LEDCOLORY 1.0f, 1.0f, 0.0f   /* LED color when yellow                */
#define LEDSIZE  0.03f
#define LEDPITCH 0.1f

#define TFTX 320
#define TFTY 480

// The GL frame is centered at (0,0) and spans {-1,1} in both X and Y.

// Button output is to an external function GUIbuttonHandler(char cmd).

#ifndef GUIbuttonHandler            // define a test output
static void GUIbuttonHandler(char c) {
    printf("%c", c);
}
#endif

static uint16_t LEDstatus = 2;

// LED status input is by calling a function:
void LEDstripWrite(uint16_t sr) {
    LEDstatus = sr;
}

// LEDs D1-D12 line up with switches 4, 5, 6, and 7 respectively top to bottom
// LED bits (0=off):
// 15 D12   G3 11
// 14 D10   R3 9
// 13 D9    G2 8
// 12 D5    Y1 4
// 11 D6    G1 5
// 10 D7    R2 6
//  9 D8    Y2 7
//  8 D11   Y3 10
// 7:5 ---     255
//  4 D4    R1 3
//  3 D3    G0 2
//  2 D2    Y0 1
//  1 D1    R0 0
//  0 ---      255

uint8_t LEDpos[16] = {255, 0, 1, 2, 3, 255, 255, 255, 10, 7, 6, 5, 4, 8, 9, 11};
float LEDoffset[3] = { -LEDPITCH , 0.0f, LEDPITCH };

static void DisplayLEDs(uint16_t sr) {
    for (uint8_t i = 0; i < 16; i++) {
        uint8_t p = LEDpos[i];
        if (p < 16) {
            int button = 3 - 2 * (p / 3); // 0..3 = 3, 1, -1, -3
            GLfloat x = 0.85f;
            GLfloat y = (LANEPITCH * button) + LEDoffset[p % 3];
            if (sr & 1) {
                switch (p % 3) {
                case 0: glColor3f(LEDCOLORR);  break;
                case 1: glColor3f(LEDCOLORY);  break;
                default: glColor3f(LEDCOLORG);
                }
            }
            else {
                glColor3f(LEDCOLOR0);
            }
            glBegin(GL_POLYGON);
            glVertex3f(-LEDSIZE + x, -LEDSIZE + y, 0.0);
            glVertex3f(-LEDSIZE + x, LEDSIZE + y, 0.0);
            glVertex3f(LEDSIZE + x, LEDSIZE + y, 0.0);
            glVertex3f(LEDSIZE + x, -LEDSIZE + y, 0.0);
            glEnd();
        }
        sr >>= 1;
    }
}

//##############################################################################
// Pushbuttons

struct Pushbutton_t {
    GLfloat x;
    GLfloat y;
    int state; // 0 = pressed, 1 = released
};

struct Pushbutton_t Buttons[BUTTONS];

static void LoadButton(int i, GLfloat x, GLfloat y) {
    Buttons[i].x = x;
    Buttons[i].y = y;
    Buttons[i].state = 1;
}

static void InitButtons(void) {
    LoadButton(0, -0.54f, -(3 * LANEPITCH));
    LoadButton(1, -0.1f, -(3 * LANEPITCH));
    LoadButton(2, -0.54f, (3 * LANEPITCH));
    LoadButton(3, -0.1f, (3 * LANEPITCH));
    LoadButton(4,  0.5f, (3 * LANEPITCH));
    LoadButton(5,  0.5f,  LANEPITCH);
    LoadButton(6,  0.5f, -LANEPITCH);
    LoadButton(7,  0.5f, -(3* LANEPITCH));
}

static void DrawButton(int i) {
    GLfloat x = Buttons[i].x;
    GLfloat y = Buttons[i].y;
    if (Buttons[i].state)
        glColor3f(BTCOLOR1);
    else
        glColor3f(BTCOLOR0);
    glBegin(GL_POLYGON);
    glVertex3f(-BTSIZE + x, -BTSIZE + y, 0.0);
    glVertex3f(-BTSIZE + x,  BTSIZE + y, 0.0);
    glVertex3f( BTSIZE + x,  BTSIZE + y, 0.0);
    glVertex3f( BTSIZE + x, -BTSIZE + y, 0.0);
    glEnd();
}

// Mouse clicks are referenced from the upper left in pixels.
// We are working in the relative frame, not pixels.
static void MyMouseFunc(int button, int state, int ix, int iy) {
    float x = -1.0f + 2.0f * (float) ix / glutGet(GLUT_WINDOW_WIDTH);
    float y =  1.0f - 2.0f * (float) iy / glutGet(GLUT_WINDOW_HEIGHT);
    for (int i = 0; i < BUTTONS; i++) {
        if ((button == GLUT_LEFT_BUTTON)
            && (x > (Buttons[i].x - BTSIZE))
            && (x < (Buttons[i].x + BTSIZE))
            && (y > (Buttons[i].y - BTSIZE))
            && (y < (Buttons[i].y + BTSIZE))) {
            Buttons[i].state = state;
            GUIbuttonHandler('A' + i + (0x20 * state));
        }
    }
}

//##############################################################################
// LCD display simulator
// For TFTX x TFTY graphic LCD module ILI9341 controller with IM=0000.
// The raw data is held in Windows 24-bit BMP format with reversed red/blue.
// glDrawPixels does not support GL_BGR (native BMP) format.

#define LCDimageSize (3 * TFTX * TFTY + 56)
static uint8_t LCDimage[LCDimageSize];

// Load a bitmap from a file. Must be 24-bit, TFTX x TFTY.
void GUILCDload(char * s) {
    FILE* fp;
#ifdef MORESAFE
    errno_t err = fopen_s(&fp, s, "rb");
#else
    fp = fopen(s, "rb");
#endif
    if (fp == NULL) {
        memset(LCDimage, 0, sizeof(uint8_t) * LCDimageSize);
    }
    else {
        fread(LCDimage, LCDimageSize, 1, fp);
        // Swap the R and B bytes assuming no padding (width is multiple of 4)
        uint8_t* p = &LCDimage[54];     // skip the header
        for (int i = 0; i < (3 * TFTX * TFTY); i += 3) {
            uint8_t temp = p[2];
            p[2] = p[0];
            p[0] = temp;
            p += 3;
        }
        fclose(fp);
    }
}

//##############################################################################
// The continuously called display function
static void displayMe(void)
{
    glClearColor(0.2f, 0.2f, 0.4f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);       // blue background
    for (int i = 0; i < BUTTONS; i++)   // buttons
        DrawButton(i);
    glColor3f(0.0f, 0.0f, 0.0f);        // dark LCD
    DisplayLEDs(LEDstatus);
    glRasterPos2f(AACENTER - AAWIDTH, -AAHEIGHT); // lower left corner of LCD
    glDrawPixels(TFTX, TFTY, GL_RGB, GL_UNSIGNED_BYTE, &LCDimage[54]);
    glFlush();    glFlush();
    Sleep(10); // <-- windows.h dependency
}

// Don't let the window be re-sized.
static void MyReshape(int width, int height) {
    glutReshapeWindow(WSIZE, WSIZE);
}

uint16_t teststream[] = {
    0x12A, 0, 10,  0, 19, // Column Address Set
    0x12B, 0, 20,  0, 39, // Row Address Set
    0x12C, // Memory Write (16-bit data follows)
    0xFFFF };

void GUIrun(void)
{
    char* myargv[1];
    int myargc = 1;
    myargv[0] = _strdup("glut");
    glutInit(&myargc, myargv);
    glutInitDisplayMode(GLUT_SINGLE);
    glutInitWindowSize(WSIZE, WSIZE);
    glutInitWindowPosition(100, 100);
    glutCreateWindow("Demo Front Panel");
    InitButtons();
    glutDisplayFunc(displayMe);
    glutIdleFunc(displayMe);
    glutMouseFunc(MyMouseFunc);
    glutReshapeFunc(MyReshape);
    GUILCDload("splash.bmp");
    TFTLCDsetup(LCDimage, 0, TFTX, TFTY);
    glutMainLoop();
}
