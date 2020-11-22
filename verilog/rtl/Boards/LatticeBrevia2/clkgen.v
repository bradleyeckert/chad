/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.11.3.469 */
/* Module Version: 5.7 */
/* C:\lscc\diamond\3.11_x64\ispfpga\bin\nt64\scuba.exe -w -n clkgen -lang verilog -synth synplify -arch mg5a00 -type pll -fin 50 -phase_cntl STATIC -fclkop 100 -fclkop_tol 0.0 -fb_mode CLOCKTREE -noclkos -noclkok -norst -noclkok2  */
/* Fri Nov 20 23:54:03 2020 */


`timescale 1 ns / 1 ps
module clkgen (CLK, CLKOP, LOCK)/* synthesis NGD_DRC_MASK=1 */;
    input wire CLK;
    output wire CLKOP;
    output wire LOCK;

    wire CLKOP_t;
    wire scuba_vlo;

    VLO scuba_vlo_inst (.Z(scuba_vlo));

    // synopsys translate_off
    defparam PLLInst_0.CLKOK_BYPASS = "DISABLED" ;
    defparam PLLInst_0.CLKOS_BYPASS = "DISABLED" ;
    defparam PLLInst_0.CLKOP_BYPASS = "DISABLED" ;
    defparam PLLInst_0.PHASE_CNTL = "STATIC" ;
    defparam PLLInst_0.DUTY = 8 ;
    defparam PLLInst_0.PHASEADJ = "0.0" ;
    defparam PLLInst_0.CLKOK_DIV = 2 ;
    defparam PLLInst_0.CLKOP_DIV = 8 ;
    defparam PLLInst_0.CLKFB_DIV = 2 ;
    defparam PLLInst_0.CLKI_DIV = 1 ;
    // synopsys translate_on
    EPLLD1 PLLInst_0 (.CLKI(CLK), .CLKFB(CLKOP_t), .RST(scuba_vlo), .RSTK(scuba_vlo), 
        .DPAMODE(scuba_vlo), .DRPAI3(scuba_vlo), .DRPAI2(scuba_vlo), .DRPAI1(scuba_vlo), 
        .DRPAI0(scuba_vlo), .DFPAI3(scuba_vlo), .DFPAI2(scuba_vlo), .DFPAI1(scuba_vlo), 
        .DFPAI0(scuba_vlo), .PWD(scuba_vlo), .CLKOP(CLKOP_t), .CLKOS(), 
        .CLKOK(), .LOCK(LOCK), .CLKINTFB())
             /* synthesis CLKOK_BYPASS="DISABLED" */
             /* synthesis CLKOS_BYPASS="DISABLED" */
             /* synthesis FREQUENCY_PIN_CLKOP="100.000000" */
             /* synthesis CLKOP_BYPASS="DISABLED" */
             /* synthesis PHASE_CNTL="STATIC" */
             /* synthesis DUTY="8" */
             /* synthesis PHASEADJ="0.0" */
             /* synthesis FREQUENCY_PIN_CLKI="50.000000" */
             /* synthesis CLKOK_DIV="2" */
             /* synthesis CLKOP_DIV="8" */
             /* synthesis CLKFB_DIV="2" */
             /* synthesis CLKI_DIV="1" */
             /* synthesis FIN="50.000000" */;

    assign CLKOP = CLKOP_t;


    // exemplar begin
    // exemplar attribute PLLInst_0 CLKOK_BYPASS DISABLED
    // exemplar attribute PLLInst_0 CLKOS_BYPASS DISABLED
    // exemplar attribute PLLInst_0 FREQUENCY_PIN_CLKOP 100.000000
    // exemplar attribute PLLInst_0 CLKOP_BYPASS DISABLED
    // exemplar attribute PLLInst_0 PHASE_CNTL STATIC
    // exemplar attribute PLLInst_0 DUTY 8
    // exemplar attribute PLLInst_0 PHASEADJ 0.0
    // exemplar attribute PLLInst_0 FREQUENCY_PIN_CLKI 50.000000
    // exemplar attribute PLLInst_0 CLKOK_DIV 2
    // exemplar attribute PLLInst_0 CLKOP_DIV 8
    // exemplar attribute PLLInst_0 CLKFB_DIV 2
    // exemplar attribute PLLInst_0 CLKI_DIV 1
    // exemplar attribute PLLInst_0 FIN 50.000000
    // exemplar end

endmodule