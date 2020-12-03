// #defines for options

`ifndef _options_vh_
`define _options_vh_

`default_nettype none

// coprocessor options
`define OPTIONS_IMULT  // 1
`define OPTIONS_IDIV   // 2
`define OPTIONS_ISHIFT // 4
		      
`define OPTIONS_COP  7 // sum of options, tells firmware what's here

`endif // _options_vh_
