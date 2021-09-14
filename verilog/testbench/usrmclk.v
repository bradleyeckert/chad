// Dummy for ECP5's SPI mux
// For testing, output the SPI clock through both an unused FPGA pin and USRMCLK.

`timescale 1 ns / 1 ps

module USRMCLK (
    input wire USRMCLKI,
    input wire USRMCLKTS
);

endmodule
