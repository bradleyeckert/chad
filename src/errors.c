#include <stdio.h>
#include <string.h>

// ANS Forth Standard Throw Codes

// This list includes everything but the kitchen sink and adds a couple more.

static char ErrorString[260];   // String to include in error message

void ErrorMessage (int error, char *s) {
   char *msg;
   if (!error) return;
   switch (error) {
       case   -1: msg = "";                        /* ABORT */          break;
       case   -2: msg = s;                         /* ABORT" */         break;
       case   -3: msg = "Stack overflow";                               break;
       case   -4: msg = "Stack underflow";                              break;
       case   -5: msg = "Return stack overflow";                        break;
       case   -6: msg = "Return stack underflow";                       break;
       case   -7: msg = "Do-loops nested too deeply during execution";  break;
       case   -8: msg = "Dictionary overflow";                          break;
       case   -9: msg = "Invalid memory address";                       break;
       case  -10: msg = "Division by zero";                             break;
       case  -11: msg = "Result out of range";                          break;
       case  -12: msg = "Argument type mismatch";                       break;
       case  -13: memmove (ErrorString, s, 256);
                  memmove (&ErrorString[strlen(s) & 255], " ?", 3);
                  msg = *&ErrorString;                                  break;
       case  -14: msg = "Interpreting a compile-only word";             break;
       case  -15: msg = "Invalid FORGET";                               break;
       case  -16: msg = "Attempt to use zero-length string as a name";  break;
       case  -17: msg = "Pictured numeric output string overflow";      break;
       case  -18: msg = "Parsed string overflow";                       break;
       case  -19: msg = "Definition name too long";                     break;
       case  -20: msg = "Write to a read-only location";                break;
       case  -21: msg = "Unsupported operation";                        break;
       case  -22: msg = "Control structure mismatch";                   break;
       case  -23: msg = "Address alignment exception";                  break;
       case  -24: msg = "Invalid numeric argument";                     break;
       case  -25: msg = "Return stack imbalance";                       break;
       case  -26: msg = "Loop parameters unavailable";                  break;
       case  -27: msg = "Invalid recursion";                            break;
       case  -28: msg = "User interrupt";                               break;
       case  -29: msg = "Compiler nesting";                             break;
       case  -30: msg = "Obsolescent feature";                          break;
       case  -31: msg = ">BODY used on non-CREATEd definition";         break;
       case  -32: msg = "Invalid name argument (e.g., TO xxx)";         break;
       case  -33: msg = "Block read exception";                         break;
       case  -34: msg = "Block write exception";                        break;
       case  -35: msg = "Invalid block number";                         break;
       case  -36: msg = "Invalid file position";                        break;
       case  -37: msg = "File I/O exception";                           break;
       case  -38: msg = "File not found";                               break;
       case  -39: msg = "Unexpected end of file" ;                      break;
       case  -40: msg = "Invalid BASE for floating point conversion";   break;
       case  -41: msg = "Loss of precision";                            break;
       case  -42: msg = "Floating-point divide by zero";                break;
       case  -43: msg = "Floating-point result out of range";           break;
       case  -44: msg = "Floating-point stack overflow";                break;
       case  -45: msg = "Floating-point stack underflow";               break;
       case  -46: msg = "Floating-point invalid argument";              break;
       case  -47: msg = "Compilation wordlist deleted";                 break;
       case  -48: msg = "Invalid POSTPONE";                             break;
       case  -49: msg = "Search-order overflow";                        break;
       case  -50: msg = "Search-order underflow";                       break;
       case  -51: msg = "Compilation wordlist changed";                 break;
       case  -52: msg = "Control-flow stack overflow";                  break;
       case  -53: msg = "Exception stack overflow";                     break;
       case  -54: msg = "Floating-point underflow";                     break;
       case  -55: msg = "Floating-point unidentified fault";            break;
       case  -56: msg = "QUIT";                                         break;
       case  -57: msg = "Exception in sending or receiving a character";break;
       case  -58: msg = "[IF], [ELSE], or [THEN] exception";            break;
       case  -59: msg = "Missing literal before opcode";                break;
       case  -60: msg = "Attempt to write to non-blank flash memory";   break;
       case  -61: msg = "Macro expansion failure";                      break;
       case  -62: msg = "Input buffer overflow, line too long";         break;
       case  -63: msg = "Bad arguments to RESTORE-INPUT";               break;
       case  -64: msg = "Write to non-existent data memory";            break;
       case  -65: msg = "Read from non-existent data memory";           break;
       case  -66: msg = "PC is in non-existent code memory";            break;
       case  -67: msg = "Write to non-existent code memory";            break;
       case  -68: msg = "Test failure";                                 break;
       case  -69: msg = "Page fault writing flash memory";              break;
       case  -70: msg = "Bad I/O address";                              break;
       case  -71: msg = "Writing to flash without issuing WREN first";  break;
       case  -72: msg = "Invalid ALU opcode";                           break;
       case  -73: msg = "Bitfield is 0 or too wide for a cell";         break;
       case  -74: msg = "Resolving a word that's not a DEFER";          break;
       case  -75: msg = "Too many WORDLISTs used";                      break;
       case  -76: msg = "Internal API calls are blocked";               break;
       case  -77: msg = "Invalid CREATE DOES> usage";                   break;
       case  -80: msg = "Dictionary full";                              break;
       case  -81: msg = "Writing to invalid flash sector";              break;
       case  -82: msg = "Flash string space overflow";                  break;
       case  -98: msg = "Compiling an execute-only word";               break;
       case  -99: msg = "Nesting overflow during include";              break;
       case -100: msg = "ALLOCATE failed";                              break;
       case -101: msg = "RESIZE failed";                                break;
       case -102: msg = "FREE failed";                                  break;
       case -191: msg = "Can't delete file";  /* DELETE-FILE */         break;
       case -192: msg = "Can't rename file";  /* RENAME-FILE */         break;
       case -193: msg = "Can't resize file";  /* RESIZE-FILE */         break;
       case -194: msg = "Can't flush file";   /* FLUSH-FILE  */         break;
       case -195: msg = "Can't read file";    /* READ-FILE,READ-LINE */ break;
       case -196: msg = "Can't write file";   /* WRITE-FILE */          break;
       case -197: msg = "Can't close file";   /* CLOSE-FILE */          break;
       case -198: msg = "Can't create file";  /* CREATE-FILE */         break;
       case -199: msg = "Can't open file";  /* OPEN-FILE,INCLUDE-FILE*/ break;
       default: printf("Error: %d\n", error);  return;
    }
    printf("%s\n", msg);
}
