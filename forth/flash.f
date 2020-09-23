\ SPI flash memory interface                                    9/22/20 BNE

there

\ I/O registers       Read        Write
4 equ SPIdata       \ retrig      spitx
5 equ SPIformat     \ result      format
6 equ SPIrate       \             rate
8 equ CodeAddr      \             cmaddr
9 equ CodeData      \ cmdata      cmdata

0 equ S_R8                              \ 8-bit read mode
1 equ S_W8                              \ 8-bit write mode
2 equ S_R16                             \ 16-bit read mode
3 equ S_W16                             \ 16-bit write mode

variable qe-flag                        \ 2.4010 -- a-addr
variable stream-handle                  \ 2.4020 -- a-addr
3 cells buffer: stream-parms
: stream-mode stream-handle @ ;
: stream-ptr  stream-handle @ cell+ ;
: stream-cell stream-mode @ 2 and 2/ 1 + ; \ -- n \ bytes per stream element

: readSPI     SPIformat io@ ;           \ -- c \ result of transfer
: SPI[        1 SPIformat io! [ ;       \ c -- \ activate CS line and send byte
: sendSPI     SPIdata io! ;             \ c -- \ transmit an SPI byte
: ]SPI        0 SPIformat io! ;         \ end SPI cycle
: fl_wren     6 SPI[ ]SPI ;             \ write enable
: fl_wrdi     4 SPI[ ]SPI ;             \ write disable
: _fc>        0 sendSPI  readSPI ;      \ -- c \ read next flash byte
: fc>         SPIdata io@ ;             \ -- c \ read and trigger flash

\ Initialize the flash: Read the QE bit and provide a handle
: /flash            \ --
    53 SPI[  _fc>  2 and qe-flag ! ]SPI \ upper status byte
    stream-parms stream-handle !        \ set up a default handle
;

/flash

: waitflash         \ --                \ wait for write or erase to finish
    5 SPI[
    begin  _fc> 1 and  while  noop  repeat ]SPI
;

\ Cell size dependency: expects 18-bit cells.
\ Send a 24-bit address using 3 bytes. May use QSPI mode.

: sendaddr24        \ --                \ send address using 3 bytes
    stream-ptr 2@
    2* 2*  over swapw +  sendSPI
    dup swapb sendSPI    sendSPI
;
: erase4Ksec fl_wren 32 SPI[ sendaddr24 ]SPI ;
: 256page?   255 [ ;                    \ -- flag
: pagebreak  stream-ptr cell + @  and 0= ; \ mask -- flag
: 4Kpage?    4095 pagebreak ;           \ -- flag

: SDRsize           \ --                \ Set SDR transfer size
    stream-mode @ 2 and if
        3 SPIformat io!                 \ 16-bit single-rate SPI
    then
;

\ formats:
\ 0001 = 8-bit SPI
\ 0011 = 16-bit SPI
\ 1001 = 8-bit QSPI mode receive
\ 1011 = 16-bit QSPI mode receive
\ 1101 = 8-bit QSPI mode transmit
\ 1111 = 16-bit QSPI mode transmit

\ Start a SPI transfer based on stream-mode.
\ Note that the QE bit in the status register must be programmed to '1'
\ for quad rate commands to work. See the flash data sheet.
: resume-stream     \ 2.4030 --
    stream-mode @
    dup SPIrate io!                     \ set SCLK frequency and SPI device
    1 and if
        4Kpage? if erase4Ksec then
        fl_wren   2 SPI[  sendaddr24    \ start page write
        SDRsize
    else
        qe-flag @ if
            $EB SPI[                    \ EB single
            13 SPIformat io!            \ 8-bit QSPI transmit
            sendaddr24  0 sendSPI       \ 24-bit address and mode, QSPI
            11 SPIformat io!            \ 16-bit QSPI receive:
            0 sendSPI                   \ 4-beat dummy
            stream-mode @ 2 and 0= if
                9 SPIformat io!         \ 8-bit QSPI receive:
            then
        else
            11 SPI[  sendaddr24
            0 sendSPI  SDRsize
        then
        0 sendSPI                       \ first read
    then
;

: open-stream                           \ 2.4040 addr_lo addr_hi mode --
    stream-mode !  stream-ptr 2!
    resume-stream
;
: close-stream                          \ 2.4050 --
    ]SPI
    stream-mode @ 1 and if  waitflash  fl_wrdi  then
;

: ?end-page         \ --
    256page? if
        close-stream                    \ end the 256-byte page
        4Kpage? if  erase4Ksec  waitflash  then
        resume-stream                   \ start a new page
    then
;

\ Write element to the next free space in flash.
: >s       \ 2.4060 n --\ Write next element to flash
    sendSPI  stream-cell stream-ptr 2+!
    ?end-page
;
: s>       \ 2.4070 -- c\ read and trigger flash
    fc> stream-cell stream-ptr 2+!
;

:noname   count >s ;                    \ Write data bytes to stream
: dm>s    literal times  drop ;         \ 2.4080 addr u --
:noname   s> over c! char+ ;            \ Read data bytes from stream
: s>dm    literal times  drop ;         \ 2.4090 addr u --
: _CodeAddr  swap CodeAddr io! ;
:noname   CodeData io@ >s ;             \ Write code cells to stream
: cm>s    _CodeAddr  literal times ;    \ 2.4100 addr u --
:noname   s> CodeData io! ;             \ Read code cells from stream
: s>cm    _CodeAddr  literal times ;    \ 2.4110 addr u --

\ Load an app into code RAM based on boilerplate.
\ w16 contents
\  0: c0de
\  1: destination
\  2: length
\  3: checksum (to be added)

: loadcode  ( d-fa -- )
    S_R16 open-stream
;


there swap - . .( instructions used by flash access) cr
