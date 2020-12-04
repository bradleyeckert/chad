// #defines for options

`ifndef _options_vh_
`define _options_vh_

`default_nettype none

// coprocessor options
`define OPTIONS_IMULT   // 1
`define OPTIONS_IDIV    // 2
`define OPTIONS_ISHIFT  // 4
`define OPTIONS_TINYGPU	// 8
		      
`define OPTIONS_COP  15 // sum of options, tells firmware what's here

`endif // _options_vh_

// When synthesizing for MAX 10, including all options adds 711 LEs for 24-bit
// cells.
