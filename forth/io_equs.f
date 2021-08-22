\ I/O equates

                        \ write                  read
 0 cells equ io'udata   \ UART out               UART in
 1 cells equ io'rxbusy  \ set the code address   UART receive status
 2 cells equ io'txbusy  \ write to code RAM      UART send status

 4 cells equ io'isp     \ ISP byte               ISP status
 5 cells equ io'gkey    \ set gecko key          flash read status
 6 cells equ io'fcfg    \ format:size
 6 cells equ io'cycles  \                        raw cycle count
10 cells equ io'fnext   \ trigger next
11 cells equ io'fread   \ start new flash read   flash read result
12 cells equ io'boot    \                        other status: okay, ISP
2 equ bootokay

$10 cells equ io'lcmd   \ write command byte
$11 cells equ io'ldata  \ write data byte
$12 cells equ io'lend   \ chip select high
$13 cells equ io'lgram  \ write data cell (6:6:6 GRAM)
\ $14 cells equ io'lraw   \ raw data to LCD pins
$15 cells equ io'lwtime \ write cycle timing
$16 cells equ io'lrtime \ read cycle timing
$17 cells equ io'lreset \ reset pin control

$18 cells equ io'leds   \ LEDs                   switches

