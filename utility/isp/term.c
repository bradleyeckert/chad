#include <stdio.h>
#include <stdint.h>
#ifdef _WIN32
#include <Windows.h>
#else
#include <unistd.h>
#endif
#include "rs232.h"

/*
Terminal stdio <--> COMport utility, C99.

Command line parameters are:
<port#> [baud]
port# is the COM port number.
baud is an optional baud rate.

Serial communication uses https://gitlab.com/Teuniz/RS-232/ for cross-platform
abstraction. Ports are numbered for this. Numbering starts at 0, so COM4 is 3.
*/

#define DEFAULTBAUD 3000000L
#define DEFAULTPORT 9
#define MAXPORTS 31

void ms(int msec) {                     // time delay
#ifdef _WIN32
    Sleep(msec);
#else
    usleep(msec * 1000);
#endif
}

#ifdef __linux__
#include <unistd.h>
/**
 Linux (POSIX) implementation of _kbhit().
 Morgan McGuire, morgan@cs.brown.edu
 */
#include <stdio.h>
#include <sys/select.h>
#include <termios.h>
#include <stropts.h>

int KbHit(void) { // _kbhit in Linux
    static const int STDIN = 0;
    static bool initialized = false;

    if (!initialized) {
        // Use termios to turn off line buffering
        termios term;
        tcgetattr(STDIN, &term);
        term.c_lflag &= ~ICANON;
        tcsetattr(STDIN, TCSANOW, &term);
        setbuf(stdin, NULL);
        initialized = true;
    }

    int bytesWaiting;
    ioctl(STDIN, FIONREAD, &bytesWaiting);
    return bytesWaiting;
}
#else
#include <conio.h>
int KbHit(void) {
    return _kbhit();
}
#endif

#define maxlen 80
char txbuf[128];
unsigned char rxbuf[128];
int portnum = DEFAULTPORT;

void CloseCom(void) {
    ms(30);
    RS232_CloseComport(portnum);
}

int main(int argc, char *argv[])
{
    int baudrate = DEFAULTBAUD;
    if (argc < 2) {
		printf("Usage: 'term <port#> [baud]'\n");
		printf("Possible port#:");
		for (int i = 0; i < MAXPORTS; i++) {
            if (RS232_OpenComport(i, baudrate, "8N1", 0) == 0) {
                RS232_CloseComport(i);
                printf(" %d", i);
            }
		}
		return 1;
	}
    if (argc > 1) {
        char* p = argv[1];
        portnum = 0;
        char c;
        while ((c = *p++)) portnum = portnum * 10 + (c - '0');
    }
    if (argc > 2) {
        char* p = argv[2];
        baudrate = 0;
        char c;
        while ((c = *p++)) baudrate = baudrate * 10 + (c - '0');
    }

    if (RS232_OpenComport(portnum, baudrate, "8N1", 0)) {
        printf("Can't open com port %d\n", portnum);
        return 3;
    }
    printf("Opened port %d at %d BPS, ^C to quit.\n", portnum, baudrate);
    atexit(CloseCom);

    while (1) {
        if (KbHit()) {
            if (fgets(txbuf, maxlen, stdin)) {
                size_t len = strlen(txbuf);
                RS232_SendBuf(portnum, (unsigned char *)txbuf, (int)len);
            }
        }
        ms(30);
        int rxlen = RS232_PollComport(portnum, rxbuf, 127);
        rxbuf[rxlen] = 0;
        printf("%s", rxbuf);
    }
}

