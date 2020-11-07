///////////////////////////////////////////////////////////////////////////////
//  File name : s25fl064l.v
///////////////////////////////////////////////////////////////////////////////
//  Copyright (C) 2018-2019 Free Model Foundry; http://www.FreeModelFoundry.com
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License version 2 as
//  published by the Free Software Foundation.
//
//  MODIFICATION HISTORY :
//
//  version: |   author:     |  mod date:  |  changes made:
//    V1.0      B.Barac        18 Feb 14     Initial version
//    V1.1      M.Dinic        18 Jun 08     Bug 18 fixed -
//                                           added !CSNeg condition for
//                                           two model instances
//    V1.2      B.Barac        19 Feb 06     SFDP update
//              B.Eckert       12 Oct 20     tdevice_PU = 3 ns
//
///////////////////////////////////////////////////////////////////////////////
//  PART DESCRIPTION:
//
//  Library:    FLASH
//  Technology: FLASH MEMORY
//  Part:       S25FL064L
//
//  Description: 64 Megabit Serial Flash Memory
//
//////////////////////////////////////////////////////////////////////////////
//  Comments :
//      For correct simulation, simulator resolution should be set to 1 ps
//
//////////////////////////////////////////////////////////////////////////////
//  Known Bugs:
//
//////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////
// MODULE DECLARATION                                                       //
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ps/1 ps

module s25fl064l
    (
        // Data Inputs/Outputs
        SI     ,
        SO     ,
        SCK    ,
        CSNeg  ,
        RESETNeg,
        WPNeg  ,
        IO3_RESETNeg
    );

///////////////////////////////////////////////////////////////////////////////
// Port / Part Pin Declarations
///////////////////////////////////////////////////////////////////////////////

    inout   SI            ;
    inout   SO            ;

    input   SCK           ;
    input   CSNeg         ;
    input   RESETNeg      ;
    inout   WPNeg         ;
    inout   IO3_RESETNeg  ;

    // interconnect path delay signals
    wire   SCK_ipd        ;
    wire   SI_ipd         ;
    wire   SO_ipd         ;
    wire   CSNeg_ipd      ;
    wire   RESETNeg_ipd   ;
    wire   WPNeg_ipd      ;
    wire   IO3_RESETNeg_ipd   ;

    wire SI_in            ;
    assign SI_in = SI_ipd ;

    wire SI_out           ;
    assign SI_out = SI    ;

    wire SO_in            ;
    assign SO_in = SO_ipd ;

    wire SO_out           ;
    assign SO_out = SO    ;

    wire   WPNeg_in                 ;
    //Internal pull-up
    assign WPNeg_in = (WPNeg_ipd === 1'bx) ? 1'b1 : WPNeg_ipd;

    wire   WPNeg_out                ;
    assign WPNeg_out = WPNeg        ;

    wire   RESETNeg_in              ;
    //Internal pull-up
    assign RESETNeg_in = (RESETNeg_ipd===1'bx) ? 1'b1:RESETNeg_ipd;

    wire   RESETNeg_out             ;
    assign RESETNeg_out = RESETNeg  ;

    wire   IO3_RESETNeg_in              ;
    //Internal pull-up
    assign IO3_RESETNeg_in=(IO3_RESETNeg_ipd===1'bx) ? 1'b1:IO3_RESETNeg_ipd;

    wire   IO3_RESETNeg_out             ;
    assign IO3_RESETNeg_out = IO3_RESETNeg  ;

    // internal delays
    reg ERSSUSP_in = 1'b0 ;
    reg ERSSUSP_out = 1'b0 ;
    reg PRGSUSP_in = 1'b0  ;
    reg PRGSUSP_out = 1'b0 ;
    reg PASSULCK_in = 1'b0 ;
    reg PASSULCK_out = 1'b0;
    reg SFT_RST_in = 1'b0;
    reg SFT_RST_out = 1'b1;
    reg HW_RST_in   = 1'b0;
    reg HW_RST_out  = 1'b1;
    reg DPD_in = 1'b0;
    reg DPD_out = 1'b0;
    reg RES_in = 1'b0;
    reg RES_out = 1'b0;
    reg QEN_in = 1'b0;
    reg QEN_out = 1'b0;
    reg QEXN_in = 1'b0;
    reg QEXN_out = 1'b0;

    reg rising_edge_CSNeg_ipd  = 1'b0;
    reg rising_edge_CSNeg_d    = 1'b0;
    reg falling_edge_CSNeg_ipd = 1'b0;
    reg rising_edge_SCK_ipd    = 1'b0;
    reg rising_edge_SCK_D      = 1'b0;
    reg falling_edge_SCK_D     = 1'b0;
    reg falling_edge_SCK_ipd   = 1'b0;
    reg falling_edge_RST       = 1'b0;
    reg rising_edge_PSTART     = 1'b0;
    reg rising_edge_PDONE      = 1'b0;
    reg rising_edge_ESTART     = 1'b0;
    reg rising_edge_EDONE      = 1'b0;
    reg rising_edge_WSTART_NV  = 1'b0;
    reg rising_edge_WSTART_V   = 1'b0;
    reg rising_edge_WDONE      = 1'b0;

    reg rising_edge_RES_out    = 1'b0;
    reg falling_edge_RES_in    = 1'b0;
    reg rising_edge_PRGSUSP_out;
    reg rising_edge_ERSSUSP_out;
    reg rising_edge_QEN_out;
    reg rising_edge_QEXN_out;
    reg rising_edge_PASSULCK_out;
    reg rising_edge_SFT_RST_out;
    reg rising_edge_HW_RST_out;
    reg rising_edge_reseted  = 1'b0;
    reg rising_edge_PoweredUp = 1'b0;

    reg SOut_zd        = 1'bZ;
    reg SIOut_zd       = 1'bZ;
    reg WPNegOut_zd    = 1'bZ;
    reg IO3_RESETNegOut_zd = 1'bZ;

    parameter UserPreload       = 1;
    parameter mem_file_name     = "none";//"s25fl064l.mem";
    parameter secr_file_name    = "s25fl064lSECR.mem";//"none";

    parameter TimingModel       = "DefaultTimingModel";

    parameter  PartID           = "s25fl064l";
    parameter  MaxData          = 255;
    parameter  MemSize          = 24'h7FFFFF;
    parameter  PageSize         = 8'hFF;
    parameter  SecRegSize       = 8'hFF;
    parameter  SecSize          = 12'hFFF;
    parameter  HalfBlockSize    = 15'h7FFF;
    parameter  BlockSize        = 16'hFFFF;
    parameter  SecNum           = 12'h7FF;
    parameter  BlockNum         = 7'h7F;
    parameter  HalfBlockNum     = 8'hFF;
    parameter  SecRegNum        = 3;

    parameter  PageNum          = 19'h7FFF;
    parameter  AddrRANGE        = 27'h7FFFFF;

    parameter  SECRLoAddr       = 12'h000;
    parameter  SECRHiAddr       = 12'h3FF;

    parameter  SFDPLoAddr       = 16'h0000;
    parameter  SFDPHiAddr       = 16'h5FF;
    parameter  SFDPLength       = 16'h5FF;

    parameter  IDCFILength      = 16'h115;

    parameter  ManufIDDeviceID  = 24'h176001;
    parameter  DeviceID         = 16'h6017;
    parameter  UID              = 64'b0;

    reg SECURE_OPN = 1'b0;
    reg QIO_ONLY_OPN = 1'b0;
    reg QPI_ONLY_OPN = 1'b0;

    reg [24*8-1:0] tmp_timing;//stores copy of TimingModel
    reg [7:0] tmp_char1; //Define General Market or Secure Device
    integer found = 1'b0;

    // If speedsimulation is needed uncomment following line

//        `define SPEEDSIM;

    // powerup
    reg PoweredUp;

    // FSM states
    parameter STANDBY             = 7'd0;
    parameter RESET_STATE         = 7'd1;
    parameter RD_ADDR             = 7'd2;
    parameter FAST_RD_ADDR        = 7'd3;
    parameter DUALO_RD_ADDR       = 7'd4;
    parameter DUALIO_RD_ADDR      = 7'd5;
    parameter QUADO_RD_ADDR       = 7'd6;
    parameter QUADIO_RD_ADDR      = 7'd7;
    parameter DDRQUADIO_RD_ADDR   = 7'd8;
    parameter DLPRD_DUMMY         = 7'd9;
    parameter IRPRD_DUMMY         = 7'd10;
    parameter IBLRD_ADDR          = 7'd11;
    parameter SFT_RST_EN          = 7'd12;
    parameter SECRR_ADDR          = 7'd13;
    parameter PASSRD_DUMMY        = 7'd14;
    parameter PRRD_DUMMY          = 7'd15;
    parameter RDID_DATA_OUTPUT    = 7'd16;
    parameter RDQID_DATA_OUTPUT   = 7'd17;
    parameter RUID_DUMMY          = 7'd18;
    parameter RSFDP_ADDR          = 7'd19;
    parameter SET_BURST_DATA_INPUT = 7'd20;
    parameter RDSR1_DATA_OUTPUT    = 7'd21;
    parameter RDSR2_DATA_OUTPUT    = 7'd22;
    parameter RDCR1_DATA_OUTPUT    = 7'd23;
    parameter RDCR2_DATA_OUTPUT    = 7'd24;
    parameter RDCR3_DATA_OUTPUT    = 7'd25;
    parameter RDAR_ADDR            = 7'd26;
    parameter DPD                  = 7'd27;
    parameter RDP_DUMMY            = 7'd28;
    parameter PGM_ADDR             = 7'd29;
    parameter SECT_ERS_ADDR        = 7'd30;
    parameter HALF_BLOCK_ERS_ADDR  = 7'd31;
    parameter BLOCK_ERS_ADDR       = 7'd32;
    parameter CHIP_ERS             = 7'd33;
    parameter IBL_LOCK             = 7'd34;
    parameter IRP_PGM_DATA_INPUT   = 7'd35;
    parameter WRR_DATA_INPUT       = 7'd36;
    parameter WRAR_ADDR            = 7'd37;
    parameter PASSP_DATA_INPUT     = 7'd38;
    parameter SEC_REG_PGM_ADDR     = 7'd39;
    parameter SEC_REG_ERS_ADDR     = 7'd40;
    parameter PASSU_DATA_INPUT     = 7'd41;
    parameter IBL_UNLOCK           = 7'd42;
    parameter SET_PNTR_PROT_ADDR   = 7'd43;
    parameter PGM_NV_DLR_DATA      = 7'd44;
    parameter DLRV_WRITE_DATA      = 7'd45;
    parameter RD_DATA              = 7'd46;
    parameter FAST_RD_DUMMY        = 7'd47;
    parameter FAST_RD_DATA         = 7'd48;
    parameter DUALO_RD_DUMMY       = 7'd49;
    parameter DUALO_RD_DATA        = 7'd50;
    parameter QUADO_RD_DUMMY       = 7'd51;
    parameter QUADO_RD_DATA        = 7'd52;
    parameter DUALIO_RD_DUMMY      = 7'd53;
    parameter DUALIO_RD_MODE       = 7'd54;
    parameter DUALIO_RD_DATA       = 7'd55;
    parameter QUADIO_RD_DUMMY      = 7'd56;
    parameter QUADIO_RD_MODE       = 7'd57;
    parameter QUADIO_RD_DATA       = 7'd58;
    parameter DDRQUADIO_RD_DUMMY   = 7'd59;
    parameter DDRQUADIO_RD_MODE    = 7'd60;
    parameter DDRQUADIO_RD_DATA    = 7'd61;
    parameter RDAR_DUMMY           = 7'd62;
    parameter RDAR_DATA_OUTPUT     = 7'd63;
    parameter PGM_DATAIN           = 7'd64;
    parameter PGM                  = 7'd65;
    parameter PGMSUS               = 7'd66;
    parameter SECT_ERS             = 7'd67;
    parameter HALF_BLOCK_ERS       = 7'd68;
    parameter BLOCK_ERS            = 7'd69;
    parameter ERSSUS               = 7'd70;
    parameter SEC_REG_PGM_DATAIN   = 7'd71;
    parameter PGM_SEC_REG          = 7'd72;
    parameter SECT_ERS_SEC_REG     = 7'd73;
    parameter DLPRD_DATA_OUTPUT    = 7'd74;
    parameter IRPRD_DATA_OUTPUT    = 7'd75;
    parameter IBLRD_DATA_OUTPUT    = 7'd76;
    parameter SECRR_DUMMY          = 7'd77;
    parameter SECRR_DATA_OUTPUT    = 7'd78;
    parameter PASSRD_DATA_OUTPUT   = 7'd79;
    parameter PRRD_DATA_OUTPUT     = 7'd80;
    parameter RUID_DATA_OUTPUT     = 7'd81;
    parameter RSFDP_DUMMY          = 7'd82;
    parameter RSFDP_DATA_OUTPUT    = 7'd83;
    parameter RDP_DATA_OUTPUT      = 7'd84;
    parameter IRP_PGM              = 7'd85;
    parameter WRR_NV               = 7'd86;
    parameter WRR_V                = 7'd87;
    parameter WRAR_DATA_INPUT      = 7'd88;
    parameter WRAR_NV              = 7'd89;
    parameter WRAR_V               = 7'd90;
    parameter PGM_NV_DLR           = 7'd91;
    parameter SET_PNTR_PROT        = 7'd92;
    parameter PASS_PGM             = 7'd93;
    parameter PASS_ULCK            = 7'd94;

    reg [6:0] current_state = STANDBY;
    reg [6:0] next_state = STANDBY;

    // Instruction type
    parameter NONE            = 7'd0;
    parameter READ            = 7'd1;
    parameter READ4           = 7'd2;
    parameter FAST_READ       = 7'd3;
    parameter FAST_READ4      = 7'd4;
    parameter DOR             = 7'd5;
    parameter DOR4            = 7'd6;
    parameter DIOR            = 7'd7;
    parameter DIOR4           = 7'd8;
    parameter QOR             = 7'd9;
    parameter QOR4            = 7'd10;
    parameter QIOR            = 7'd11;
    parameter QIOR4           = 7'd12;
    parameter DDRQIOR         = 7'd13;
    parameter DDRQIOR4        = 7'd14;
    parameter DLPRD           = 7'd15;
    parameter IRPRD           = 7'd16;
    parameter IBLRD           = 7'd17;
    parameter IBLRD4          = 7'd18;
    parameter RSTEN           = 7'd19;
    parameter SECRR           = 7'd20;
    parameter PASSRD          = 7'd21;
    parameter PRRD            = 7'd22;
    parameter RDID            = 7'd23;
    parameter RDQID           = 7'd24;
    parameter RUID            = 7'd25;
    parameter RSFDP           = 7'd26;
    parameter SET_BURST       = 7'd27;
    parameter BEN4            = 7'd28;
    parameter BEX4            = 7'd29;
    parameter QPIEN           = 7'd30;
    parameter QPIEX           = 7'd31;
    parameter RDSR1           = 7'd32;
    parameter RDSR2           = 7'd33;
    parameter RDCR1           = 7'd34;
    parameter RDCR2           = 7'd35;
    parameter RDCR3           = 7'd36;
    parameter RDAR            = 7'd37;
    parameter DEEP_PD         = 7'd38;
    parameter RES             = 7'd39;
    parameter WREN            = 7'd40;
    parameter WRENV           = 7'd41;
    parameter WRDI            = 7'd42;
    parameter CLSR            = 7'd43;
    parameter PP              = 7'd44;
    parameter PP4             = 7'd45;
    parameter QPP             = 7'd46;
    parameter QPP4            = 7'd47;
    parameter SE              = 7'd48;
    parameter SE4             = 7'd49;
    parameter HBE             = 7'd50;
    parameter HBE4            = 7'd51;
    parameter BE              = 7'd52;
    parameter BE4             = 7'd53;
    parameter CE              = 7'd54;
    parameter IBL             = 7'd55;
    parameter IBL4            = 7'd56;
    parameter IRPP            = 7'd57;
    parameter WRR             = 7'd58;
    parameter WRAR            = 7'd59;
    parameter PASSP           = 7'd60;
    parameter SECRP           = 7'd61;
    parameter SECRE           = 7'd62;
    parameter PASSU           = 7'd63;
    parameter PRL             = 7'd64;
    parameter IBUL            = 7'd65;
    parameter IBUL4           = 7'd66;
    parameter GBL             = 7'd67;
    parameter GBUL            = 7'd68;
    parameter SPRP            = 7'd69;
    parameter SPRP4           = 7'd70;
    parameter PDLRNV          = 7'd71;
    parameter WDLRV           = 7'd72;
    parameter EPS             = 7'd73;
    parameter EPR             = 7'd74;
    parameter RSTCMD          = 7'd75;

    // Command Register
    reg [7:0] Instruct;
    reg [7:0] Instruct_tmp;
    reg [7:0] mode_byte;

    reg reseted;
    reg RST = 1;

    reg WREN_V;
    integer opcode_cnt = 0;
    reg [7:0] opcode;
    reg [31:0] Address;
    reg [31:0] Address_wrar;
    integer sec;
    integer blk;
    integer pgm_page;
    integer sec_region;
    integer addr_cnt = 0;
    integer Latency_code;
    integer WrapLength;
    integer dummy_cnt = 0;
    integer mode_cnt = 0;
    integer read_cnt  = 0;
    integer byte_cnt  = 0;
    reg[7:0] data_out;

    integer data_cnt   = 0;
    integer bit_cnt    = 0;
    reg[7:0] Data_in[0:PageSize];
    reg [7:0] Byte_slv = {8{1'b1}};

    integer WByte[0:255];
    integer WData [0:255];

    integer Addr;
    integer Addr_tmp;

    reg [SecNum:0] Sec_Prot = {(SecNum+1){1'b0}};
    reg [HalfBlockNum:0] HalfBlock_Prot = {(HalfBlockNum+1){1'b0}};
    reg [BlockNum:0] Block_Prot = {(BlockNum+1){1'b0}};

    reg [SecNum:0] Legacy_Sec_Prot  = {(SecNum+1){1'b0}};
    reg [SecNum:0] IBL_Sec_Prot  = {(SecNum+1){1'b0}};
    reg [SecNum:0] PRP_Sec_Prot  = {(SecNum+1){1'b0}};

    reg DPD_ACT;
    reg DLP_ACT;
    reg PGM_ACT = 0;
    reg PGM_SEC_REG_ACT = 0;
    reg SECT_ERS_ACT = 0;
    reg HALF_BLOCK_ERS_ACT = 0;
    reg BLOCK_ERS_ACT = 0;
    reg CHIP_ERS_ACT = 0;
    reg SECT_ERS_SEC_REG_ACT = 0;
    reg WRR_NV_ACT = 0;
    reg WRAR_NV_ACT = 0;
    reg IRP_ACT = 0;
    reg DLRNV_ACT = 0;
    reg SET_PNTR_PROT_ACT = 0;
    reg PASS_PGM_ACT = 0;

    reg DLRNV_programmed = 0;

    time CLK_PER;
    time LAST_CLK;

    // FSM control signals
    reg PDONE     ;
    reg PSTART    ;
    reg PGSUSP    ;
    reg PGRES     ;

    reg RES_TO_SUSP_TIME;

    reg WDONE     ;
    reg WSTART_NV ;
    reg WSTART_V  ;

    reg EDONE     ;
    reg ESTART    ;
    reg ESUSP     ;
    reg ERES      ;

    reg WL6       ;
    reg WL5       ;
    reg WL4       ;

    // SFDP array
    integer SFDP_array[SFDPLoAddr:SFDPHiAddr];
    // Security Region array
    integer SECRMem[SECRLoAddr:SECRHiAddr];
    // Flash Memory Array
    integer Mem[0:AddrRANGE];

    //-----------------------------------------
    //  Registers
    //-----------------------------------------

    reg [7:0] SR1NV    = 8'h00;
    reg [7:0] SR1V     = 8'h00;
    reg [7:0] SR1_in   = 8'h00;

    wire SEC;
    assign SEC = SR1V[6];
    wire TBPROT;
    assign TBPROT = SR1V[5];
    wire BP2;
    assign BP2 = SR1V[4];
    wire BP1;
    assign BP1 = SR1V[3];
    wire BP0;
    assign BP0 = SR1V[2];
    wire WEL;
    assign WEL = SR1V[1];
    wire WIP;
    assign WIP = SR1V[0];

    reg [7:0] SR2V     = 8'h00;

    reg [7:0] CR1NV    = 8'h00;
    reg [7:0] CR1V     = 8'h00;
    reg [7:0] CR1_in   = 8'h00;

    wire CMP;
    assign CMP = CR1V[6];
    wire LB3;
    assign LB3 = CR1V[5];
    wire LB2;
    assign LB2 = CR1V[4];
    wire LB1;
    assign LB1 = CR1V[3];
    wire LB0;
    assign LB0 = CR1V[2];
    wire QUAD;
    assign QUAD = CR1V[1];
    wire srp1;
    assign srp1 = CR1V[0];

    reg [7:0] CR2NV    = 8'h60;
    reg [7:0] CR2V     = 8'h60;
    reg [7:0] CR2_in   = 8'h00;

    wire QPI;
    assign QPI = CR2V[3];
    wire IO3R;
    assign IO3R = CR2V[7];
    wire WPS;
    assign WPS = CR2V[2];

    reg [7:0] CR3NV    = 8'h78;
    reg [7:0] CR3V     = 8'h78;
    reg [7:0] CR3_in   = 8'h00;

    reg [31:0] WRR_in  = 32'd0;
    reg [7:0] WRAR_in  = 8'd0;

    reg[15:0] IRP    = 16'hFFFD;
    reg[15:0] IRP_in = 16'hFFFD;

    reg[63:0] Password_reg     = 64'hFFFFFFFFFFFFFFFF;
    reg[63:0] Password_reg_in  = 64'hFFFFFFFFFFFFFFFF;
    reg[63:0] Password_regU_in = 64'h0;

    // Protection Register
    reg[7:0] PR              = 8'h41;
    reg[7:0] PR_in           = 8'h41;

    wire   NVLOCK;
    assign NVLOCK     = PR[0];
    wire   SECRRP;
    assign SECRRP     = PR[6];

    // Pointer Region Protect Register
    reg[31:0] PRPR    = 32'hFFFFFFFF;
    reg[31:0] PRPR_in  = 32'hFFFFFFFF;

    // Individual Block Lock Access Register
    reg[7:0] IBLAR             = 8'h00;

    // DLP registers
    reg[7:0] DLRV          = 8'h00;
    reg[7:0] DLRNV         = 8'h00;
    reg[7:0] DLRV_in       = 8'h00;
    reg[7:0] DLRNV_in      = 8'h00;

    reg [7:0] RDAR_reg    = 8'h00;

    integer SectorErase = 0;
    integer HalfBlockErase = 0;
    integer BlockErase = 0;

    // timing check violation
    reg Viol = 1'b0;

    integer AddrLOW;
    integer AddrHIGH;

    reg[7:0]  old_bit, new_bit;
    integer old_int, new_int;
    integer wr_cnt;
    integer cnt;

    reg normal_rd = 0;
    reg fast_rd = 1;
    reg ddr_rd = 0;
    reg reg_rd = 0;

    reg frst_addr_nibb;

    reg  glitch = 1'b0;
    reg  DataDriveOut_SO = 1'bZ ;
    reg  DataDriveOut_SI = 1'bZ ;
    reg  DataDriveOut_IO3_RESET = 1'bZ ;
    reg  DataDriveOut_WP = 1'bZ ;

///////////////////////////////////////////////////////////////////////////////
//Interconnect Path Delay Section
///////////////////////////////////////////////////////////////////////////////
 buf   (SCK_ipd, SCK);
 buf   (SI_ipd, SI);
 buf   (SO_ipd, SO);
 buf   (CSNeg_ipd, CSNeg);
 buf   (WPNeg_ipd, WPNeg);
 buf   (IO3_RESETNeg_ipd, IO3_RESETNeg);

///////////////////////////////////////////////////////////////////////////////
// Propagation  delay Section
///////////////////////////////////////////////////////////////////////////////
    nmos   (SI,       SIOut_zd       , 1);
    nmos   (SO,       SOut_zd        , 1);
    nmos   (IO3_RESETNeg, IO3_RESETNegOut_zd , 1);
    nmos   (WPNeg,    WPNegOut_zd    , 1);

    // Needed for TimingChecks
    // VHDL CheckEnable Equivalent

    wire io3_rst;
    assign io3_rst = IO3R && ((~QUAD & ~QPI) | CSNeg_ipd);

    wire ddr;
    assign ddr = (Instruct==DDRQIOR) | (Instruct==DDRQIOR4);

    wire RST_QUAD;
    assign RST_QUAD = IO3R & (QUAD | QPI);

    wire datain;
    assign datain = SOut_zd === 1'bz;

    wire datain_ddr;
    assign datain_ddr = datain & ddr;

    wire srp0;
    assign srp0 = SR1V[7];

    wire WrProt;
    assign WrProt = SR1V[7] & ~CR1V[1] & ~CR2V[3];

    wire rd_normal;
    wire rd_fast;
    wire rd_ddr;
    wire rd_reg;

    assign rd_normal = normal_rd;
    assign rd_fast = fast_rd;
    assign rd_ddr = ddr_rd;
    assign rd_reg = reg_rd;

specify
        // tipd delays: interconnect path delays , mapped to input port delays.
        // In Verilog is not necessary to declare any tipd_ delay variables,
        // they can be taken from SDF file
        // With all the other delays real delays would be taken from SDF file

    // tpd delays
    specparam        tpd_SCK_SO      = 1; // tV
    specparam        tpd_CSNeg_SO_RST_QUAD_EQ_1 = 1; // tDIS
    specparam        tpd_CSNeg_SO_RST_QUAD_EQ_0 = 1; // tDIS

    //tsetup values: setup times
    specparam        tsetup_CSNeg_SCK        = 1;   // tCSS edge /
    specparam        tsetup_SI_SCK           = 1;   // tSU  edge /
    specparam        tsetup_WPNeg_CSNeg      = 1;   // tWPS edge \

    //thold values: hold times
    specparam        thold_CSNeg_SCK         = 1;   // tCSH edge /
    specparam        thold_SI_SCK            = 1;   // tHD  edge /
    specparam        thold_WPNeg_CSNeg       = 1;   // tWPH edge /
    specparam        thold_CSNeg_RESETNeg    = 1;   // tRH  edge /
    specparam        thold_CSNeg_IO3_RESETNeg= 1;   // tRH  edge /

    // tpw values: pulse width
    specparam        tpw_SCK_normal  = 1;
    specparam        tpw_SCK_fast    = 1;
    specparam        tpw_SCK_ddr     = 1;
    specparam        tpw_SCK_reg     = 1;
    specparam        tpw_CSNeg       = 1;   // tCS
    specparam        tpw_RESETNeg    = 1;   // tRP
    specparam        tpw_IO3_RESETNeg= 1;   // tRP

    // tperiod min (calculated as 1/max freq)
    specparam        tperiod_SCK_normal   = 1;   // 50 MHz
    specparam        tperiod_SCK_fast     = 1;   //108 MHz
    specparam        tperiod_SCK_ddr      = 1;   // 54 MHz
    specparam        tperiod_SCK_reg      = 1;   // 108 MHz

    `ifdef SPEEDSIM
        // WRR Cycle Time
        specparam        tdevice_WRR               = 1200e9; //tW = 1200us
        // Page Program Operation
        specparam        tdevice_PP                = 1350e6; //tPP = 1350us
        // Byte Programming
        specparam        tdevice_BP1               = 90e6; //tBP1 = 90us
        // Byte Programming
        specparam        tdevice_BP2               = 30e6; //tBP2 = 30us
        // 4 KB Sector Erase Operation
        specparam        tdevice_SE                = 320e6; //tSE = 320us
        // 32 KB Half Block Erase Operation
        specparam        tdevice_HBE               = 600e6; //tHBE = 600us
       // 64 KB Block Erase Operation
        specparam        tdevice_BE                = 1150e6; //tBE = 1150us
        // Chip Erase Operation
        specparam        tdevice_CE                = 150e9; //tCE = 150ms
        // Suspend Latency
        specparam        tdevice_SUSP              = 40e6; //tSL = 40us
        // Resume to next Suspend Time
        specparam        tdevice_RNS               = 100e6;//tRS = 100 us
        // RESET# Low to CS# Low
        specparam        tdevice_RPH               = 100e6; //tRPH = 100 us
        // VCC (min) to CS# Low
        specparam        tdevice_PU                = 300e1;//tPU = 300us
        // Password Unlock to Password Unlock Time
        specparam        tdevice_PASSACC           = 100e6;// 100us
        // DPD enter
        specparam        tdevice_DPD               = 3e6;// 3us
        // Release DPD
        specparam        tdevice_RES               = 5e6;// 5us
        // QIO, QPI mode enter to the next command
        specparam        tdevice_QEN               = 1.5e6;// 1.5us
        // QIO, QPI mode exit to the next command
        specparam        tdevice_QEXN              = 1e6;// 1us
        // Volatile registers write time
        specparam        tdevice_CS                = 50e3; //tCS = 50ns
    `else
        // WRR Cycle Time
        specparam        tdevice_WRR               = 1200e9; //tW = 1200ms
        // Page Program Operation
        specparam        tdevice_PP                = 1350e6; //tPP = 1350us
        // Byte Programming
        specparam        tdevice_BP1               = 90e6; //tBP1 = 90us
        // Byte Programming
        specparam        tdevice_BP2               = 30e6; //tBP2 = 30us
        // 4 KB Sector Erase Operation
        specparam        tdevice_SE                = 320e9; //tSE = 320ms
        // 32 KB Half Block Erase Operation
        specparam        tdevice_HBE               = 600e9; //tHBE = 600ms
       // 64 KB Block Erase Operation
        specparam        tdevice_BE                = 1150e9; //tBE = 1150ms
        // Chip Erase Operation
        specparam        tdevice_CE                = 150e12; //tCE = 150s
        // Suspend Latency
        specparam        tdevice_SUSP              = 40e6; //tSL = 40us
        // Resume to next Suspend Time
        specparam        tdevice_RNS               = 100e6;//tRS = 100 us
        // RESET# Low to CS# Low
        specparam        tdevice_RPH               = 100e6; //tRPH = 100 us
        // VCC (min) to CS# Low
        specparam        tdevice_PU                = 300e1;//tPU = 300us
        // Password Unlock to Password Unlock Time
        specparam        tdevice_PASSACC           = 100e6;// 100us
        // DPD enter
        specparam        tdevice_DPD               = 3e6;// 3us
        // Release DPD
        specparam        tdevice_RES               = 5e6;// 5us
        // QIO, QPI mode enter to the next command
        specparam        tdevice_QEN               = 1.5e6;// 1.5us
        // QIO, QPI mode exit to the next command
        specparam        tdevice_QEXN              = 1e6;// 1us
        // Volatile registers write time
        specparam        tdevice_CS                = 50e3; //tCS = 50ns

    `endif // SPEEDSIM

///////////////////////////////////////////////////////////////////////////////
// Input Port  Delays  don't require Verilog description
///////////////////////////////////////////////////////////////////////////////
// Path delays                                                               //
///////////////////////////////////////////////////////////////////////////////
   if (~glitch)     (SCK => SO) = tpd_SCK_SO;
   if (~glitch)     (SCK => SI) = tpd_SCK_SO;
   if (~glitch)     (SCK => IO3_RESETNeg) = tpd_SCK_SO;
   if (~glitch)     (SCK => WPNeg)        = tpd_SCK_SO;

   if (RST_QUAD)    (CSNeg => SO)  = tpd_CSNeg_SO_RST_QUAD_EQ_1;
   if (RST_QUAD)    (CSNeg => SI)  = tpd_CSNeg_SO_RST_QUAD_EQ_1;
   if (RST_QUAD)    (CSNeg => IO3_RESETNeg) = tpd_CSNeg_SO_RST_QUAD_EQ_1;
   if (RST_QUAD)    (CSNeg => WPNeg)        = tpd_CSNeg_SO_RST_QUAD_EQ_1;

   if (~RST_QUAD)   (CSNeg => SO)  = tpd_CSNeg_SO_RST_QUAD_EQ_0;
   if (~RST_QUAD)   (CSNeg => SI)  = tpd_CSNeg_SO_RST_QUAD_EQ_0;
   if (~RST_QUAD)   (CSNeg => IO3_RESETNeg) = tpd_CSNeg_SO_RST_QUAD_EQ_0;
   if (~RST_QUAD)   (CSNeg => WPNeg)        = tpd_CSNeg_SO_RST_QUAD_EQ_0;

///////////////////////////////////////////////////////////////////////////////
// Timing Violation                                                          //
///////////////////////////////////////////////////////////////////////////////
    $setup ( CSNeg  , posedge SCK,                    tsetup_CSNeg_SCK , Viol);

    $setup ( SI     , posedge SCK &&& datain,            tsetup_SI_SCK , Viol);
    $setup ( SI     , negedge SCK &&& datain_ddr,        tsetup_SI_SCK , Viol);
    $setup ( SO     , posedge SCK &&& datain,            tsetup_SI_SCK , Viol);
    $setup ( SO     , negedge SCK &&& datain_ddr,        tsetup_SI_SCK , Viol);
    $setup ( IO3_RESETNeg  , posedge SCK &&& datain,     tsetup_SI_SCK , Viol);
    $setup ( IO3_RESETNeg  , negedge SCK &&& datain_ddr, tsetup_SI_SCK , Viol);
    $setup ( WPNeg  , posedge SCK &&& datain,            tsetup_SI_SCK , Viol);
    $setup ( WPNeg  , negedge SCK &&& datain_ddr,        tsetup_SI_SCK , Viol);

    $setup ( WPNeg  , negedge CSNeg &&& WrProt,        tsetup_WPNeg_CSNeg , Viol);

    $hold  ( posedge SCK    , CSNeg,                 thold_CSNeg_SCK    , Viol);

    $hold  ( posedge SCK &&& datain,     SI ,             thold_SI_SCK    ,Viol);
    $hold  ( negedge SCK &&& datain_ddr, SI ,             thold_SI_SCK    ,Viol);
    $hold  ( posedge SCK &&& datain,     SO ,             thold_SI_SCK    ,Viol);
    $hold  ( negedge SCK &&& datain_ddr, SO ,             thold_SI_SCK    ,Viol);
    $hold  ( posedge SCK &&& datain,     IO3_RESETNeg,    thold_SI_SCK    ,Viol);
    $hold  ( negedge SCK &&& datain_ddr, IO3_RESETNeg,    thold_SI_SCK    ,Viol);
    $hold  ( posedge SCK &&& datain,     WPNeg,           thold_SI_SCK    ,Viol);
    $hold  ( negedge SCK &&& datain_ddr, WPNeg,           thold_SI_SCK    ,Viol);

    $hold  ( posedge CSNeg &&& WrProt,  WPNeg,        thold_WPNeg_CSNeg   ,Viol);
    $hold  ( posedge RESETNeg,        negedge CSNeg, thold_CSNeg_RESETNeg,Viol);
    $hold  ( posedge IO3_RESETNeg &&& IO3R, negedge CSNeg, thold_CSNeg_IO3_RESETNeg,Viol);

    $width ( posedge SCK &&& rd_normal           , tpw_SCK_normal);
    $width ( negedge SCK &&& rd_normal           , tpw_SCK_normal);
    $width ( posedge SCK &&& rd_fast             , tpw_SCK_fast);
    $width ( negedge SCK &&& rd_fast             , tpw_SCK_fast);
    $width ( posedge SCK &&& rd_ddr              , tpw_SCK_ddr);
    $width ( negedge SCK &&& rd_ddr              , tpw_SCK_ddr);
    $width ( posedge SCK &&& rd_reg              , tpw_SCK_reg);
    $width ( negedge SCK &&& rd_reg              , tpw_SCK_reg);

    $width ( posedge CSNeg                       , tpw_CSNeg);
    $width ( negedge RESETNeg                    , tpw_RESETNeg);
    $width ( negedge IO3_RESETNeg &&& io3_rst    , tpw_IO3_RESETNeg);

    $period ( posedge SCK &&& rd_normal          , tperiod_SCK_normal);
    $period ( posedge SCK &&& rd_fast            , tperiod_SCK_fast);
    $period ( posedge SCK &&& rd_ddr             , tperiod_SCK_ddr);
    $period ( posedge SCK &&& rd_reg             , tperiod_SCK_reg);

endspecify

///////////////////////////////////////////////////////////////////////////////
// Main Behavior Block                                                       //
///////////////////////////////////////////////////////////////////////////////

    //Power Up time;
    initial
    begin
        PoweredUp = 1'b0;
        #tdevice_PU PoweredUp = 1'b1;
    end

    initial
    begin : Init
        Address     = 0;
        Address_wrar= 0;
        RST         = 1'b1;
        SFT_RST_out = 1'b1;
        HW_RST_out  = 1'b1;
        PDONE       = 1'b1;
        PSTART      = 1'b0;
        PGSUSP      = 1'b0;
        PGRES       = 1'b0;
        PRGSUSP_in  = 1'b0;
        ERSSUSP_in  = 1'b0;
        RES_TO_SUSP_TIME  = 1'b0;
        EDONE       = 1'b1;
        ESTART      = 1'b0;
        ESUSP       = 1'b0;
        ERES        = 1'b0;
        WDONE       = 1'b1;
        WSTART_NV   = 1'b0;
        WSTART_V    = 1'b0;
        reseted     = 1'b0;
        Instruct    = NONE;

        current_state   = STANDBY;
        next_state      = STANDBY;
    end

    // initialize memory and load preload files if any
    initial
    begin: InitMemory
        integer i;

        for (i=0;i<=AddrRANGE;i=i+1)
            Mem[i] = MaxData;


        if ((UserPreload) && !(mem_file_name == "none"))
        begin
           // Memory Preload
           //s25fl128l.mem, memory preload file
           //  @aaaaaaa - <aaaaaaa> stands for address
           //  dd       - <dd> is byte to be written at Mem(aaaaaaa++)
           // (aaaaaaa is incremented at every load)
           $readmemh(mem_file_name,Mem);
        end

        for (i=SECRLoAddr;i<=SECRHiAddr;i=i+1)
            SECRMem[i] = MaxData;

        if (UserPreload && !(secr_file_name == "none"))
        begin
        //s25fl128l_secr memory file
        //   /        - comment
        //   @aaa - <aaa> stands for address
        //   dd  - <dd> is byte to be written at OTPMem(aaa++)
        //   (aaa is incremented at every load)
        //   only first 1-4 columns are loaded. NO empty lines !!!!!!!!!!!!!!!!
           $readmemh(secr_file_name,SECRMem);
        end
    end

    initial
    begin: InitTimingModel
    integer i;
    integer j;
        tmp_timing = TimingModel;//copy of TimingModel

        i = 23;
        while ((i >= 0) && (found != 1'b1))//search for first non null character
        begin        //i keeps position of first non null character
            j = 7;
            while ((j >= 0) && (found != 1'b1))
            begin
                if (tmp_timing[i*8+j] != 1'd0)
                    found = 1'b1;
                else
                    j = j-1;
            end
            i = i - 1;
        end
        i = i +1;
        if (found)//if non null character is found
        begin
            for (j=0;j<=7;j=j+1)
            begin
            //Security character is 15
                tmp_char1[j] = TimingModel[(i-14)*8+j];
            end
        end

        if (tmp_char1 == "S" || tmp_char1 == "s")
        begin
            SECURE_OPN = 1'b1;
            IRP = 16'hFFFF;
        end
        else if (tmp_char1 == "4" )
        begin
            QIO_ONLY_OPN = 1'b1;
            CR1NV = 8'h02;
            CR1V = 8'h02;
        end
        else if (tmp_char1 == "P" || tmp_char1 == "p" )
        begin
            QPI_ONLY_OPN = 1'b1;
            CR2NV = 8'h68;
            CR2V = 8'h68;
        end
    end

    //SFDP
    initial
    begin: InitSFDP
    integer i;
        ///////////////////////////////////////////////////////////////////////
        // SFDP Header
        ///////////////////////////////////////////////////////////////////////
        SFDP_array[16'h0000] = 8'h53;
        SFDP_array[16'h0001] = 8'h46;
        SFDP_array[16'h0002] = 8'h44;
        SFDP_array[16'h0003] = 8'h50;
        SFDP_array[16'h0004] = 8'h06;
        SFDP_array[16'h0005] = 8'h01;
        SFDP_array[16'h0006] = 8'h01;
        SFDP_array[16'h0007] = 8'hFF;
        SFDP_array[16'h0008] = 8'h00;
        SFDP_array[16'h0009] = 8'h06;
        SFDP_array[16'h000A] = 8'h01;
        SFDP_array[16'h000B] = 8'h10;
        SFDP_array[16'h000C] = 8'h00;
        SFDP_array[16'h000D] = 8'h03;
        SFDP_array[16'h000E] = 8'h00;
        SFDP_array[16'h000F] = 8'hFF;
        SFDP_array[16'h0010] = 8'h84;
        SFDP_array[16'h0011] = 8'h00;
        SFDP_array[16'h0012] = 8'h01;
        SFDP_array[16'h0013] = 8'h02;
        SFDP_array[16'h0014] = 8'h40;
        SFDP_array[16'h0015] = 8'h03;
        SFDP_array[16'h0016] = 8'h00;
        SFDP_array[16'h0017] = 8'hFF;
        for (i=16'h0018; i<16'h02FF; i=i+1)
        begin
            SFDP_array[i] = 8'hFF; // undefined space
        end
        // Basic SPI Flash Parameter, JEDEC SFDP Rev B
        SFDP_array[16'h0300] = 8'hE5;
        SFDP_array[16'h0301] = 8'h20;
        SFDP_array[16'h0302] = 8'hFB;
        SFDP_array[16'h0303] = 8'hFF;
        SFDP_array[16'h0304] = 8'hFF;
        SFDP_array[16'h0305] = 8'hFF;
        SFDP_array[16'h0306] = 8'hFF;
        SFDP_array[16'h0307] = 8'h03;
        SFDP_array[16'h0308] = 8'h48;
        SFDP_array[16'h0309] = 8'hEB;
        SFDP_array[16'h030A] = 8'h08;
        SFDP_array[16'h030B] = 8'h6B;
        SFDP_array[16'h030C] = 8'h08;
        SFDP_array[16'h030D] = 8'h3B;
        SFDP_array[16'h030E] = 8'h88;
        SFDP_array[16'h030F] = 8'hBB;
        SFDP_array[16'h0310] = 8'hFE;
        SFDP_array[16'h0311] = 8'hFF;
        SFDP_array[16'h0312] = 8'hFF;
        SFDP_array[16'h0313] = 8'hFF;
        SFDP_array[16'h0314] = 8'hFF;
        SFDP_array[16'h0315] = 8'hFF;
        SFDP_array[16'h0316] = 8'hFF;
        SFDP_array[16'h0317] = 8'hFF;
        SFDP_array[16'h0318] = 8'hFF;
        SFDP_array[16'h0319] = 8'hFF;
        SFDP_array[16'h031A] = 8'h48;
        SFDP_array[16'h031B] = 8'hEB;
        SFDP_array[16'h031C] = 8'h0C;
        SFDP_array[16'h031D] = 8'h20;
        SFDP_array[16'h031E] = 8'h0F;
        SFDP_array[16'h031F] = 8'h52;
        SFDP_array[16'h0320] = 8'h10;
        SFDP_array[16'h0321] = 8'hD8;
        SFDP_array[16'h0322] = 8'h00;
        SFDP_array[16'h0323] = 8'hFF;
        SFDP_array[16'h0324] = 8'h31;
        SFDP_array[16'h0325] = 8'h92;
        SFDP_array[16'h0326] = 8'h0D; //
        SFDP_array[16'h0327] = 8'hFF; //
        SFDP_array[16'h0328] = 8'h81;
        SFDP_array[16'h0329] = 8'h66;
        SFDP_array[16'h032A] = 8'h4E;
        SFDP_array[16'h032B] = 8'hCD;
        SFDP_array[16'h032C] = 8'hCC;
        SFDP_array[16'h032D] = 8'h83;
        SFDP_array[16'h032E] = 8'h18;
        SFDP_array[16'h032F] = 8'h44;
        SFDP_array[16'h0330] = 8'h7A;
        SFDP_array[16'h0331] = 8'h75;
        SFDP_array[16'h0332] = 8'h7A;
        SFDP_array[16'h0333] = 8'h75;
        SFDP_array[16'h0334] = 8'hF7;
        SFDP_array[16'h0335] = 8'hA2;
        SFDP_array[16'h0336] = 8'hD5;
        SFDP_array[16'h0337] = 8'h5C;
        SFDP_array[16'h0338] = 8'h22;
        SFDP_array[16'h0339] = 8'hF6;
        SFDP_array[16'h033A] = 8'h5D;
        SFDP_array[16'h033B] = 8'hFF;
        SFDP_array[16'h033C] = 8'hE8;
        SFDP_array[16'h033D] = 8'h50;
        SFDP_array[16'h033E] = 8'hF8;
        SFDP_array[16'h033F] = 8'hA1;
        // 4-byte Address Instruction, JEDEC SFDP Rev B
        SFDP_array[16'h0340] = 8'hFB;
        SFDP_array[16'h0341] = 8'h8E;
        SFDP_array[16'h0342] = 8'hF3;
        SFDP_array[16'h0343] = 8'hFF;
        SFDP_array[16'h0344] = 8'h21;
        SFDP_array[16'h0345] = 8'h52;
        SFDP_array[16'h0346] = 8'hDC;
        SFDP_array[16'h0347] = 8'hFF;
        for (i=16'h0348; i<16'h0600; i=i+1)
        begin
            SFDP_array[i] = 8'hFF; // undefined space
        end
    end

    always @(next_state or PoweredUp or falling_edge_RST or HW_RST_out or
    SFT_RST_out)
    begin: StateTransition1
        if (PoweredUp)
        begin
            if ((!RESETNeg || !IO3_RESETNeg) &&
                                         falling_edge_RST)
            begin
            // no state transition while RESET# low
                current_state = RESET_STATE;
                HW_RST_in = 1'b1;
                HW_RST_in <= #1 1'b0;
                reseted   = 1'b0;
            end
            else if (HW_RST_out && SFT_RST_out)
            begin
                current_state <= next_state;
                reseted = 1;
            end
            if (!SFT_RST_out)
            begin
                current_state = RESET_STATE;
                reseted   = 1'b0;
            end
        end
    end

    always @(negedge RESETNeg or negedge IO3_RESETNeg)
    begin:HW_RESET
            // hw reset ignored during WRR operation and WRAR to NV Status and
            // Configuration registers
        if (!RESETNeg)
        begin
            if (!WRR_NV_ACT && !(WRAR_NV_ACT && (Address==24'd0 ||
            Address==24'd2 || Address==24'd3 || Address==24'd4)))
                RST <= #200000 RESETNeg;
        end

        if (!IO3_RESETNeg && CR2V[7] && (CSNeg_ipd || (!QUAD  && !QPI)))
        begin
            if (!WRR_NV_ACT && !(WRAR_NV_ACT && (Address==23'd0 ||
            Address==24'd2 || Address==24'd3 || Address==24'd4)))
                RST <= #200000 IO3_RESETNeg;
        end

    end

    always @(posedge RESETNeg)
    begin
        if (PoweredUp)
        begin
            if (RESETNeg)
            begin
                disable HW_RESET;
                RST = 1'b1;
            end
        end
    end

    always @(posedge IO3_RESETNeg)
    begin
        if (PoweredUp)
        begin
            if (IO3_RESETNeg && CR2V[7])
            begin
                disable HW_RESET;
                RST = 1'b1;
            end
        end
    end

    always @(negedge CSNeg_ipd)
    begin:CheckCSOnPowerUP
        if (~PoweredUp)
            $display ("Device is selected during Power Up");
    end

    ///////////////////////////////////////////////////////////////////////////
    //// Internal Delays
    ///////////////////////////////////////////////////////////////////////////

    always @(posedge PRGSUSP_in)
    begin:PRGSuspend
        PRGSUSP_out = 1'b0;
        #tdevice_SUSP PRGSUSP_out = 1'b1;
    end

    always @(posedge ERSSUSP_in)
    begin:ERSSuspend
        ERSSUSP_out = 1'b0;
        #tdevice_SUSP ERSSUSP_out = 1'b1;
    end

    always @(posedge PASSULCK_in)
    begin:PASSULock
        PASSULCK_out = 1'b0;
        #tdevice_PASSACC PASSULCK_out = 1'b1;
    end

    always @(posedge DPD_in)
    begin:DPDown
        DPD_out = 1'b0;
        #tdevice_DPD DPD_out = 1'b1;
    end

    always @(posedge RES_in)
    begin:DPDRes
        RES_out = 1'b0;
        #tdevice_RES RES_out = 1'b1;
    end

    always @(posedge QEN_in)
    begin:QPIEn
        QEN_out = 1'b0;
        #tdevice_QEN QEN_out = 1'b1;
    end

    always @(posedge QEXN_in)
    begin:QPIEx
        QEXN_out = 1'b0;
        #tdevice_QEXN QEXN_out = 1'b1;
    end
    // Timing control for the Hardware Reset
    always @(posedge HW_RST_in)
    begin:HW_RST
        HW_RST_out = 1'b0;
        #tdevice_RPH HW_RST_out = 1'b1;
    end
    // Timing control for the Software Reset
    always @(posedge SFT_RST_in)
    begin:SFT_RST
        SFT_RST_out = 1'b0;
        #tdevice_RPH SFT_RST_out = 1'b1;
    end

///////////////////////////////////////////////////////////////////////////////
// write cycle decode
///////////////////////////////////////////////////////////////////////////////


///////////////////////////////////////////////////////////////////////////////
// Timing control for the Page Program
///////////////////////////////////////////////////////////////////////////////
    time  pob;
    time  elapsed_pgm;
    time  start_pgm;
    time  duration_pgm;
    event pdone_event;

    always @(rising_edge_PSTART or rising_edge_reseted)
    begin : ProgTime

        if (wr_cnt==1)
            pob = tdevice_BP1;
        else if (wr_cnt==PageSize)
            pob = tdevice_PP;
        else
            pob = tdevice_BP1 + wr_cnt*tdevice_BP2;
        if (IRP_ACT)
            pob = tdevice_BP1 + tdevice_BP2;
        if (PASS_PGM_ACT)
            pob = tdevice_BP1 + 7*tdevice_BP2;

        if (rising_edge_reseted)
        begin
            PDONE = 1; // reset done, programing terminated
            disable pdone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_PSTART && PDONE)
            begin
                elapsed_pgm = 0;
                duration_pgm = pob;
                PDONE = 1'b0;
                start_pgm = $time;
                ->pdone_event;
            end
        end
    end

    always @(posedge PGSUSP)
    begin
        if (PGSUSP && (~PDONE))
        begin
            disable pdone_process;
            elapsed_pgm = $time - start_pgm;
            duration_pgm = duration_pgm - elapsed_pgm;
            PDONE = 1'b0;
        end
    end

    always @(posedge PGRES)
    begin
        start_pgm = $time;
        ->pdone_event;
    end

    always @(pdone_event)
    begin : pdone_process
        #(duration_pgm) PDONE = 1;
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for the Write Status Register
///////////////////////////////////////////////////////////////////////////////
    time  wob;
    event wdone_event;
    event csdone_event;

    always @(rising_edge_WSTART_NV or rising_edge_WSTART_V or rising_edge_reseted)
    begin:WriteTime

        if (rising_edge_reseted)
        begin
            WDONE = 1; // reset done, Write terminated
            disable wdone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_WSTART_NV && WDONE)
            begin
                wob = tdevice_WRR;
                WDONE = 1'b0;
                -> wdone_event;
            end
            else if (rising_edge_WSTART_V && WDONE)
            begin
                wob = tdevice_CS;
                WDONE = 1'b0;
                -> wdone_event;
            end
        end
    end

    always @(wdone_event)
    begin : wdone_process
        #wob WDONE = 1;
    end

///////////////////////////////////////////////////////////////////////////////
// Timing control for Erase
///////////////////////////////////////////////////////////////////////////////
    event edone_event;
    time elapsed_ers;
    time start_ers;
    time duration_ers;

    always @(rising_edge_ESTART or rising_edge_reseted)
    begin : ErsTime
        if (SECT_ERS_ACT)
            duration_ers = tdevice_SE;
        else if (HALF_BLOCK_ERS_ACT)
            duration_ers = tdevice_HBE;
        else if (BLOCK_ERS_ACT)
            duration_ers = tdevice_BE;
        else if (CHIP_ERS_ACT)
            duration_ers = tdevice_CE;
        else
            duration_ers = tdevice_SE;

        if (rising_edge_reseted)
        begin
            EDONE = 1; // reset done, ERASE terminated
            disable edone_process;
        end
        else if (reseted)
        begin
            if (rising_edge_ESTART && EDONE)
            begin
                elapsed_ers = 0;
                EDONE = 1'b0;
                start_ers = $time;
                ->edone_event;
            end
        end
    end

    always @(posedge ESUSP)
    begin
        if (ESUSP && (~EDONE))
        begin
            disable edone_process;
            elapsed_ers = $time - start_ers;
            duration_ers = duration_ers - elapsed_ers;
            EDONE = 1'b0;
        end
    end

    always @(posedge ERES)
    begin
        if  (ERES && (~EDONE))
        begin
            start_ers = $time;
            ->edone_event;
        end
    end

    always @(edone_event)
    begin : edone_process
        EDONE = 1'b0;
        #duration_ers EDONE = 1'b1;
    end

    ///////////////////////////////////////////////////////////////////
    // Process for clock frequency determination
    ///////////////////////////////////////////////////////////////////
    always @(posedge SCK_ipd)
    begin : clock_period
        if (SCK_ipd)
        begin
            CLK_PER = $time - LAST_CLK;
            LAST_CLK = $time;
        end
    end

//    /////////////////////////////////////////////////////////////////////////
//    // Main Behavior Process
//    // combinational process for next state generation
//    /////////////////////////////////////////////////////////////////////////

    integer i;
    integer j;

    always @(rising_edge_CSNeg_ipd or
    rising_edge_SCK_D or falling_edge_SCK_D or falling_edge_RES_in or
    rising_edge_PDONE or rising_edge_PRGSUSP_out or rising_edge_ERSSUSP_out or
    rising_edge_CSNeg_d or rising_edge_PASSULCK_out or rising_edge_SFT_RST_out
    or rising_edge_HW_RST_out or rising_edge_EDONE or rising_edge_WDONE)
    begin: StateGen1
        case (current_state)
            STANDBY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==READ || Instruct==READ4)
                        next_state <= RD_ADDR;
                    else if (Instruct==FAST_READ || Instruct==FAST_READ4)
                        next_state <= FAST_RD_ADDR;
                    else if (Instruct==DOR || Instruct==DOR4)
                        next_state <= DUALO_RD_ADDR;
                    else if (Instruct==DIOR || Instruct==DIOR4)
                        next_state <= DUALIO_RD_ADDR;
                    else if (Instruct==QOR || Instruct==QOR4)
                    begin
                        if (QUAD)
                            next_state <= QUADO_RD_ADDR;
                    end
                    else if (Instruct==QIOR || Instruct==QIOR4)
                    begin
                        if (QUAD || QPI)
                            next_state <= QUADIO_RD_ADDR;
                    end
                    else if (Instruct==DDRQIOR || Instruct==DDRQIOR4)
                    begin
                        if (QUAD || QPI)
                            next_state <= DDRQUADIO_RD_ADDR;
                    end
                    else if (Instruct==DLPRD)
                        next_state <= DLPRD_DUMMY;
                    else if (Instruct==IRPRD)
                        next_state <= IRPRD_DUMMY;
                    else if (Instruct==IBLRD || Instruct==IBLRD4)
                        next_state <= IBLRD_ADDR;
                    else if (Instruct==SECRR)
                        next_state <= SECRR_ADDR;
                    else if (Instruct==PASSRD && IRP[2])
                        next_state <= PASSRD_DUMMY;
                    else if (Instruct==PRRD)
                        next_state <= PRRD_DUMMY;
                    else if (Instruct==RDID)
                        next_state <= RDID_DATA_OUTPUT;
                    else if (Instruct==RDQID)
                    begin
                        if (QUAD || QPI)
                            next_state <= RDQID_DATA_OUTPUT;
                    end
                    else if (Instruct==RUID)
                        next_state <= RUID_DUMMY;
                    else if (Instruct==RSFDP)
                        next_state <= RSFDP_ADDR;
                    else if (Instruct==SET_BURST)
                        next_state <= SET_BURST_DATA_INPUT;
                    else if (Instruct==RDSR1)
                        next_state <= RDSR1_DATA_OUTPUT;
                    else if (Instruct==RDSR2)
                        next_state <= RDSR2_DATA_OUTPUT;
                    else if (Instruct==RDCR1)
                        next_state <= RDCR1_DATA_OUTPUT;
                    else if (Instruct==RDCR2)
                        next_state <= RDCR2_DATA_OUTPUT;
                    else if (Instruct==RDCR3)
                        next_state <= RDCR3_DATA_OUTPUT;
                    else if (Instruct==RDAR)
                        next_state <= RDAR_ADDR;
                    else if (Instruct==RES)
                        next_state <= RDP_DUMMY;
                    else if (Instruct==PP || Instruct==PP4)
                    begin
                        if (WEL == 1'b1)
                            next_state <= PGM_ADDR;
                    end
                    else if (Instruct==QPP || Instruct==QPP4)
                    begin
                        if (WEL == 1'b1 && QUAD)
                            next_state <= PGM_ADDR;
                    end
                    else if (Instruct==SE || Instruct==SE4)
                    begin
                        if (WEL == 1'b1)
                            next_state <= SECT_ERS_ADDR;
                    end
                    else if (Instruct==HBE || Instruct==HBE4)
                    begin
                        if (WEL == 1'b1)
                            next_state <= HALF_BLOCK_ERS_ADDR;
                    end
                    else if (Instruct==BE || Instruct==BE4)
                    begin
                        if (WEL == 1'b1)
                            next_state <= BLOCK_ERS_ADDR;
                    end
                    else if (Instruct==IBL || Instruct==IBL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_LOCK;
                    end
                    else if (Instruct==IRPP)
                    begin
                        if (WEL == 1'b1)
                            next_state <= IRP_PGM_DATA_INPUT;
                    end
                    else if (Instruct==WRR)
                    begin
                        if (WEL == 1'b1 || WREN_V == 1'b1)
                            next_state <= WRR_DATA_INPUT;
                    end
                    else if (Instruct==WRAR)
                    begin
                        if (WEL == 1'b1)
                            next_state <= WRAR_ADDR;
                    end
                    else if (Instruct==PASSP)
                    begin
                        if (WEL == 1'b1)
                            if (IRP[2] == 1'b1)
                                next_state <= PASSP_DATA_INPUT;
                    end
                    else if (Instruct==SECRP)
                    begin
                        if (WEL == 1'b1)
                            next_state <= SEC_REG_PGM_ADDR;
                    end
                    else if (Instruct==SECRE)
                    begin
                        if (WEL == 1'b1)
                            next_state <= SEC_REG_ERS_ADDR;
                    end
                    else if (Instruct==PASSU)
                    begin
                        next_state <= PASSU_DATA_INPUT;
                    end
                    else if (Instruct==IBUL || Instruct==IBUL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_UNLOCK;
                    end
                    else if (Instruct==SPRP || Instruct==SPRP4)
                    begin
                        if (WEL == 1'b1)
                            if (NVLOCK == 1'b1)
                                next_state <= SET_PNTR_PROT_ADDR;
                    end
                    else if (Instruct==PDLRNV)
                    begin
                        if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                            if (WEL == 1'b1)
                                if (!DLRNV_programmed) // OTP
                                    next_state <= PGM_NV_DLR_DATA;
                    end
                    else if (Instruct==WDLRV)
                    begin
                        if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                            if (WEL == 1'b1)
                                next_state <= DLRV_WRITE_DATA;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                        else if (Instruct==DEEP_PD)
                            next_state <= DPD;
                        else if (Instruct==CE)
                        begin
                            if (WEL == 1'b1)
                                next_state <= CHIP_ERS;
                        end
                    end
                end
            end

            SFT_RST_EN :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RSTCMD)
                            next_state = RESET_STATE;
                        else
                            next_state = STANDBY;
                    end
                end
            end

            RESET_STATE :
            begin
                if (rising_edge_SFT_RST_out || rising_edge_HW_RST_out)
                    if (SFT_RST_out &&  HW_RST_out)
                        next_state = STANDBY;
            end

            DPD :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==9)
                        if (Instruct==RES)
                            next_state <= RDP_DUMMY;
                end
                if (falling_edge_RES_in)
                    next_state <= STANDBY;
            end

            RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((Instruct==READ) && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= RD_DATA;
                    end
                    else if ((Instruct==READ4) ||
                    ((Instruct==READ) && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= RD_DATA;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RD_DATA, FAST_RD_DATA, DUALO_RD_DATA, QUADO_RD_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            FAST_RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==FAST_READ && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= FAST_RD_DUMMY;
                    end
                    else if (Instruct==FAST_READ4 ||
                    (Instruct==FAST_READ && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= FAST_RD_DUMMY;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            FAST_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= FAST_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALO_RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==DOR && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= DUALO_RD_DUMMY;
                    end
                    else if (Instruct==DOR4 ||
                    (Instruct==DOR && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= DUALO_RD_DUMMY;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALO_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= DUALO_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            QUADO_RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==QOR && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= QUADO_RD_DUMMY;
                    end
                    else if (Instruct==QOR4 ||
                    (Instruct==QOR && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= QUADO_RD_DUMMY;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            QUADO_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= QUADO_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALIO_RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==DIOR && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= DUALIO_RD_MODE;
                    end
                    else if (Instruct==DIOR4 ||
                    (Instruct==DIOR && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= DUALIO_RD_MODE;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALIO_RD_MODE :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (mode_cnt == 8)
                        next_state <= DUALIO_RD_DUMMY;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= DUALIO_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DUALIO_RD_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (mode_byte[7:4] == 4'b1010)
                        next_state <= DUALIO_RD_ADDR;
                    else
                    begin
                        if (SR2V[0])
                            next_state <= PGMSUS;
                        else if (SR2V[1])
                            next_state <= ERSSUS;
                        else
                            next_state <= STANDBY;
                    end
                end
            end

            QUADIO_RD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==QIOR && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= QUADIO_RD_MODE;
                    end
                    else if (Instruct==QIOR4 ||
                    (Instruct==QIOR && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= QUADIO_RD_MODE;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            QUADIO_RD_MODE :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (mode_cnt == 8)
                        next_state <= QUADIO_RD_DUMMY;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            QUADIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= QUADIO_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            QUADIO_RD_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (mode_byte[7:4] == 4'b1010)
                        next_state <= QUADIO_RD_ADDR;
                    else
                    begin
                        if (SR2V[0])
                            next_state <= PGMSUS;
                        else if (SR2V[1])
                            next_state <= ERSSUS;
                        else
                            next_state <= STANDBY;
                    end
                end
            end

            DDRQUADIO_RD_ADDR :
            begin
                if (falling_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==DDRQIOR && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= DDRQUADIO_RD_MODE;
                    end
                    else if (Instruct==DDRQIOR4 ||
                    (Instruct==DDRQIOR && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= DDRQUADIO_RD_MODE;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DDRQUADIO_RD_MODE :
            begin
                if (falling_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (mode_cnt == 8)
                        next_state <= DDRQUADIO_RD_DUMMY;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DDRQUADIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == 2*Latency_code )
                        next_state <= DDRQUADIO_RD_DATA;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DDRQUADIO_RD_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (mode_byte[7:4] == ~mode_byte[3:0])
                        next_state <= DDRQUADIO_RD_ADDR;
                  else
                  begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                  end
                end
            end

            RDAR_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((!CR2V[0] && addr_cnt==24) ||
                    (CR2V[0] && addr_cnt==32))
                        next_state <= RDAR_DUMMY;
                end

                // if the Read Any Register is broken early (in address phase)
                if (rising_edge_CSNeg_ipd)
                begin
                    next_state <= STANDBY;
                    if (CHIP_ERS_ACT)
                        next_state <= CHIP_ERS;
                    if (SECT_ERS_ACT)
                        next_state <= SECT_ERS;
                    if (HALF_BLOCK_ERS_ACT)
                        next_state <= HALF_BLOCK_ERS;
                    if (BLOCK_ERS_ACT)
                        next_state <= BLOCK_ERS;
                    if (SR2V[1])
                        next_state <= ERSSUS;
                    if (PGM_ACT)
                        next_state <= PGM;
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    if (PGM_SEC_REG_ACT)
                        next_state <= PGM_SEC_REG;
                    if (SECT_ERS_SEC_REG_ACT)
                        next_state <= SECT_ERS_SEC_REG;
                    if (WRR_NV_ACT)
                        next_state <= WRR_NV;
                    if (WRAR_NV_ACT)
                        next_state <= WRAR_NV;
                    if (IRP_ACT)
                        next_state <= IRP_PGM;
                    if (DLRNV_ACT)
                        next_state <= PGM_NV_DLR;
                    if (SET_PNTR_PROT_ACT)
                        next_state <= SET_PNTR_PROT;
                    if (PASS_PGM_ACT)
                        next_state <= PASS_PGM;
                    if (PASSULCK_in)
                        next_state <= PASS_ULCK;
                end
            end

            RDAR_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= RDAR_DATA_OUTPUT;
                end

                // if the Read Any Register is broken early (in dummy phase)
                if (rising_edge_CSNeg_ipd)
                begin
                    next_state <= STANDBY;
                    if (CHIP_ERS_ACT)
                        next_state <= CHIP_ERS;
                    if (SECT_ERS_ACT)
                        next_state <= SECT_ERS;
                    if (HALF_BLOCK_ERS_ACT)
                        next_state <= HALF_BLOCK_ERS;
                    if (BLOCK_ERS_ACT)
                        next_state <= BLOCK_ERS;
                    if (SR2V[1])
                        next_state <= ERSSUS;
                    if (PGM_ACT)
                        next_state <= PGM;
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    if (PGM_SEC_REG_ACT)
                        next_state <= PGM_SEC_REG;
                    if (SECT_ERS_SEC_REG_ACT)
                        next_state <= SECT_ERS_SEC_REG;
                    if (WRR_NV_ACT)
                        next_state <= WRR_NV;
                    if (WRAR_NV_ACT)
                        next_state <= WRAR_NV;
                    if (IRP_ACT)
                        next_state <= IRP_PGM;
                    if (DLRNV_ACT)
                        next_state <= PGM_NV_DLR;
                    if (SET_PNTR_PROT_ACT)
                        next_state <= SET_PNTR_PROT;
                    if (PASS_PGM_ACT)
                        next_state <= PASS_PGM;
                    if (PASSULCK_in)
                        next_state <= PASS_ULCK;
                end
            end

            RDSR1_DATA_OUTPUT, RDSR2_DATA_OUTPUT, RDCR1_DATA_OUTPUT,
            RDCR2_DATA_OUTPUT, RDCR3_DATA_OUTPUT, RDAR_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    next_state <= STANDBY;
                    if (CHIP_ERS_ACT)
                        next_state <= CHIP_ERS;
                    if (SECT_ERS_ACT)
                        next_state <= SECT_ERS;
                    if (HALF_BLOCK_ERS_ACT)
                        next_state <= HALF_BLOCK_ERS;
                    if (BLOCK_ERS_ACT)
                        next_state <= BLOCK_ERS;
                    if (SR2V[1])
                        next_state <= ERSSUS;
                    if (PGM_ACT)
                        next_state <= PGM;
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    if (PGM_SEC_REG_ACT)
                        next_state <= PGM_SEC_REG;
                    if (SECT_ERS_SEC_REG_ACT)
                        next_state <= SECT_ERS_SEC_REG;
                    if (WRR_NV_ACT)
                        next_state <= WRR_NV;
                    if (WRAR_NV_ACT)
                        next_state <= WRAR_NV;
                    if (IRP_ACT)
                        next_state <= IRP_PGM;
                    if (DLRNV_ACT)
                        next_state <= PGM_NV_DLR;
                    if (SET_PNTR_PROT_ACT)
                        next_state <= SET_PNTR_PROT;
                    if (PASS_PGM_ACT)
                        next_state <= PASS_PGM;
                    if (PASSULCK_in)
                        next_state <= PASS_ULCK;
                end
            end

            DLPRD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= DLPRD_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            DLPRD_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            IRPRD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= IRPRD_DATA_OUTPUT;
                end
               if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            IRPRD_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            IBLRD_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((Instruct==IBLRD && ((!CR2V[0] && addr_cnt==24) ||
                    (CR2V[0] && addr_cnt==32))) ||
                    (Instruct==IBLRD4 && addr_cnt==32))
                        next_state <= IBLRD_DATA_OUTPUT;
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end

            end

            IBLRD_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SECRR_ADDR :
            begin
                if (falling_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((!CR2V[0] && addr_cnt==24) ||
                    (CR2V[0] && addr_cnt==32))
                        next_state <= SECRR_DUMMY;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SECRR_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= SECRR_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SECRR_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            PASSRD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= PASSRD_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            PASSRD_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            PRRD_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= PRRD_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            PRRD_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            RDID_DATA_OUTPUT, RDQID_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RUID_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= RUID_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RUID_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RSFDP_ADDR :
            begin
                if (falling_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((!CR2V[0] && addr_cnt==24) ||
                    (CR2V[0] && addr_cnt==32))
                        next_state <= RSFDP_DUMMY;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RSFDP_DUMMY :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == Latency_code)
                        next_state <= RSFDP_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RSFDP_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SET_BURST_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            RDP_DUMMY : //release DP
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (dummy_cnt == 24)
                        next_state <= RDP_DATA_OUTPUT;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (DPD_ACT)
                        next_state <= DPD;
                    else
                        next_state <= STANDBY;
                end
            end

            RDP_DATA_OUTPUT:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (DPD_ACT)
                        next_state <= DPD;
                    else
                        next_state <= STANDBY;
                end
                if (falling_edge_RES_in)// when in DPD mode
                    next_state <= STANDBY;
            end

            PGM_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((Instruct==PP || Instruct==QPP) && !CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= PGM_DATAIN;
                    end
                    else if (Instruct==PP4 || Instruct==QPP4 ||
                    ((Instruct==PP || Instruct==QPP) && CR2V[0]))
                    begin
                        if (addr_cnt == 32)
                            next_state <= PGM_DATAIN;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[1])  // erase suspend
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            PGM_DATAIN :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==0 && byte_cnt>0)
                        next_state <= PGM;
                  else
                  begin
                      if (SR2V[1])  // erase suspend
                          next_state <= ERSSUS;
                      else
                          next_state <= STANDBY;
                  end
                end
            end

            PGM :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                if (SR2V[1])  // erase suspend
                                    next_state <= ERSSUS;
                                else
                                    next_state <= STANDBY;
                            end
                        end
                        else if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                    end
                end

                if (rising_edge_PRGSUSP_out)
                    next_state <= PGMSUS;
                if (rising_edge_PDONE ||
                // operation finished during status read
                (rising_edge_CSNeg_d && PDONE && !SR2V[5]))
                begin
                    if (SR2V[1])  // erase suspend
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SECT_ERS_ADDR :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == SE4 && addr_cnt == 32) ||
                    (Instruct == SE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                        next_state <= SECT_ERS;
                    else
                        next_state <= STANDBY;
                end
            end

            HALF_BLOCK_ERS_ADDR :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == HBE4 && addr_cnt == 32) ||
                    (Instruct == HBE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                        next_state <= HALF_BLOCK_ERS;
                    else
                        next_state <= STANDBY;
                end
            end

            BLOCK_ERS_ADDR :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == BE4 && addr_cnt == 32) ||
                    (Instruct == BE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                        next_state <= BLOCK_ERS;
                    else
                        next_state <= STANDBY;
                end
            end

            SECT_ERS, HALF_BLOCK_ERS, BLOCK_ERS :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[6])
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                    end
                end
                if (rising_edge_ERSSUSP_out)
                    next_state <= ERSSUS;
                if (rising_edge_EDONE ||
                // operation finished during status read)
                (rising_edge_CSNeg_d && EDONE  && !SR2V[6]))
                    next_state <= STANDBY;
            end

            CHIP_ERS :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[6])
                                next_state = STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end
                if (rising_edge_EDONE ||
                // operation finished during status read)
                (rising_edge_CSNeg_d && EDONE  && !SR2V[6]))
                    next_state = STANDBY;
            end

            SEC_REG_PGM_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (!CR2V[0])
                    begin
                        if (addr_cnt == 24)
                            next_state <= SEC_REG_PGM_DATAIN;
                    end
                    else if (CR2V[0])
                    begin
                        if (addr_cnt == 32)
                            next_state <= SEC_REG_PGM_DATAIN;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SEC_REG_PGM_DATAIN :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==0 && byte_cnt>0 &&
                  Address<=SECRHiAddr)
                      next_state <= PGM_SEC_REG;
                  else
                  begin
                      if (SR2V[1])
                          next_state <= ERSSUS;
                      else
                          next_state <= STANDBY;
                  end
                end
            end

            PGM_SEC_REG :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                if (SR2V[1])  // erase suspend
                                    next_state <= ERSSUS;
                                else
                                    next_state <= STANDBY;
                            end
                        end
                        else if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                    end
                end

                if (rising_edge_PDONE ||
                // operation finished during status read
                (rising_edge_CSNeg_d && PDONE  && !SR2V[5]))
                begin
                    if (SR2V[1])  // erase suspend
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            SEC_REG_ERS_ADDR :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))
                        next_state <= SECT_ERS_SEC_REG;
                    else
                    begin
                        if (SR2V[1])
                            next_state <= ERSSUS;
                        else
                            next_state <= STANDBY;
                    end
                end
            end

            SECT_ERS_SEC_REG :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[6])
                                next_state = STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end
                if (rising_edge_EDONE ||
                // operation finished during status read
                (rising_edge_CSNeg_d && EDONE  && !SR2V[6]))
                    next_state <= STANDBY;
            end

            PGMSUS :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==READ || Instruct==READ4)
                        next_state <= RD_ADDR;
                    else if (Instruct==FAST_READ || Instruct==FAST_READ4)
                        next_state <= FAST_RD_ADDR;
                    else if (Instruct==DOR || Instruct==DOR4)
                        next_state <= DUALO_RD_ADDR;
                    else if (Instruct==DIOR || Instruct==DIOR4)
                        next_state <= DUALIO_RD_ADDR;
                    else if (Instruct==QOR || Instruct==QOR4)
                    begin
                        if (QUAD)
                            next_state <= QUADO_RD_ADDR;
                    end
                    else if (Instruct==QIOR || Instruct==QIOR4)
                    begin
                        if (QUAD || QPI)
                            next_state <= QUADIO_RD_ADDR;
                    end
                    else if (Instruct==DDRQIOR || Instruct==DDRQIOR4)
                    begin
                        if (QUAD || QPI)
                        next_state <= DDRQUADIO_RD_ADDR;
                    end
                    else if (Instruct==DLPRD)
                        next_state <= DLPRD_DUMMY;
                    else if (Instruct==IBLRD || Instruct==IBLRD4)
                        next_state <= IBLRD_ADDR;
                    else if (Instruct==SECRR)
                        next_state <= SECRR_ADDR;
                    else if (Instruct==RDID)
                        next_state <= RDID_DATA_OUTPUT;
                    else if (Instruct==RDQID)
                        next_state <= RDQID_DATA_OUTPUT;
                    else if (Instruct==RUID)
                        next_state <= RUID_DUMMY;
                    else if (Instruct==RSFDP)
                        next_state <= RSFDP_ADDR;
                    else if (Instruct==SET_BURST)
                        next_state <= SET_BURST_DATA_INPUT;
                    else if (Instruct==RDSR1)
                        next_state <= RDSR1_DATA_OUTPUT;
                    else if (Instruct==RDSR2)
                        next_state <= RDSR2_DATA_OUTPUT;
                    else if (Instruct==RDCR1)
                        next_state <= RDCR1_DATA_OUTPUT;
                    else if (Instruct==RDCR2)
                        next_state <= RDCR2_DATA_OUTPUT;
                    else if (Instruct==RDCR3)
                        next_state <= RDCR3_DATA_OUTPUT;
                    else if (Instruct==RDAR)
                        next_state <= RDAR_ADDR;
                    else if (Instruct==IBL || Instruct==IBL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_LOCK;
                    end
                    else if (Instruct==IBUL || Instruct==IBUL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_UNLOCK;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                        else if (Instruct==EPR)
                            next_state <= PGM;
                    end
                end
            end

            ERSSUS :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (Instruct==READ || Instruct==READ4)
                        next_state <= RD_ADDR;
                    else if (Instruct==FAST_READ || Instruct==FAST_READ4)
                        next_state <= FAST_RD_ADDR;
                    else if (Instruct==DOR || Instruct==DOR4)
                        next_state <= DUALO_RD_ADDR;
                    else if (Instruct==DIOR || Instruct==DIOR4)
                        next_state <= DUALIO_RD_ADDR;
                    else if (Instruct==QOR || Instruct==QOR4)
                    begin
                        if (QUAD)
                            next_state <= QUADO_RD_ADDR;
                    end
                    else if (Instruct==QIOR || Instruct==QIOR4)
                    begin
                        if (QUAD || QPI)
                            next_state <= QUADIO_RD_ADDR;
                    end
                    else if (Instruct==DDRQIOR || Instruct==DDRQIOR4)
                    begin
                        if (QUAD || QPI)
                        next_state <= DDRQUADIO_RD_ADDR;
                    end
                    else if (Instruct==DLPRD)
                        next_state <= DLPRD_DUMMY;
                    else if (Instruct==IBLRD || Instruct==IBLRD4)
                        next_state <= IBLRD_ADDR;
                    else if (Instruct==SECRR)
                        next_state <= SECRR_ADDR;
                    else if (Instruct==RDID)
                        next_state <= RDID_DATA_OUTPUT;
                    else if (Instruct==RDQID)
                        next_state <= RDQID_DATA_OUTPUT;
                    else if (Instruct==RUID)
                        next_state <= RUID_DUMMY;
                    else if (Instruct==RSFDP)
                        next_state <= RSFDP_ADDR;
                    else if (Instruct==SET_BURST)
                        next_state <= SET_BURST_DATA_INPUT;
                    else if (Instruct==RDSR1)
                        next_state <= RDSR1_DATA_OUTPUT;
                    else if (Instruct==RDSR2)
                        next_state <= RDSR2_DATA_OUTPUT;
                    else if (Instruct==RDCR1)
                        next_state <= RDCR1_DATA_OUTPUT;
                    else if (Instruct==RDCR2)
                        next_state <= RDCR2_DATA_OUTPUT;
                    else if (Instruct==RDCR3)
                        next_state <= RDCR3_DATA_OUTPUT;
                    else if (Instruct==RDAR)
                        next_state <= RDAR_ADDR;
                    else if (Instruct==IBL || Instruct==IBL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_LOCK;
                    end
                    else if (Instruct==IBUL || Instruct==IBUL4)
                    begin
                        if (WPS == 1'b1)
                            next_state <= IBL_UNLOCK;
                    end
                    else if (Instruct==PP || Instruct==PP4)
                    begin
                        if (WEL == 1'b1)
                            next_state <= PGM_ADDR;
                    end
                    else if (Instruct==QPP || Instruct==QPP4)
                    begin
                        if (WEL == 1'b1 && QUAD)
                            next_state <= PGM_ADDR;
                    end
                    else if (Instruct==SECRP)
                    begin
                        if (WEL == 1'b1)
                            next_state <= SEC_REG_PGM_ADDR;
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RSTEN)
                            next_state <= SFT_RST_EN;
                        else if (Instruct==EPR)
                        begin
                            if (SECT_ERS_ACT)
                                next_state <= SECT_ERS;
                            else if (HALF_BLOCK_ERS_ACT)
                                next_state <= HALF_BLOCK_ERS;
                            else if (BLOCK_ERS_ACT)
                                next_state <= BLOCK_ERS;
                        end
                    end
                end
            end

            WRR_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (data_cnt==0 &&
                    byte_cnt>0 && byte_cnt<=4)
                    begin
                        if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                        begin
                            if (WEL)
                                next_state <= WRR_NV;
                            else if (WREN_V)
                                next_state <= WRR_V;
                        end
                        else
                            next_state <= STANDBY;
                    end
                    else
                        next_state <= STANDBY;
                end
            end

            WRR_NV :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state <= STANDBY;
                        end
                    end
                end

                if (rising_edge_WDONE ||
                (rising_edge_CSNeg_d && WDONE  && !SR2V[5]))
                    next_state <= STANDBY;
            end

            WRR_V :
            begin
                if (rising_edge_WDONE)
                    next_state <= STANDBY;
            end

            WRAR_ADDR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if ((!CR2V[0] && addr_cnt==24) ||
                    (CR2V[0] && addr_cnt==32))
                        next_state <= WRAR_DATA_INPUT;
                end
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            WRAR_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (data_cnt==8)
                    begin
                        if ((Address_wrar==24'h0) || (Address_wrar==24'h2) ||
                        (Address_wrar==24'h3) || (Address_wrar==24'h4) ||
                        (Address_wrar==24'h5))
                            if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                next_state <= WRAR_NV;
                            else
                                next_state <= STANDBY;

                        if ((Address_wrar>=24'h20) && (Address_wrar<=24'h27))
                        begin
                            if (IRP[2])
                                next_state <= WRAR_NV;
                            else
                                next_state <= STANDBY;
                        end
                        if ((Address_wrar==24'h30) || (Address_wrar==24'h31))
                            next_state <= WRAR_NV;

                        if ((Address_wrar==24'h39) ||
                        (Address_wrar==24'h3A) || (Address_wrar==24'h3B))
                        begin
                            if (NVLOCK)
                                next_state <= WRAR_NV;
                            else
                                next_state <= STANDBY;
                        end

                        if ((Address_wrar==24'h800000)
                        || (Address_wrar==24'h800002) || (Address_wrar==24'h800003)
                        || (Address_wrar==24'h800005))
                        begin
                            if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                next_state <= WRAR_V;
                            else
                                next_state <= STANDBY;
                        end
                        if (Address_wrar==24'h800004)
                            next_state <= WRAR_V;
                    end
                    else
                        next_state <= STANDBY;
                end
            end

            WRAR_NV :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                        begin
                            if (Address!=24'h0 && Address!=24'h2 &&
                            Address!=24'h03 && Address!=24'h04)
                                next_state = SFT_RST_EN;
                        end
                    end
                end

                if (rising_edge_WDONE ||
                (rising_edge_CSNeg_d && WDONE && !SR2V[5]))
                    next_state <= STANDBY;
            end

            WRAR_V :
            begin
                if (rising_edge_WDONE)
                    next_state <= STANDBY;
            end

            IRP_PGM_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==0 && byte_cnt==2)
                      next_state <= IRP_PGM;
                  else
                      next_state <= STANDBY;
                end
            end

            IRP_PGM :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state = STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end
                if (rising_edge_PDONE ||
                (rising_edge_CSNeg_d && PDONE && !SR2V[5]))
                    next_state <= STANDBY;
            end

            PGM_NV_DLR_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==8 )
                      next_state <= PGM_NV_DLR;
                  else
                      next_state <= STANDBY;
                end
            end

            PGM_NV_DLR :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end

                if (rising_edge_PDONE ||
                (rising_edge_CSNeg_d && PDONE  && !SR2V[5]))
                    next_state <= STANDBY;
            end

            DLRV_WRITE_DATA :
            begin
                if (rising_edge_CSNeg_ipd)
                    next_state <= STANDBY;
            end

            SET_PNTR_PROT_ADDR :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == SPRP4 && addr_cnt == 32) ||
                    (Instruct == SPRP && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                        next_state <= SET_PNTR_PROT;
                    else
                        next_state <= STANDBY;
                end
            end

            SET_PNTR_PROT :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if ((SR2V[5]) || (SR2V[6]))
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end

                if (rising_edge_WDONE ||
                (rising_edge_CSNeg_d && WDONE && !SR2V[5]))
                    next_state <= STANDBY;
            end

            PASSP_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==0 && byte_cnt==8 )
                      next_state <= PASS_PGM;
                  else
                      next_state <= STANDBY;
                end
            end

            PASS_PGM :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end

                if (rising_edge_PDONE ||
                (rising_edge_CSNeg_d && PDONE && !SR2V[5]))
                    next_state <= STANDBY;
            end

            PASSU_DATA_INPUT :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                  if (data_cnt==0 && byte_cnt==8 )
                      next_state <= PASS_PGM;
                  else
                      next_state <= STANDBY;
                end
            end

            PASS_ULCK :
            begin
                if (rising_edge_SCK_D && !CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RDSR1)
                            next_state <= RDSR1_DATA_OUTPUT;
                        else if (Instruct==RDSR2)
                            next_state <= RDSR2_DATA_OUTPUT;
                        else if (Instruct==RDCR1)
                            next_state <= RDCR1_DATA_OUTPUT;
                        else if (Instruct==RDCR2)
                            next_state <= RDCR2_DATA_OUTPUT;
                        else if (Instruct==RDCR3)
                            next_state <= RDCR3_DATA_OUTPUT;
                        else if (Instruct==RDAR)
                            next_state <= RDAR_ADDR;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                                next_state <= STANDBY;
                        end
                        else if (Instruct==RSTEN)
                            next_state = SFT_RST_EN;
                    end
                end

                if (rising_edge_PASSULCK_out ||
                (rising_edge_CSNeg_d && PASSULCK_out  && !SR2V[5]))
                    next_state <= STANDBY;
            end

            IBL_LOCK :
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

            IBL_UNLOCK:
            begin
                if (rising_edge_CSNeg_ipd)
                begin
                    if (SR2V[0])
                        next_state <= PGMSUS;
                    else if (SR2V[1])
                        next_state <= ERSSUS;
                    else
                        next_state <= STANDBY;
                end
            end

        endcase

    end

//    /////////////////////////////////////////////////////////////////////////
//    //FSM Output generation and general functionality
//    /////////////////////////////////////////////////////////////////////////
    always @(rising_edge_PoweredUp or falling_edge_CSNeg_ipd or rising_edge_CSNeg_ipd
            or rising_edge_SCK_ipd or falling_edge_SCK_ipd or rising_edge_RES_out or
            rising_edge_PDONE or rising_edge_EDONE or rising_edge_PRGSUSP_out or
            rising_edge_ERSSUSP_out or rising_edge_QEN_out or rising_edge_QEXN_out or
            rising_edge_PASSULCK_out or rising_edge_SFT_RST_out or
            rising_edge_HW_RST_out or rising_edge_WDONE)
    begin: Functionality
    integer i,j;
        if (rising_edge_PoweredUp)
        begin
            SR1NV    = 8'h00;
            SR1V     = SR1NV;
            SR2V     = 8'h00;
            CR1NV    = 8'h00;
            if (QIO_ONLY_OPN)
                CR1NV    = 8'h02;
            CR1V    = CR1NV;
            CR2NV    = 8'h60;
            if (QPI_ONLY_OPN)
                CR2NV    = 8'h68;
            CR2V[7:1]    = CR2NV[7:1];
            CR2V[0]    = CR2NV[1];
            CR3NV    = 8'h78;
            CR3V     = CR3NV;
            IRP    = 16'hFFFD;
            if (SECURE_OPN)
                IRP    = 16'hFFFF;
            Password_reg = 64'hFFFFFFFFFFFFFFFF;
            PR = 8'h41;
            PRPR    = 32'hFFFFFFFF;
            DLRV    = 8'h00;
            DLRNV   = 8'h00;
            IBL_Sec_Prot  = {(SecNum+1){1'b0}};
            RST = 1;
        end

        if (PoweredUp)
        begin
        case (current_state)
            STANDBY :
            begin
                if (falling_edge_CSNeg_ipd || rising_edge_CSNeg_d)
                begin
                    Instruct = NONE;
                    opcode = 0;
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    DPD_ACT = 0;
                    DLP_ACT = 0;
                    RES_in = 0;
                    Address = 32'd0;
                    mode_byte = 8'b00000000;
                    data_cnt   = 0;
                    bit_cnt   = 0;
                    read_cnt  = 0;
                    byte_cnt  = 0;
                    PGM_ACT = 0;
                    PGM_SEC_REG_ACT = 0;
                    SECT_ERS_ACT = 0;
                    HALF_BLOCK_ERS_ACT = 0;
                    BLOCK_ERS_ACT = 0;
                    CHIP_ERS_ACT = 0;
                    SECT_ERS_SEC_REG_ACT = 0;
                    WRR_NV_ACT = 0;
                    WRAR_NV_ACT = 0;
                    IRP_ACT = 0;
                    DLRNV_ACT = 0;
                    SET_PNTR_PROT_ACT = 0;
                    PASS_PGM_ACT = 0;
                    PASSULCK_in = 0;
                    SR2V[0] = 0;
                    SR2V[1] = 0;
                    PRGSUSP_in = 1'b0;
                    ERSSUSP_in = 1'b0;
                    normal_rd = 0;
                    fast_rd = 1;
                    ddr_rd = 0;
                    reg_rd = 0;
                    frst_addr_nibb = 0;
                    Latency_code = CR3V[3:0];
                    if (Latency_code==0)
                        Latency_code = 8;
                    if (CR3V[6:5]==0)
                        WrapLength = 8;
                    if (CR3V[6:5]==1)
                        WrapLength = 16;
                    if (CR3V[6:5]==2)
                        WrapLength = 32;
                    if (CR3V[6:5]==3)
                        WrapLength = 64;
                end

                if (rising_edge_SCK_ipd && !CSNeg_ipd && QEN_in==1'b0
                && QEXN_in==1'b0)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end

                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        case (opcode)
                            8'b00000011 :
                                Instruct = READ; // 03h
                            8'b00010011 :
                                Instruct = READ4; // 13h
                            8'b00001011 :
                                Instruct = FAST_READ; // 0Bh
                            8'b00001100 :
                                Instruct = FAST_READ4; // 0Ch
                            8'b00111011 :
                                Instruct = DOR; // 3Bh
                            8'b00111100 :
                                Instruct = DOR4; // 3Ch
                            8'b10111011 :
                                Instruct = DIOR; // BBh
                            8'b10111100 :
                                Instruct = DIOR4; // BCh
                            8'b01101011 :
                                Instruct = QOR; // 6Bh
                            8'b01101100 :
                                Instruct = QOR4; // 6Ch
                            8'b11101011 :
                                Instruct = QIOR; // EBh
                            8'b11101100 :
                                Instruct = QIOR4; // ECh
                            8'b11101101 :
                                Instruct = DDRQIOR; // EDh
                            8'b11101110 :
                                Instruct = DDRQIOR4; // EEh
                            8'b01000001 :
                            begin
                                Instruct = DLPRD; // 41h
                                Latency_code = 1;
                            end
                            8'b00101011 :
                            begin
                                Instruct = IRPRD; // 2Bh
                                Latency_code = 1;
                            end
                            8'b00111101 :
                                Instruct = IBLRD;// 3Dh
                            8'b11100000 :
                                Instruct = IBLRD4;// E0h
                            8'b01100110 : Instruct = RSTEN; // 66h

                            8'b10011001 : Instruct = RSTCMD; // 99h

                            8'b01001000 :
                                Instruct = SECRR; // 48h
                            8'b11100111 :
                            begin
                                Instruct = PASSRD; // E7h
                                Latency_code = 1;
                            end
                            8'b10100111 :
                            begin
                                Instruct = PRRD; // A7h
                                Latency_code = 1;
                            end
                            8'b10011111 :
                                Instruct = RDID;// 9Fh
                            8'b10101111 :
                                Instruct = RDQID;// AFh
                            8'b01001011 :
                            begin
                                Instruct = RUID; // 4Bh
                                Latency_code = 32;
                            end
                            8'b01011010 :
                                Instruct = RSFDP;// 5Ah
                            8'b01110111 : Instruct = SET_BURST; // 77h
                            8'b10110111 : Instruct = BEN4; // B7h
                            8'b11101001 : Instruct = BEX4; // E9h
                            8'b00111000 : Instruct = QPIEN; // 38h
                            8'b11110101 : Instruct = QPIEX; // F5h

                            8'b00000101 :
                                Instruct = RDSR1; // 05h
                            8'b00000111 :
                                Instruct = RDSR2; // 07h
                            8'b00110101 :
                                Instruct = RDCR1; // 35h
                            8'b00010101 :
                                Instruct = RDCR2; // 15h
                            8'b00110011 :
                                Instruct = RDCR3; // 33h
                            8'b01100101 :
                                Instruct = RDAR; // 65h
                            8'b10111001 : Instruct = DEEP_PD; // B9h
                            8'b10101011 : Instruct = RES; // ABh
                            8'b00000110 : Instruct = WREN; // 06h
                            8'b01010000 : Instruct = WRENV; // 50h
                            8'b00000100 : Instruct = WRDI; // 04h
                            8'b00110000 : Instruct = CLSR; // 30h
                            8'b00000010 : Instruct = PP; // 02h
                            8'b00010010 : Instruct = PP4; // 12h
                            8'b00110010 : Instruct = QPP; // 32h
                            8'b00110100 : Instruct = QPP4; // 34h
                            8'b00100000 : Instruct = SE; // 20h
                            8'b00100001 : Instruct = SE4; // 21h
                            8'b01010010 : Instruct = HBE; // 52h
                            8'b01010011 : Instruct = HBE4; // 53h
                            8'b11011000 : Instruct = BE; // D8h
                            8'b11011100 : Instruct = BE4; // DCh
                            8'b01100000 : Instruct = CE; // 60h
                            8'b11000111 : Instruct = CE; // C7h
                            8'b00110110 : Instruct = IBL; // 36h
                            8'b11100001 : Instruct = IBL4; // E1h
                            8'b00101111 : Instruct = IRPP;
                            8'b00000001 : Instruct = WRR; // 01h
                            8'b01110001 : Instruct = WRAR; // 71h
                            8'b11101000 : Instruct = PASSP; // E8h
                            8'b01000010 : Instruct = SECRP; // 42h
                            8'b01000100 : Instruct = SECRE; // 44h
                            8'b11101010 : Instruct = PASSU; // EAh
                            8'b10100110 : Instruct = PRL; // A6h
                            8'b00111001 : Instruct = IBUL; // 39h
                            8'b11100010 : Instruct = IBUL4; // E2h
                            8'b01111110 : Instruct = GBL; // 7Eh
                            8'b10011000 : Instruct = GBUL; // 98h
                            8'b11111011 : Instruct = SPRP; // FBh
                            8'b11100011 : Instruct = SPRP4; // E3h
                            8'b01000011 : Instruct = PDLRNV; // 43h
                            8'b01001010 : Instruct = WDLRV; // 4Ah

                        endcase
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==DEEP_PD)
                            DPD_in = 1'b1;
                        else if (Instruct==BEN4)
                        begin
                            if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                CR2V[0] = 1'b1;
                        end
                        else if (Instruct==BEX4)
                        begin
                            if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                CR2V[0] = 1'b0;
                        end
                        else if (Instruct==QPIEN)
                        begin
                            if (!QPI_ONLY_OPN)
                            begin
                                if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                begin
                                    CR2V[3] = 1'b1;
                                    QEN_in = 1'b1;
                                end
                            end
                        end
                        else if (Instruct==QPIEX)
                        begin
                            if (!QPI_ONLY_OPN)
                            begin
                                if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                                begin
                                    CR2V[3] = 1'b0;
                                    QEXN_in = 1'b1;
                                end
                            end
                        end
                        else if (Instruct==WREN)
                        begin
                            SR1V[1] = 1'b1;
                            WREN_V = 1'b0;
                        end
                        else if (Instruct==WRENV)
                        begin
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b1;
                        end
                        else if (Instruct==WRDI)
                        begin
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                        end
                        else if (Instruct==CLSR)
                        begin
                            SR1V[0] = 1'b0;
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                            SR2V[5] = 1'b0;
                            SR2V[6] = 1'b0;
                        end
                        else if (Instruct==CE)
                        begin
                            if (WEL == 1'b1)
                            begin
                                SR1V[0] = 1'b1;
                                if (Sec_Prot != (0))
                                    SR2V[6] = 1'b1;
                                else
                                begin
                                    ESTART  = 1'b1;
                                    ESTART <= #5 1'b0;
                                    for (i=0;i<=AddrRANGE;i=i+1)
                                        Mem[i] = -1;
                                end
                            end
                        end
                        else if (Instruct==PRL)
                        begin
                            if (WEL)
                            begin
                                PR[0] = 1'b0;
                                PR[6] = IRP[6];
                            end
                        end
                        else if (Instruct==GBL)
                        begin
                            if (WPS)
                                IBL_Sec_Prot = {(SecNum+1){1'b0}};
                        end
                        else if (Instruct==GBUL)
                        begin
                            if (WPS)
                                IBL_Sec_Prot = {(SecNum+1){1'b1}};
                        end
                    end
                end
            end

            SFT_RST_EN :
            begin
                if (falling_edge_CSNeg_ipd)
                begin
                    Instruct = NONE;
                    opcode_cnt = 0;
                end
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        if (opcode == 8'b10011001)  // 99h (RST)
                            Instruct = RSTCMD;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==RSTCMD)
                        begin
                            SFT_RST_in = 1'b1;
                            SFT_RST_in <= #1 1'b0;
                        end
                    end
                end
            end

            RESET_STATE :
            begin
                if (rising_edge_SFT_RST_out)
                begin
                    SR1V     = SR1NV;
                    SR2V     = 8'h00;
                    CR1V[7:1]= CR1NV[7:1];
                    CR2V[7:1]= CR2NV[7:1];
                    CR2V[0]  = CR2NV[1];
                    CR3V     = CR3NV;
                    DLRV     = DLRNV;
                    PR[6]    = IRP[6];
                    if (IRP[4]) // IBL lock
                        IBL_Sec_Prot = {(SecNum+1){1'b0}};
                    else        // IBL unlock
                        IBL_Sec_Prot = {(SecNum+1){1'b1}};
                end

                if (rising_edge_HW_RST_out)
                begin
                    SR1V     = SR1NV;
                    SR2V     = 8'h00;
                    CR1V    = CR1NV;
                    CR2V[7:1]    = CR2NV[7:1];
                    CR2V[0]    = CR2NV[1];
                    CR3V     = CR3NV;
                    DLRV     = DLRNV;
                    if (IRP[4]) // IBL lock
                        IBL_Sec_Prot = {(SecNum+1){1'b0}};
                    else        // IBL unlock
                        IBL_Sec_Prot = {(SecNum+1){1'b1}};

                    if (!IRP[2]) // Password protection mode
                    begin
                        PR[0] = 1'b0;
                        PR[6] = IRP[6];
                    end
                    else if (!IRP[1])       // Power Suply Lock-Down
                    begin
                        PR[0] = 1'b1;
                        PR[6] = IRP[6];
                    end
                    else if (!IRP[0])       // Permanent protection
                    begin
                        PR[0] = 1'b0;
                        PR[6] = 1'b1;
                    end
                end
            end

            DPD :
            begin
                DPD_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                begin
                    Instruct = NONE;
                    opcode_cnt = 0;
                end
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        if (opcode == 8'b10101011)  // ABh (RES)
                            Instruct <= RES;
                    end
                    else if (opcode_cnt > 8)
                        dummy_cnt = dummy_cnt + 1;
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                        if (Instruct==RES)
                            RES_in = 1'b1;
                end
                if (rising_edge_RES_out)
                    RES_in = 1'b0;
            end

            RD_ADDR, FAST_RD_ADDR, DUALO_RD_ADDR, QUADO_RD_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if ((Instruct==READ || Instruct==FAST_READ
                    || Instruct==DOR || Instruct==QOR) && !CR2V[0])
                    begin
                        Address[23-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 1;
                    end
                    else if ((Instruct==READ4 || Instruct==FAST_READ4 ||
                    Instruct==DOR4 || Instruct==QOR4) ||
                    ((Instruct==READ || Instruct==FAST_READ ||
                    Instruct==DOR || Instruct==QOR) && CR2V[0]))
                    begin
                        Address[31-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 1;
                    end
                end
            end

            RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    normal_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_SO  = data_out[7-read_cnt];
                    end
                    else
                        DataDriveOut_SO  = 1'bx;
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (Address == AddrRANGE)
                            Address = 0;
                        else
                            Address = Address + 1;
                    end
                end
            end

            FAST_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                        if ((CLK_PER < 20000 && Latency_code == 1) || // <= 50MHz
                        (CLK_PER < 15380 && Latency_code == 2) || // <= 65MHz
                        (CLK_PER < 13330 && Latency_code == 3) || // <= 75MHz
                        (CLK_PER < 11760 && Latency_code == 4) || // <= 85MHz
                        (CLK_PER < 10520 && Latency_code == 5) || // <= 95MHz
                        (CLK_PER <  9250 && Latency_code <= 6))   // <= 108MHz
                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
            end

            FAST_RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_SO  = data_out[7-read_cnt];
                    end
                    else
                        DataDriveOut_SO  = 1'bx;
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (Address == AddrRANGE)
                            Address = 0;
                        else
                            Address = Address + 1;
                    end
                end
            end

            DUALO_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                        if ((CLK_PER < 20000 && Latency_code == 1) || // <= 50MHz
                        (CLK_PER < 15380 && Latency_code == 2) || // <= 65MHz
                        (CLK_PER < 13330 && Latency_code == 3) || // <= 75MHz
                        (CLK_PER < 11760 && Latency_code == 4) || // <= 85MHz
                        (CLK_PER < 10520 && Latency_code == 5) || // <= 95MHz
                        (CLK_PER <  9520 && Latency_code == 6) || // <= 105MHz
                        (CLK_PER <  9250 && Latency_code <= 7))  // <= 108MHz
                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
            end

            DUALO_RD_DATA, DUALIO_RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_SO  = data_out[7-read_cnt];
                        DataDriveOut_SI = data_out[6-read_cnt];
                    end
                    else
                    begin
                        DataDriveOut_SO = 1'bx;
                        DataDriveOut_SI = 1'bx;
                    end
                    read_cnt = read_cnt + 2;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (Address == AddrRANGE)
                            Address = 0;
                        else
                            Address = Address + 1;
                    end
                end
            end

            QUADO_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                        if ((CLK_PER < 28570 && Latency_code == 1) || // <= 35MHz
                        (CLK_PER < 22220 && Latency_code == 2) || // <= 45MHz
                        (CLK_PER < 18180 && Latency_code == 3) || // <= 55MHz
                        (CLK_PER < 15380 && Latency_code == 4) || // <= 65MHz
                        (CLK_PER < 13330 && Latency_code == 5) || // <= 75MHz
                        (CLK_PER < 11760 && Latency_code == 6) || // <= 85MHz
                        (CLK_PER < 10520 && Latency_code == 7) || // <= 95MHz
                        (CLK_PER < 9250  && Latency_code <= 8))  // <= 108MHz

                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
            end

            QUADO_RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                    end
                    else
                    begin
                        DataDriveOut_IO3_RESET = 1'bx;
                        DataDriveOut_WP    = 1'bx;
                        DataDriveOut_SO    = 1'bx;
                        DataDriveOut_SI    = 1'bx;
                    end
                    read_cnt = read_cnt + 4;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (Address == AddrRANGE)
                            Address = 0;
                        else
                            Address = Address + 1;
                    end
                end
            end

            DUALIO_RD_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (Instruct==DIOR && !CR2V[0])
                    begin
                        Address[23-addr_cnt] = SO_in;
                        Address[22-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 2;
                    end
                    else if (Instruct==DIOR4 ||
                    (Instruct==DIOR && CR2V[0]))
                    begin
                        Address[31-addr_cnt] = SO_in;
                        Address[30-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 2;
                    end

                    if (mode_byte[7:4]==4'b1010)
                    begin
                        if (opcode_cnt<=7)
                            // latching data for MBR instruct
                            Instruct_tmp[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                end
                // Continuous read
                if (falling_edge_CSNeg_ipd && mode_byte[7:4]==4'b1010)
                begin
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    mode_byte = 8'b00000000;
                    read_cnt = 0;
                end
            end

            DUALIO_RD_MODE :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    mode_byte[7-mode_cnt] = SO_in;
                    mode_byte[6-mode_cnt] = SI_in;
                    mode_cnt = mode_cnt + 2;
                end
            end

            DUALIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                        if ((CLK_PER < 13330 && Latency_code == 1) || // <= 75MHz
                        (CLK_PER < 11760 && Latency_code == 2) ||     // <= 85MHz
                        (CLK_PER < 10520 && Latency_code == 3) ||     // <= 95MHz
                        (CLK_PER < 9250 && Latency_code <= 4))       // <= 108MHz
                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
            end

            QUADIO_RD_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (Instruct==QIOR && !CR2V[0])
                    begin
                        Address[23-addr_cnt] = IO3_RESETNeg_in;
                        Address[22-addr_cnt] = WPNeg_in;
                        Address[21-addr_cnt] = SO_in;
                        Address[20-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 4;
                    end
                    else if (Instruct==QIOR4 ||
                    (Instruct==QIOR && CR2V[0]))
                    begin
                        Address[31-addr_cnt] = IO3_RESETNeg_in;
                        Address[30-addr_cnt] = WPNeg_in;
                        Address[29-addr_cnt] = SO_in;
                        Address[28-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 4;
                    end

                    if (mode_byte[7:4]==4'b1010)
                    begin
                        if (opcode_cnt<=7)
                            // latching data for MBR instruct
                            Instruct_tmp[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                end
                if (falling_edge_CSNeg_ipd && mode_byte[7:4]==4'b1010)
                begin
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    mode_byte = 8'b00000000;
                    read_cnt = 0;
                end
            end

            QUADIO_RD_MODE :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    mode_byte[7-mode_cnt] = IO3_RESETNeg_in;
                    mode_byte[6-mode_cnt] = WPNeg_in;
                    mode_byte[5-mode_cnt] = SO_in;
                    mode_byte[4-mode_cnt] = SI_in;
                    mode_cnt = mode_cnt + 4;
                end
            end

            QUADIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                        if ((CLK_PER < 28570 && Latency_code == 1) || // <= 35MHz
                        (CLK_PER < 22220 && Latency_code == 2) || // <= 45MHz
                        (CLK_PER < 18180 && Latency_code == 3) || // <= 55MHz
                        (CLK_PER < 15380 && Latency_code == 4) || // <= 65MHz
                        (CLK_PER < 13330 && Latency_code == 5) || // <= 75MHz
                        (CLK_PER < 11760 && Latency_code == 6) || // <= 85MHz
                        (CLK_PER < 10520 && Latency_code == 7) || // <= 95MHz
                        (CLK_PER < 9250  && Latency_code <= 8))  // <= 108MHz
                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
            end

           QUADIO_RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                    end
                    else
                    begin
                        DataDriveOut_IO3_RESET = 1'bx;
                        DataDriveOut_WP    = 1'bx;
                        DataDriveOut_SO    = 1'bx;
                        DataDriveOut_SI    = 1'bx;
                    end
                    read_cnt = read_cnt + 4;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (CR3V[4]) // disable burst wrap read
                        begin
                            if (Address == AddrRANGE)
                                Address = 0;
                            else
                                Address = Address + 1;
                        end
                        else if (!CR3V[4]) // enable burst wrap read
                        begin
                            Address = Address + 1;
                            if (Address % WrapLength == 0)
                                Address = Address - WrapLength;
                        end
                    end
                end
            end

            DDRQUADIO_RD_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (Instruct==DDRQIOR && !CR2V[0])
                    begin
                        Address[23-addr_cnt] = IO3_RESETNeg_in;
                        Address[22-addr_cnt] = WPNeg_in;
                        Address[21-addr_cnt] = SO_in;
                        Address[20-addr_cnt] = SI_in;
                    end
                    else if (Instruct==DDRQIOR4 ||
                    (Instruct==DDRQIOR && CR2V[0]))
                    begin
                        Address[31-addr_cnt] = IO3_RESETNeg_in;
                        Address[30-addr_cnt] = WPNeg_in;
                        Address[29-addr_cnt] = SO_in;
                        Address[28-addr_cnt] = SI_in;
                    end

                    if (mode_byte[7:4]==~mode_byte[3:0])
                    begin
                        if (opcode_cnt<=7)
                            // latching data for MBR instruct
                            Instruct_tmp[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    frst_addr_nibb = 1'b1;
                end

                if (falling_edge_SCK_ipd && !CSNeg_ipd && frst_addr_nibb)
                begin
                    if (Instruct==DDRQIOR && !CR2V[0])
                    begin
                        Address[19-addr_cnt] = IO3_RESETNeg_in;
                        Address[18-addr_cnt] = WPNeg_in;
                        Address[17-addr_cnt] = SO_in;
                        Address[16-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 8;
                    end
                    else if (Instruct==DDRQIOR4 ||
                    (Instruct==DDRQIOR && CR2V[0]))
                    begin
                        Address[27-addr_cnt] = IO3_RESETNeg_in;
                        Address[26-addr_cnt] = WPNeg_in;
                        Address[25-addr_cnt] = SO_in;
                        Address[24-addr_cnt] = SI_in;
                        addr_cnt = addr_cnt + 8;
                    end
                end
                if (falling_edge_CSNeg_ipd)
                begin
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    mode_byte = 8'b00000000;
                    read_cnt = 0;
                    frst_addr_nibb = 1'b0;
                end
            end

            DDRQUADIO_RD_MODE :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    mode_byte[7] = IO3_RESETNeg_in;
                    mode_byte[6] = WPNeg_in;
                    mode_byte[5] = SO_in;
                    mode_byte[4] = SI_in;
                end
                if (falling_edge_SCK_ipd && !CSNeg_ipd )
                begin
                    mode_byte[3] = IO3_RESETNeg_in;
                    mode_byte[2] = WPNeg_in;
                    mode_byte[1] = SO_in;
                    mode_byte[0] = SI_in;
                    mode_cnt = mode_cnt + 8;

                    if (((2*Latency_code)-dummy_cnt==8) && (DLRV!=8'd0))
                        DLP_ACT = 1'b1;
                    if (DLP_ACT)
                    begin
                        DataDriveOut_IO3_RESET = DLRV[7-read_cnt];
                        DataDriveOut_WP    = DLRV[7-read_cnt];
                        DataDriveOut_SO    = DLRV[7-read_cnt];
                        DataDriveOut_SI    = DLRV[7-read_cnt];
                        read_cnt = read_cnt + 1;
                    end
                    dummy_cnt = dummy_cnt + 1;
                end
            end

            DDRQUADIO_RD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (DLP_ACT)
                    begin
                        DataDriveOut_IO3_RESET = DLRV[7-read_cnt];
                        DataDriveOut_WP    = DLRV[7-read_cnt];
                        DataDriveOut_SO    = DLRV[7-read_cnt];
                        DataDriveOut_SI    = DLRV[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            DLP_ACT = 1'b0;
                        end
                    end

                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == 2*Latency_code)
                        if ((CLK_PER < 50000 && Latency_code == 1) || // <= 20MHz
                        (CLK_PER < 40000 && Latency_code == 2) || // <= 25MHz
                        (CLK_PER < 28570 && Latency_code == 3) || // <= 35MHz
                        (CLK_PER < 22220 && Latency_code == 4) || // <= 45MHz
                        (CLK_PER < 18180 && Latency_code <= 5)) // <= 54MHz
                        begin
                            $display ("More wait states are required for");
                            $display ("this clock frequency value");
                        end
                end
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (((2*Latency_code) - dummy_cnt==8) && (DLRV != 8'd0))
                        DLP_ACT = 1'b1;
                    if (DLP_ACT)
                    begin
                        DataDriveOut_IO3_RESET = DLRV[7-read_cnt];
                        DataDriveOut_WP    = DLRV[7-read_cnt];
                        DataDriveOut_SO    = DLRV[7-read_cnt];
                        DataDriveOut_SI    = DLRV[7-read_cnt];
                        read_cnt = read_cnt + 1;
                    end
                    dummy_cnt = dummy_cnt + 1;
                end
            end

            DDRQUADIO_RD_DATA :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    ddr_rd = 1'b1;
                    if (!(SR2V[0] && pgm_page==Address/(PageSize+1)) &&
                    !(SR2V[1] && SECT_ERS_ACT && SectorErase==Address/(SecSize+1)) &&
                    !(SR2V[1] && HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) &&
                    !(SR2V[1] && BLOCK_ERS_ACT && BlockErase==Address/(BlockSize+1)) &&
                    (Mem[Address] !== -1))
                    begin
                        data_out[7:0] = Mem[Address];
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                    end
                    else
                    begin
                        DataDriveOut_IO3_RESET = 1'bx;
                        DataDriveOut_WP    = 1'bx;
                        DataDriveOut_SO    = 1'bx;
                        DataDriveOut_SI    = 1'bx;
                    end
                    read_cnt = read_cnt + 4;
                end
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                    DataDriveOut_WP    = data_out[6-read_cnt];
                    DataDriveOut_SO    = data_out[5-read_cnt];
                    DataDriveOut_SI    = data_out[4-read_cnt];
                    read_cnt = read_cnt + 4;
                    if (read_cnt == 8)
                    begin
                        read_cnt = 0;
                        if (CR3V[4]) // disable burst wrap read
                        begin
                            if (Address == AddrRANGE)
                                Address = 0;
                            else
                                Address = Address + 1;
                        end
                        else if (!CR3V[4]) // enable burst wrap read
                        begin
                            Address = Address + 1;
                            if (Address % WrapLength == 0)
                                Address = Address - WrapLength;
                        end
                    end
                end
            end

            RDAR_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end

                // embedded operation finished during Read Any Register operation
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDAR_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                    begin
                        if (QPI)
                        begin
                            if ((CLK_PER < 66600 && Latency_code == 1) || // <= 15MHz
                            (CLK_PER < 40000 && Latency_code == 2) || // <= 25MHz
                            (CLK_PER < 28570 && Latency_code == 3) || // <= 35MHz
                            (CLK_PER < 22220 && Latency_code == 4) || // <= 45MHz
                            (CLK_PER < 18180 && Latency_code == 5) || // <= 55MHz
                            (CLK_PER < 15380 && Latency_code == 6) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 7) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 8) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 9) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 10))  // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                        else
                        begin
                            if ((CLK_PER < 20000 && Latency_code == 1) || // <= 50MHz
                            (CLK_PER < 15380 && Latency_code == 2) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 3) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 4) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 5) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 6))    // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                    end
                end

                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDAR_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    READ_ALL_REG(Address, RDAR_reg);
                    data_out[7:0]  = RDAR_reg;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else
                    begin
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDSR1_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    data_out[7:0]  = SR1V;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else
                    begin
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDSR2_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    data_out[7:0]  = SR2V;
                    DataDriveOut_SO = data_out[7-read_cnt];
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                        read_cnt = 0;
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDCR1_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    data_out[7:0]  = CR1V;
                    DataDriveOut_SO = data_out[7-read_cnt];
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                        read_cnt = 0;
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDCR2_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    data_out[7:0]  = CR2V;
                    DataDriveOut_SO = data_out[7-read_cnt];
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                        read_cnt = 0;
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            RDCR3_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    data_out[7:0]  = CR3V;
                    DataDriveOut_SO = data_out[7-read_cnt];
                    read_cnt = read_cnt + 1;
                    if (read_cnt == 8)
                        read_cnt = 0;
                end
                // embedded operation finished during status read
                if (rising_edge_PDONE)
                begin
                    if (PGM_ACT)
                        EndProgramming;
                    else if (PGM_SEC_REG_ACT)
                        EndSECRProgramming;
                    else if (IRP_ACT)
                        EndIRPP;
                    else if (DLRNV_ACT)
                    begin
                        SR1V[0] = 1'b0;
                        SR1V[1] = 1'b0;
                        DLRNV = DLRNV_in;
                        DLRV = DLRNV;
                        DLRNV_ACT = 1'b0;
                        DLRNV_programmed = 1'b1;
                    end
                    else if (PASS_PGM_ACT)
                        EndPassProgramming;
                end
                if (rising_edge_EDONE)
                begin
                    if (SECT_ERS_ACT)
                        EndSecErasing;
                    else if (HALF_BLOCK_ERS_ACT)
                        EndHalfBlockErasing;
                    else if (BLOCK_ERS_ACT)
                        EndBlockErasing;
                    else if (CHIP_ERS_ACT)
                        EndChipErasing;
                    else if (SECT_ERS_SEC_REG_ACT)
                        EndSECRErasing;
                end
                if (rising_edge_WDONE)
                begin
                    if (WRR_NV_ACT)
                        EndWRR_NV;
                    else if (WRAR_NV_ACT)
                        EndWRAR_NV;
                    else if (SET_PNTR_PROT_ACT)
                        EndSPRP;
                end
            end

            DLPRD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                    dummy_cnt = dummy_cnt + 1;
            end

            DLPRD_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    data_out[7:0]  = DLRV;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP    = data_out[6-read_cnt];
                        DataDriveOut_SO    = data_out[5-read_cnt];
                        DataDriveOut_SI    = data_out[4-read_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else
                    begin
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end

            IRPRD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                    dummy_cnt = dummy_cnt + 1;
            end

            IRPRD_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = IRP[7-read_cnt+8*byte_cnt];
                        DataDriveOut_WP        = IRP[6-read_cnt+8*byte_cnt];
                        DataDriveOut_SO        = IRP[5-read_cnt+8*byte_cnt];
                        DataDriveOut_SI        = IRP[4-read_cnt+8*byte_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            byte_cnt = byte_cnt+1;
                            if (byte_cnt==2)
                                byte_cnt=0;
                        end
                    end
                    else
                    begin
                        DataDriveOut_SO = IRP[7-read_cnt+8*byte_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            byte_cnt = byte_cnt+1;
                            if (byte_cnt==2)
                                byte_cnt=0;
                        end
                    end
                end
            end

            IBLRD_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct==IBLRD && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if ((Instruct==IBLRD4) || (Instruct==IBLRD && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct==IBLRD && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if ((Instruct==IBLRD4) || (Instruct==IBLRD && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            IBLRD_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    sec = Address/(SecSize+1);
                    if (!IBL_Sec_Prot[sec])
                        IBLAR = 8'h00;
                    else if (IBL_Sec_Prot[sec])
                        IBLAR = 8'hFF;
                    data_out = IBLAR;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP        = data_out[6-read_cnt];
                        DataDriveOut_SO        = data_out[5-read_cnt];
                        DataDriveOut_SI        = data_out[4-read_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else
                    begin
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end

            SECRR_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            SECRR_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                    begin
                        if (QPI)
                        begin
                            if ((CLK_PER < 66600 && Latency_code == 1) || // <= 15MHz
                            (CLK_PER < 40000 && Latency_code == 2) || // <= 25MHz
                            (CLK_PER < 28570 && Latency_code == 3) || // <= 35MHz
                            (CLK_PER < 22220 && Latency_code == 4) || // <= 45MHz
                            (CLK_PER < 18180 && Latency_code == 5) || // <= 55MHz
                            (CLK_PER < 15380 && Latency_code == 6) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 7) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 8) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 9) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 10)) // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                        else
                        begin
                            if ((CLK_PER < 20000 && Latency_code == 1) || // <= 50MHz
                            (CLK_PER < 15380 && Latency_code == 2) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 3) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 4) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 5) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 6))    // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                    end
                end
            end

            SECRR_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (Address/(SECRHiAddr+1)==0)
                    begin
                        data_out[7:0] = SECRMem[Address];
                        if (QPI)
                        begin
                            if (!(Address/(SecRegSize+1)==3
                            && SECRRP==1'b0 && NVLOCK==1'b0))
                            begin
                                DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                                DataDriveOut_WP    = data_out[6-read_cnt];
                                DataDriveOut_SO    = data_out[5-read_cnt];
                                DataDriveOut_SI    = data_out[4-read_cnt];
                                read_cnt = read_cnt + 4;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (Address < SECRHiAddr) // 1023
                                        Address = Address + 1;
                                end
                            end
                            else
                            begin
                            // Security Region 3 Read Password Protected
                                DataDriveOut_IO3_RESET = 1'bx;
                                DataDriveOut_WP        = 1'bx;
                                DataDriveOut_SO        = 1'bx;
                                DataDriveOut_SI        = 1'bx;
                            end

                        end
                        else
                        begin
                            if (!(Address/(SecRegSize+1)==3
                            && SECRRP==1'b0 && NVLOCK==1'b0))
                            begin
                                DataDriveOut_SO = data_out[7-read_cnt];
                                read_cnt = read_cnt + 1;
                                if (read_cnt == 8)
                                begin
                                    read_cnt = 0;
                                    if (Address < SECRHiAddr)  // 1023
                                        Address = Address + 1;
                                end
                            end
                            else
                            // Security Region 3 Read Password Protected
                                DataDriveOut_SO        = 1'bx;
                        end
                    end
                end
            end

            PASSRD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                    dummy_cnt = dummy_cnt + 1;
            end

            PASSRD_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = Password_reg[7-read_cnt+8*byte_cnt];
                        DataDriveOut_WP        = Password_reg[6-read_cnt+8*byte_cnt];
                        DataDriveOut_SO        = Password_reg[5-read_cnt+8*byte_cnt];
                        DataDriveOut_SI        = Password_reg[4-read_cnt+8*byte_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            byte_cnt = byte_cnt+1;
                            if (byte_cnt==8)
                                byte_cnt=0;
                        end
                    end
                    else
                    begin
                        DataDriveOut_SO = Password_reg[7-read_cnt+8*byte_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            byte_cnt = byte_cnt+1;
                            if (byte_cnt==8)
                                byte_cnt=0;
                        end
                    end
                end
            end

            PRRD_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                    dummy_cnt = dummy_cnt + 1;
            end

            PRRD_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    data_out = PR;
                    if (QPI)
                    begin
                        DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                        DataDriveOut_WP        = data_out[6-read_cnt];
                        DataDriveOut_SO        = data_out[5-read_cnt];
                        DataDriveOut_SI        = data_out[4-read_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                    else
                    begin
                        DataDriveOut_SO = data_out[7-read_cnt];
                        read_cnt = read_cnt + 1;
                        if (read_cnt == 8)
                            read_cnt = 0;
                    end
                end
            end

            RDID_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    if (QPI)
                    begin
                        if (byte_cnt < 3)
                        begin
                            DataDriveOut_IO3_RESET = ManufIDDeviceID[8*byte_cnt + 7-read_cnt];
                            DataDriveOut_WP        = ManufIDDeviceID[8*byte_cnt + 6-read_cnt];
                            DataDriveOut_SO        = ManufIDDeviceID[8*byte_cnt + 5-read_cnt];
                            DataDriveOut_SI        = ManufIDDeviceID[8*byte_cnt + 4-read_cnt];
                            read_cnt = read_cnt + 4;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                byte_cnt = byte_cnt+1;
                            end
                        end
                        else
                        begin
                            DataDriveOut_IO3_RESET = 1'bx;
                            DataDriveOut_WP        = 1'bx;
                            DataDriveOut_SO        = 1'bx;
                            DataDriveOut_SI        = 1'bx;
                        end
                    end
                    else
                    begin
                        if (byte_cnt < 3)
                        begin
                            DataDriveOut_SO = ManufIDDeviceID[8*byte_cnt + 7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                byte_cnt = byte_cnt+1;
                            end
                        end
                        else
                            DataDriveOut_SO = 1'bx;
                    end
                end
            end

            RDQID_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    reg_rd = 1'b1;
                    if (byte_cnt < 3)
                    begin
                        DataDriveOut_IO3_RESET = ManufIDDeviceID[7-read_cnt+8*byte_cnt];
                        DataDriveOut_WP        = ManufIDDeviceID[6-read_cnt+8*byte_cnt];
                        DataDriveOut_SO        = ManufIDDeviceID[5-read_cnt+8*byte_cnt];
                        DataDriveOut_SI        = ManufIDDeviceID[4-read_cnt+8*byte_cnt];
                        read_cnt = read_cnt + 4;
                        if (read_cnt == 8)
                        begin
                            read_cnt = 0;
                            byte_cnt = byte_cnt+1;
                        end
                    end
                    else
                    begin
                        DataDriveOut_IO3_RESET = 1'bx;
                        DataDriveOut_WP        = 1'bx;
                        DataDriveOut_SO        = 1'bx;
                        DataDriveOut_SI        = 1'bx;
                    end

                end
            end

            RUID_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                    dummy_cnt = dummy_cnt + 1;
            end

            RUID_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (QPI)
                    begin
                        if (read_cnt < 64)
                        begin
                            DataDriveOut_IO3_RESET = UID[63-read_cnt];
                            DataDriveOut_WP        = UID[62-read_cnt];
                            DataDriveOut_SO        = UID[61-read_cnt];
                            DataDriveOut_SI        = UID[60-read_cnt];
                            read_cnt = read_cnt + 4;
                        end
                        else
                        begin
                            DataDriveOut_IO3_RESET = 1'bx;
                            DataDriveOut_WP        = 1'bx;
                            DataDriveOut_SO        = 1'bx;
                            DataDriveOut_SI        = 1'bx;
                        end
                    end
                    else
                    begin
                        if (read_cnt < 64)
                        begin
                            DataDriveOut_SO = UID[63-read_cnt];
                            read_cnt = read_cnt + 1;
                        end
                        else
                            DataDriveOut_SO = 1'bx;
                    end
                end
            end

            RSFDP_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            RSFDP_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                    if (dummy_cnt == Latency_code)
                    begin
                        if (QPI)
                        begin
                            if ((CLK_PER < 66600 && Latency_code == 1) || // <= 15MHz
                            (CLK_PER < 40000 && Latency_code == 2) || // <= 25MHz
                            (CLK_PER < 28570 && Latency_code == 3) || // <= 35MHz
                            (CLK_PER < 22220 && Latency_code == 4) || // <= 45MHz
                            (CLK_PER < 18180 && Latency_code == 5) || // <= 55MHz
                            (CLK_PER < 15380 && Latency_code == 6) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 7) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 8) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 9) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 10))  // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                        else
                        begin
                            if ((CLK_PER < 20000 && Latency_code == 1) || // <= 50MHz
                            (CLK_PER < 15380 && Latency_code == 2) || // <= 65MHz
                            (CLK_PER < 13330 && Latency_code == 3) || // <= 75MHz
                            (CLK_PER < 11760 && Latency_code == 4) || // <= 85MHz
                            (CLK_PER < 10520 && Latency_code == 5) || // <= 95MHz
                            (CLK_PER < 9250 && Latency_code <= 8))    // <= 108MHz
                            begin
                                $display ("More wait states are required for");
                                $display ("this clock frequency value");
                            end
                        end
                    end
                end
            end

            RSFDP_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (Address<=SFDPHiAddr)
                    begin
                        data_out[7:0] = SFDP_array[Address];
                        if (QPI)
                        begin
                            DataDriveOut_IO3_RESET = data_out[7-read_cnt];
                            DataDriveOut_WP    = data_out[6-read_cnt];
                            DataDriveOut_SO    = data_out[5-read_cnt];
                            DataDriveOut_SI    = data_out[4-read_cnt];
                            read_cnt = read_cnt + 4;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                Address = Address + 1;
                            end
                        end
                        else
                        begin
                            DataDriveOut_SO = data_out[7-read_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                Address = Address + 1;
                            end
                        end
                    end
                end
            end

            SET_BURST_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI || QUAD)
                    begin
                        data_cnt = data_cnt +1;
                        if (data_cnt == 7)
                        begin
                            WL6 = WPNeg_in;
                            WL5 = SO_in;
                            WL4 = SI_in;
                        end
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==8)
                    CR3V[6:4] = {WL6, WL5, WL4};
            end

            RDP_DUMMY :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    dummy_cnt = dummy_cnt + 1;
                end
            end

            RDP_DATA_OUTPUT :
            begin
                if (falling_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    fast_rd = 1'b1;
                    if (QPI)
                    begin
                        if (byte_cnt < 2)
                        begin
                            DataDriveOut_IO3_RESET = DeviceID[7-read_cnt+8*byte_cnt];
                            DataDriveOut_WP        = DeviceID[6-read_cnt+8*byte_cnt];
                            DataDriveOut_SO        = DeviceID[5-read_cnt+8*byte_cnt];
                            DataDriveOut_SI        = DeviceID[4-read_cnt+8*byte_cnt];
                            read_cnt = read_cnt + 4;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                byte_cnt = byte_cnt+1;
                            end
                        end
                        else
                        begin
                            DataDriveOut_IO3_RESET = 1'bx;
                            DataDriveOut_WP        = 1'bx;
                            DataDriveOut_SO        = 1'bx;
                            DataDriveOut_SI        = 1'bx;
                        end
                    end
                    else
                    begin
                        if (byte_cnt < 2)
                        begin
                            DataDriveOut_SO = DeviceID[7-read_cnt+8*byte_cnt];
                            read_cnt = read_cnt + 1;
                            if (read_cnt == 8)
                            begin
                                read_cnt = 0;
                                byte_cnt = byte_cnt+1;
                            end
                        end
                        else
                            DataDriveOut_SO = 1'bx;
                    end
                end

                if (rising_edge_CSNeg_ipd && DPD_ACT)
                    RES_in = 1'b1;
            end

            PGM_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct==PP && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct==PP4 ||
                        (Instruct==PP && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if ((Instruct==PP || Instruct==QPP) && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct==PP4 || Instruct==QPP4 ||
                        ((Instruct==PP || Instruct==QPP) && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            PGM_DATAIN :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (byte_cnt > PageSize)
                    begin
                    //If more than PageSize+1 bytes
                    //are sent to the device previously latched data
                    //are discarded and last 256 data bytes are
                    //guaranteed to be programmed correctly within
                    //the same page.
                        for(i=0;i<=PageSize-1;i=i+1)
                        begin
                            Data_in[i] = Data_in[i+1];
                        end
                        byte_cnt = 255;
                    end
                    if (QPI || Instruct==QPP || Instruct==QPP4)
                    begin
                        Data_in[byte_cnt][7-data_cnt] = IO3_RESETNeg_in;
                        Data_in[byte_cnt][6-data_cnt] = WPNeg_in;
                        Data_in[byte_cnt][5-data_cnt] = SO_in;
                        Data_in[byte_cnt][4-data_cnt] = SI_in;
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        Data_in[byte_cnt][7-data_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==0 && byte_cnt>0)

                begin
                    SR1V[0] = 1'b1; // WIP
                    pgm_page = Address / (PageSize+1);
                    if (Sec_Prot[Address/(SecSize+1)] || (SR2V[1] &&
                    ( (SECT_ERS_ACT &&
                    SectorErase==Address/(SecSize+1)) ||
                    (HALF_BLOCK_ERS_ACT &&
                    HalfBlockErase==Address/(HalfBlockSize+1)) ||
                    (BLOCK_ERS_ACT &&
                    BlockErase==Address/(BlockSize+1)) )))
                        SR2V[5] = 1'b1; // P_ERR; attempt programming in protected area or
                                        // suspended sector/half_block/block
                    else
                    begin
                        for(i=0;i<=PageSize;i=i+1)
                        begin
                            Byte_slv = Data_in[i];
                            WByte[i] =  Byte_slv;
                        end

                        PSTART  = 1'b1;
                        PSTART <= #5 1'b0;
                        Addr    = Address;
                        Addr_tmp= Address;
                        wr_cnt  = byte_cnt - 1;
                        for (i=wr_cnt;i>=0;i=i-1)
                        begin
                            if (Viol != 0)
                                WData[i] = -1;
                            else
                                WData[i] = WByte[i];
                        end

                        AddrLOW = (Addr/(PageSize + 1))*(PageSize + 1);
                        AddrHIGH = AddrLOW + PageSize;
                        cnt = 0;

                        for (i=0;i<=wr_cnt;i=i+1)
                        begin
                            new_int = WData[i];
                            old_int = Mem[Addr + i - cnt];
                            if (new_int > -1)
                            begin
                                new_bit = new_int;
                                if (old_int > -1)
                                begin
                                    old_bit = old_int;
                                    for(j=0;j<=7;j=j+1)
                                    begin
                                        if (~old_bit[j])
                                            new_bit[j]=1'b0;
                                    end
                                    new_int=new_bit;
                                end
                                WData[i]= new_int;
                            end
                            else
                            begin
                                WData[i] = -1;
                            end

                            Mem[Addr + i - cnt] = - 1;
                            if ((Addr + i) == AddrHIGH)
                            begin
                                Addr = AddrLOW;
                                cnt = i + 1;
                            end
                        end
                    end
                end
            end

            PGM :
            begin
                PGM_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b01110101)
                            Instruct = EPS; // 75h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==EPS && !PRGSUSP_in && !SR2V[1]
                        && !SR2V[5])
                        begin
                            if (~RES_TO_SUSP_TIME)
                                PRGSUSP_in <= 1'b1;
                        end
                        else if (Instruct==CLSR)
                        begin
                            if (SR2V[5]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_PRGSUSP_out)
                begin
                    SR1V[0] = 1'b0;
                    SR2V[0] = 1'b1;
                    PGSUSP = 1'b1;
                    PGSUSP <= #5 1'b0;
                    PRGSUSP_in <= 1'b0;
                end
                if (rising_edge_PDONE)
                  EndProgramming;
            end

            SECT_ERS_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == SE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct == SE4 || (Instruct == SE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == SE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct == SE4 || (Instruct == SE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == SE4 && addr_cnt == 32) ||
                    (Instruct == SE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        SR1V[0] = 1'b1; // WIP
                        SECT_ERS_ACT = 1'b1;
                        SectorErase = Address/(SecSize+1);
                        if (Sec_Prot[SectorErase])
                            SR2V[6] = 1'b1; // E_ERR
                        else
                        begin
                            ESTART  = 1'b1;
                            ESTART <= #5 1'b0;
                            AddrLOW  = SectorErase*(SecSize+1);
                            AddrHIGH = AddrLOW + SecSize;
                            for (i=AddrLOW;i<=AddrHIGH;i=i+1)
                                Mem[i] = -1;
                        end
                    end
                end
            end

            HALF_BLOCK_ERS_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == HBE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct == HBE4 || (Instruct == HBE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == HBE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct == HBE4 || (Instruct == HBE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == HBE4 && addr_cnt == 32) ||
                    (Instruct == HBE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        SR1V[0] = 1'b1; // WIP
                        HALF_BLOCK_ERS_ACT = 1'b1;
                        HalfBlockErase = Address/(HalfBlockSize+1);
                        if (HalfBlock_Prot[HalfBlockErase])
                            SR2V[6] = 1'b1; // E_ERR
                        else
                        begin
                            ESTART  = 1'b1;
                            ESTART <= #5 1'b0;
                            AddrLOW  = HalfBlockErase*(HalfBlockSize+1);
                            AddrHIGH = AddrLOW + HalfBlockSize;
                            for (i=AddrLOW;i<=AddrHIGH;i=i+1)
                                Mem[i] = -1;
                        end
                    end
                end
            end

            BLOCK_ERS_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == BE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct == BE4 || (Instruct == BE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == BE && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct == BE4 || (Instruct == BE && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == BE4 && addr_cnt == 32) ||
                    (Instruct == BE && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        SR1V[0] = 1'b1; // WIP
                        BLOCK_ERS_ACT = 1'b1;
                        BlockErase = Address/(BlockSize+1);
                        if (Block_Prot[BlockErase])
                            SR2V[6] = 1'b1; // E_ERR
                        else
                        begin
                            BLOCK_ERS_ACT = 1'b1;
                            ESTART  = 1'b1;
                            ESTART <= #5 1'b0;
                            AddrLOW  = BlockErase*(BlockSize+1);
                            AddrHIGH = AddrLOW + BlockSize;
                            for (i=AddrLOW;i<=AddrHIGH;i=i+1)
                                Mem[i] = -1;
                        end
                    end
                end
            end

            SECT_ERS :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b01110101)
                            Instruct = EPS; // 75h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==EPS && !ERSSUSP_in
                        && !SR2V[6])
                        begin
                            if (~RES_TO_SUSP_TIME)
                                ERSSUSP_in <= 1'b1;
                        end
                        else if (Instruct==CLSR)
                        begin
                            if (SR2V[6]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_ERSSUSP_out)
                begin
                    SR1V[0] = 1'b0;
                    SR2V[1] = 1'b1;
                    ESUSP = 1'b1;
                    ESUSP <= #5 1'b0;
                    ERSSUSP_in <= 1'b0;
                end

                if (rising_edge_EDONE)
                    EndSecErasing;
            end

            HALF_BLOCK_ERS :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b01110101)
                            Instruct = EPS; // 75h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==EPS && !ERSSUSP_in
                        && !SR2V[6])
                        begin
                            if (~RES_TO_SUSP_TIME)
                                ERSSUSP_in <= 1'b1;
                        end
                        else if (Instruct==CLSR)
                        begin
                            if (SR2V[6]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_ERSSUSP_out)
                begin
                    SR1V[0] = 1'b0;
                    SR2V[1] = 1'b1;
                    ESUSP = 1'b1;
                    ESUSP <= #5 1'b0;
                    ERSSUSP_in <= 1'b0;
                end

                if (rising_edge_EDONE)
                    EndHalfBlockErasing;
            end

            BLOCK_ERS :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b01110101)
                            Instruct = EPS; // 75h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==EPS && !ERSSUSP_in
                        && !SR2V[6])
                        begin
                            if (~RES_TO_SUSP_TIME)
                                ERSSUSP_in <= 1'b1;
                        end
                        else if (Instruct==CLSR)
                        begin
                            if (SR2V[6]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_ERSSUSP_out)
                begin
                    SR1V[0] = 1'b0;
                    SR2V[1] = 1'b1;
                    ESUSP = 1'b1;
                    ESUSP <= #5 1'b0;
                    ERSSUSP_in <= 1'b0;
                end

                if (rising_edge_EDONE)
                    EndBlockErasing;
            end

            CHIP_ERS:
            begin
                CHIP_ERS_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[6]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end
                if (rising_edge_EDONE)
                    EndChipErasing;
            end

            SEC_REG_PGM_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            SEC_REG_PGM_DATAIN :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (byte_cnt > PageSize)
                    begin
                    //If more than PageSize+1 bytes
                    //are sent to the device previously latched data
                    //are discarded and last 256 data bytes are
                    //guaranteed to be programmed correctly within
                    //the same page.
                        for(i=0;i<=PageSize-1;i=i+1)
                        begin
                            Data_in[i] = Data_in[i+1];
                        end
                        byte_cnt = 255;
                    end
                    if (QPI)
                    begin
                        Data_in[byte_cnt][7-data_cnt] = IO3_RESETNeg_in;
                        Data_in[byte_cnt][6-data_cnt] = WPNeg_in;
                        Data_in[byte_cnt][5-data_cnt] = SO_in;
                        Data_in[byte_cnt][4-data_cnt] = SI_in;
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        Data_in[byte_cnt][7-data_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==0 && byte_cnt>0 &&
                (Address/(SECRHiAddr+1)==0))
                begin
                    SR1V[0] = 1'b1; // WIP
                    sec_region = Address/(SecRegSize+1);
                    // sec region write protected or locked by the CR1 LB
                    if ((!NVLOCK && (sec_region==2 || sec_region==3)) ||
                    (sec_region==0 && LB0) ||
                    (sec_region==1 && LB1) || (sec_region==2 && LB2) ||
                    (sec_region==3 && LB3))
                        SR2V[5] = 1'b1; // P_ERR
                    else
                    begin
                        for(i=0;i<=PageSize;i=i+1)
                        begin
                            Byte_slv = Data_in[i];
                            WByte[i] = Byte_slv;
                        end

                        PSTART  = 1'b1;
                        PSTART <= #5 1'b0;
                        Addr    = Address;
                        Addr_tmp= Address;
                        wr_cnt  = byte_cnt - 1;
                        for (i=wr_cnt;i>=0;i=i-1)
                        begin
                            if (Viol != 0)
                                WData[i] = -1;
                            else
                                WData[i] = WByte[i];
                        end
                        AddrLOW = (Addr/(PageSize + 1))*(PageSize + 1);
                        AddrHIGH = AddrLOW + PageSize;
                        cnt = 0;
                        for (i=0;i<=wr_cnt;i=i+1)
                        begin
                            new_int = WData[i];
                            old_int = SECRMem[Addr + i - cnt];
                            if (new_int > -1)
                            begin
                                new_bit = new_int;
                                if (old_int > -1)
                                begin
                                    old_bit = old_int;
                                    for(j=0;j<=7;j=j+1)
                                    begin
                                        if (~old_bit[j])
                                            new_bit[j]=1'b0;
                                    end
                                    new_int=new_bit;
                                end
                                WData[i]= new_int;
                            end
                            else
                            begin
                                WData[i] = -1;
                            end

                            SECRMem[Addr + i - cnt] = - 1;
                            if ((Addr + i) == AddrHIGH)
                            begin
                                Addr = AddrLOW;
                                cnt = i + 1;
                            end
                        end
                    end
                end
            end

            PGM_SEC_REG :
            begin
                PGM_SEC_REG_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end
                if (rising_edge_PDONE)
                  EndSECRProgramming;
            end

            SEC_REG_ERS_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (((addr_cnt==24 && !CR2V[0]) ||
                    (addr_cnt==32 && CR2V[0])) &&
                    Address/(SECRHiAddr+1)==0)
                    begin
                        SR1V[0] = 1'b1; // WIP
                        SECT_ERS_SEC_REG_ACT = 1'b1;
                        sec_region = Address/(SecRegSize+1);
                        // sec region write protected or locked by the CR1 LB
                        if ((!NVLOCK && (sec_region==2 || sec_region==3)) ||
                        (sec_region==0 && LB0) ||
                        (sec_region==1 && LB1) || (sec_region==2 && LB2) ||
                        (sec_region==3 && LB3))
                            SR2V[6] = 1'b1; // E_ERR
                        else
                        begin
                            ESTART  = 1'b1;
                            ESTART <= #5 1'b0;
                            AddrLOW  = sec_region*(SecRegSize+1);
                            AddrHIGH = AddrLOW + SecRegSize;
                            for (i=AddrLOW;i<=AddrHIGH;i=i+1)
                                SECRMem[i] = -1;
                        end
                    end
                end
            end

            SECT_ERS_SEC_REG :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[6]==1'b1)
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end
                if (rising_edge_EDONE)
                    EndSECRErasing;
            end

            PGMSUS :
            begin
                if (falling_edge_CSNeg_ipd)
                begin
                    Instruct = NONE;
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    DLP_ACT = 0;
                    Address = 32'd0;
                    mode_byte = 8'b00000000;
                    data_cnt   = 0;
                    bit_cnt   = 0;
                    read_cnt  = 0;
                    byte_cnt  = 0;
                    Latency_code = CR3V[3:0];
                    if (Latency_code==0)
                        Latency_code = 8;
                    if (CR3V[6:5]==0)
                        WrapLength = 8;
                    if (CR3V[6:5]==1)
                        WrapLength = 16;
                    if (CR3V[6:5]==2)
                        WrapLength = 32;
                    if (CR3V[6:5]==3)
                        WrapLength = 64;
                end
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        case (opcode)
                            8'b00000011 : Instruct = READ; // 03h
                            8'b00010011 : Instruct = READ4; // 13h
                            8'b00001011 : Instruct = FAST_READ; // 0Bh
                            8'b00001100 : Instruct = FAST_READ4; // 0Ch
                            8'b00111011 : Instruct = DOR; // 3Bh
                            8'b00111100 : Instruct = DOR4; // 3Ch
                            8'b10111011 : Instruct = DIOR; // BBh
                            8'b10111100 : Instruct = DIOR4; // BCh
                            8'b01101011 : Instruct = QOR; // 6Bh
                            8'b01101100 : Instruct = QOR4; // 6Ch
                            8'b11101011 : Instruct = QIOR; // EBh
                            8'b11101100 : Instruct = QIOR4; // ECh
                            8'b11101101 : Instruct = DDRQIOR; // EDh
                            8'b11101110 : Instruct = DDRQIOR4; // EEh
                            8'b01000001 :
                            begin
                                Instruct = DLPRD; // 41h
                                Latency_code = 1;
                            end
                            8'b00111101 : Instruct = IBLRD;// 3Dh
                            8'b11100000 : Instruct = IBLRD4;// E0h
                            8'b01100110 : Instruct = RSTEN; // 66h
                            8'b01001000 : Instruct = SECRR; // 48h
                            8'b10011111 : Instruct = RDID;// 9Fh
                            8'b10101111 : Instruct = RDQID;// AFh
                            8'b01001011 :
                            begin
                                Instruct = RUID; // 4Bh
                                Latency_code = 32;
                            end
                            8'b01011010 : Instruct = RSFDP;// 5Ah
                            8'b01110111 : Instruct = SET_BURST; // 77h
                            8'b00000101 : Instruct = RDSR1; // 05h
                            8'b00000111 : Instruct = RDSR2; // 07h
                            8'b00110101 : Instruct = RDCR1; // 35h
                            8'b00010101 : Instruct = RDCR2; // 15h
                            8'b00110011 : Instruct = RDCR3; // 33h
                            8'b01100101 : Instruct = RDAR; // 65h
                            8'b00110110 : Instruct = IBL; // 36h
                            8'b11100001 : Instruct = IBL4; // E1h
                            8'b00111001 : Instruct = IBUL; // 39h
                            8'b11100010 : Instruct = IBUL4; // E2h
                            8'b00000110 : Instruct = WREN; // 06h
                            8'b00000100 : Instruct = WRDI; // 04h
                            8'b00110000 : Instruct = CLSR; // 30h
                            8'b01111010 : Instruct = EPR; // 7Ah
                       endcase
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==WREN)
                            SR1V[1] = 1'b1;

                        else if (Instruct==WRDI)
                        begin
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                        end
                        else if (Instruct==CLSR)
                        begin
                            SR1V[0] = 1'b0;
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                            SR2V[5] = 1'b0;
                            SR2V[6] = 1'b0;
                        end
                        else if (Instruct==EPR)
                        begin
                            SR2V[0] = 1'b0;
                            SR1V[0] = 1'b1;
                            PGRES = 1'b1;
                            PGRES <= #5 1'b0;
                            RES_TO_SUSP_TIME = 1'b1;
                            RES_TO_SUSP_TIME <= #tdevice_RNS 1'b0;//100us
                        end
                    end
                end
            end

            ERSSUS :
            begin
                if (falling_edge_CSNeg_ipd)
                begin
                    Instruct = NONE;
                    opcode_cnt = 0;
                    addr_cnt = 0;
                    dummy_cnt = 0;
                    mode_cnt = 0;
                    DLP_ACT = 0;
                    Address = 32'd0;
                    mode_byte = 8'b00000000;
                    data_cnt   = 0;
                    bit_cnt   = 0;
                    read_cnt  = 0;
                    byte_cnt  = 0;
                    Latency_code = CR3V[3:0];
                    if (Latency_code==0)
                        Latency_code = 8;
                    if (CR3V[6:5]==0)
                        WrapLength = 8;
                    if (CR3V[6:5]==1)
                        WrapLength = 16;
                    if (CR3V[6:5]==2)
                        WrapLength = 32;
                    if (CR3V[6:5]==3)
                        WrapLength = 64;
                end
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        case (opcode)
                            8'b00000011 :
                                Instruct = READ; // 03h
                            8'b00010011 :
                                Instruct = READ4; // 13h
                            8'b00001011 :
                                Instruct = FAST_READ; // 0Bh
                            8'b00001100 :
                                Instruct = FAST_READ4; // 0Ch
                            8'b00111011 :
                                Instruct = DOR; // 3Bh
                            8'b00111100 :
                                Instruct = DOR4; // 3Ch
                            8'b10111011 :
                                Instruct = DIOR; // BBh
                            8'b10111100 :
                                Instruct = DIOR4; // BCh
                            8'b01101011 :
                                Instruct = QOR; // 6Bh
                            8'b01101100 :
                                Instruct = QOR4; // 6Ch
                            8'b11101011 :
                                Instruct = QIOR; // EBh
                            8'b11101100 :
                                Instruct = QIOR4; // ECh
                            8'b11101101 :
                                Instruct = DDRQIOR; // EDh
                            8'b11101110 :
                                Instruct = DDRQIOR4; // EEh
                            8'b01000001 :
                            begin
                                Instruct = DLPRD; // 41h
                                Latency_code = 1;
                            end
                            8'b00111101 :
                                Instruct = IBLRD;// 3Dh
                            8'b11100000 :
                                Instruct = IBLRD4;// E0h
                            8'b01100110 : Instruct = RSTEN; // 66h
                            8'b01001000 :
                                Instruct = SECRR; // 48h
                            8'b10011111 :
                                Instruct = RDID;// 9Fh
                            8'b10101111 :
                                Instruct = RDQID;// AFh
                            8'b01001011 :
                            begin
                                Instruct = RUID; // 4Bh
                                Latency_code = 32;
                            end
                            8'b01011010 :
                                Instruct = RSFDP;// 5Ah
                            8'b01110111 : Instruct = SET_BURST; // 77h
                            8'b00000101 :
                                Instruct = RDSR1; // 05h
                            8'b00000111 :
                                Instruct = RDSR2; // 07h
                            8'b00110101 :
                                Instruct = RDCR1; // 35h
                            8'b00010101 :
                                Instruct = RDCR2; // 15h
                            8'b00110011 :
                                Instruct = RDCR3; // 33h
                            8'b01100101 :
                                Instruct = RDAR; // 65h
                            8'b00110110 : Instruct = IBL; // 36h
                            8'b11100001 : Instruct = IBL4; // E1h
                            8'b00111001 : Instruct = IBUL; // 39h
                            8'b11100010 : Instruct = IBUL4; // E2h
                            8'b00000110 : Instruct = WREN; // 06h
                            8'b00000100 : Instruct = WRDI; // 04h
                            8'b00110000 : Instruct = CLSR; // 30h
                            8'b00000010 : Instruct = PP; // 02h
                            8'b00010010 : Instruct = PP4; // 12h
                            8'b00110010 : Instruct = QPP; // 32h
                            8'b00110100 : Instruct = QPP4; // 34h
                            8'b01000010 : Instruct = SECRP; // 42h
                            8'b01111010 : Instruct = EPR; // 7Ah
                       endcase
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==WREN)
                            SR1V[1] = 1'b1;

                        else if (Instruct==WRDI)
                        begin
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                        end
                        else if (Instruct==CLSR)
                        begin
                            SR1V[0] = 1'b0;
                            SR1V[1] = 1'b0;
                            WREN_V = 1'b0;
                            SR2V[5] = 1'b0;
                            SR2V[6] = 1'b0;
                        end
                        else if (Instruct==EPR)
                        begin
                            SR2V[1] = 1'b0;
                            SR1V[0] = 1'b1;
                            ERES = 1'b1;
                            ERES <= #5 1'b0;
                            RES_TO_SUSP_TIME = 1'b1;
                            RES_TO_SUSP_TIME <= #tdevice_RNS 1'b0;//100us
                        end
                    end
                end
            end

          WRR_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (byte_cnt <= 3)
                        begin
                            WRR_in[7-data_cnt + 8*byte_cnt] = IO3_RESETNeg_in;
                            WRR_in[6-data_cnt + 8*byte_cnt] = WPNeg_in;
                            WRR_in[5-data_cnt + 8*byte_cnt] = SO_in;
                            WRR_in[4-data_cnt + 8*byte_cnt] = SI_in;
                        end
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        if (byte_cnt <= 3)
                            WRR_in[7-data_cnt + 8*byte_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==0 &&
                byte_cnt>0 && byte_cnt<=4)
                begin
                    if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                    begin
                        SR1V[0] = 1'b1;
                        if (WEL)
                        begin
                            WSTART_NV = 1'b1;
                            WSTART_NV <= #5 1'b0;
                        end
                        else if (WREN_V)
                        begin
                            WSTART_V = 1'b1;
                            WSTART_V <= #5 1'b0;
                        end
                    end
                    // CR3V is not protected by SRP0 and SRP1
                    if (WREN_V &&  byte_cnt==4)
                    begin
                        CR3_in = WRR_in[31:24];
                        CR3V[6:5] = CR3_in[6:5]; // WL
                        CR3V[4] = CR3_in[4];     // WE
                        CR3V[3:0] = CR3_in[3:0]; // RL
                    end
                end
            end

            WRR_NV :
            begin
                WRR_NV_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_WDONE)
                  EndWRR_NV;
            end

            WRR_V :
            begin
                if (rising_edge_WDONE)
                  EndWRR_V;
            end

            WRAR_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (!CR2V[0])
                        begin
                            Address_wrar[23-addr_cnt] = IO3_RESETNeg_in;
                            Address_wrar[22-addr_cnt] = WPNeg_in;
                            Address_wrar[21-addr_cnt] = SO_in;
                            Address_wrar[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (CR2V[0])
                        begin
                            Address_wrar[31-addr_cnt] = IO3_RESETNeg_in;
                            Address_wrar[30-addr_cnt] = WPNeg_in;
                            Address_wrar[29-addr_cnt] = SO_in;
                            Address_wrar[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (!CR2V[0])
                        begin
                            Address_wrar[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (CR2V[0])
                        begin
                            Address_wrar[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
            end

            WRAR_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (data_cnt <= 7)
                        begin
                            WRAR_in[7-data_cnt] = IO3_RESETNeg_in;
                            WRAR_in[6-data_cnt] = WPNeg_in;
                            WRAR_in[5-data_cnt] = SO_in;
                            WRAR_in[4-data_cnt] = SI_in;
                        end
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        if (data_cnt <= 7)
                            WRAR_in[7-data_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==8)
                begin
                    if ((Address_wrar==24'h30) || (Address_wrar==24'h31))
                    begin
                        SR1V[0] = 1'b1;
                        if (IRP[2:0]!=3'b111)
                            SR2V[5] = 1'b1;
                        if (!SECURE_OPN && !IRP_in[4])
                            SR2V[5] = 1'b1;
                        if ((IRP[2:0]==3'b111) && (SR2V[5]==1'b0))
                        begin
                            WSTART_NV = 1'b1;
                            WSTART_NV <= #5 1'b0;
                        end
                    end
                    if ((Address_wrar==24'h0) || (Address_wrar==24'h2) ||
                    (Address_wrar==24'h3) || (Address_wrar==24'h4) ||
                    (Address_wrar==24'h5))
                    begin
                        if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                        begin
                            SR1V[0] = 1'b1;
                            WSTART_NV = 1'b1;
                            WSTART_NV <= #5 1'b0;
                        end
                    end

                    if ((Address_wrar>=24'h20) && (Address_wrar<=24'h27) )
                    begin
                        if (IRP[2])
                        begin
                            SR1V[0] = 1'b1;
                            WSTART_NV = 1'b1;
                            WSTART_NV <= #5 1'b0;
                        end
                    end

                    if ((Address_wrar==24'h39) ||
                    (Address_wrar==24'h3A) || (Address_wrar==24'h3B))
                    begin
                        if (NVLOCK)
                        begin
                            SR1V[0] = 1'b1;
                            WSTART_NV = 1'b1;
                            WSTART_NV <= #5 1'b0;
                        end
                    end
                    if ((Address_wrar==24'h800000)
                    || (Address_wrar==24'h800002) || (Address_wrar==24'h800003)
                    || (Address_wrar==24'h800004) || (Address_wrar==24'h800005))
                    begin
                        if (!srp1 && (!srp0 || WPNeg_in || QUAD || QPI))
                        begin
                            SR1V[0] = 1'b1;
                            WSTART_V = 1'b1;
                            WSTART_V <= #5 1'b0;
                        end
                    end
                end
            end

            WRAR_NV :
            begin
                WRAR_NV_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_WDONE)
                  EndWRAR_NV;
            end

            WRAR_V :
            begin
                if (rising_edge_WDONE)
                  EndWRAR_V;
            end

            IRP_PGM_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (byte_cnt <= 1)
                        begin
                            IRP_in[7-data_cnt + 8*byte_cnt] = IO3_RESETNeg_in;
                            IRP_in[6-data_cnt + 8*byte_cnt] = WPNeg_in;
                            IRP_in[5-data_cnt + 8*byte_cnt] = SO_in;
                            IRP_in[4-data_cnt + 8*byte_cnt] = SI_in;
                        end
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        if (byte_cnt <= 1)
                            IRP_in[7-data_cnt + 8*byte_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==0 && byte_cnt==2)
                begin
                    SR1V[0] = 1'b1;
                    IRP_ACT = 1'b1;
                    if (IRP[2:0]!=3'b111)
                    begin
                        if (!IRP_in[6] ||
                        (!IRP_in[4]) ||
                        (!IRP_in[2]) ||
                        (!IRP_in[1]) ||
                        (!IRP_in[0]))
                            SR2V[5] = 1'b1;
                    end
                    if (!SECURE_OPN && !IRP_in[4])
                        SR2V[5] = 1'b1;

                    if (!SR2V[5])
                    begin
                        PSTART = 1'b1;
                        PSTART <= #5 1'b0;
                    end
                end
            end

            IRP_PGM :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_PDONE)
                  EndIRPP;
            end

            PGM_NV_DLR_DATA :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (data_cnt <= 7)
                    begin
                        if (QPI)
                        begin
                            DLRNV_in[7-data_cnt] = IO3_RESETNeg_in;
                            DLRNV_in[6-data_cnt] = WPNeg_in;
                            DLRNV_in[5-data_cnt] = SO_in;
                            DLRNV_in[4-data_cnt] = SI_in;
                            data_cnt = data_cnt + 4;
                        end
                        else
                        begin
                            DLRNV_in[7-data_cnt] = SI_in;
                            data_cnt = data_cnt + 1;
                        end
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==8)
                begin
                    SR1V[0] = 1'b1;
                    PSTART = 1'b1;
                    PSTART <= #5 1'b0;
                end
            end

            PGM_NV_DLR :
            begin
                DLRNV_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt] = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_PDONE)
                begin
                  SR1V[0] = 1'b0; //WIP
                  SR1V[1] = 1'b0; //WEL
                  DLRNV = DLRNV_in;
                  DLRV = DLRNV;
                  DLRNV_ACT = 1'b0;
                  DLRNV_programmed = 1'b1;
                end
            end

            DLRV_WRITE_DATA :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (data_cnt <= 7)
                    begin
                        if (QPI)
                        begin
                            DLRV_in[7-data_cnt] = IO3_RESETNeg_in;
                            DLRV_in[6-data_cnt] = WPNeg_in;
                            DLRV_in[5-data_cnt] = SO_in;
                            DLRV_in[4-data_cnt] = SI_in;
                            data_cnt = data_cnt + 4;
                        end
                        else
                        begin
                            DLRV_in[7-data_cnt] = SI_in;
                            data_cnt = data_cnt + 1;
                        end
                    end
                end

                if (rising_edge_CSNeg_ipd && data_cnt==8)
                begin
                  SR1V[1] = 1'b0; //WEL
                  DLRV = DLRV_in;
                end
            end

            SET_PNTR_PROT_ADDR :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == SPRP && !CR2V[0])
                        begin
                            PRPR_in[23-addr_cnt] = IO3_RESETNeg_in;
                            PRPR_in[22-addr_cnt] = WPNeg_in;
                            PRPR_in[21-addr_cnt] = SO_in;
                            PRPR_in[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct==SPRP4 || (Instruct == SPRP && CR2V[0]))
                        begin
                            PRPR_in[31-addr_cnt] = IO3_RESETNeg_in;
                            PRPR_in[30-addr_cnt] = WPNeg_in;
                            PRPR_in[29-addr_cnt] = SO_in;
                            PRPR_in[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == SPRP && !CR2V[0])
                        begin
                            PRPR_in[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct==SPRP4 || (Instruct == SPRP && CR2V[0]))
                        begin
                            PRPR_in[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == SPRP4 && addr_cnt == 32) ||
                    (Instruct == SPRP && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        SR1V[0] = 1'b1;
                        WSTART_NV = 1'b1;
                        WSTART_NV <= #5 1'b0;
                    end
                end
            end

            SET_PNTR_PROT :
            begin
                SET_PNTR_PROT_ACT = 1'b1;
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if ((SR2V[5]) || SR2V[6])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end

                if (rising_edge_WDONE)
                    EndSPRP;
            end

            PASSP_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (byte_cnt <= 7)
                        begin
                            Password_reg_in[7-data_cnt + 8*byte_cnt] = IO3_RESETNeg_in;
                            Password_reg_in[6-data_cnt + 8*byte_cnt] = WPNeg_in;
                            Password_reg_in[5-data_cnt + 8*byte_cnt] = SO_in;
                            Password_reg_in[4-data_cnt + 8*byte_cnt] = SI_in;
                        end
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        if (byte_cnt <= 7)
                            Password_reg_in[7-data_cnt + 8*byte_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (data_cnt==0 && byte_cnt==8)
                    begin
                        PASS_PGM_ACT = 1'b1;
                        SR1V[0] = 1'b1;
                        PSTART = 1'b1;
                        PSTART <= #5 1'b0;
                    end
                end
            end

            PASS_PGM :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end
                if (rising_edge_PDONE)
                    EndPassProgramming;
            end

            PASSU_DATA_INPUT :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (byte_cnt <= 7)
                        begin
                            Password_regU_in[7-data_cnt + 8*byte_cnt] = IO3_RESETNeg_in;
                            Password_regU_in[6-data_cnt + 8*byte_cnt] = WPNeg_in;
                            Password_regU_in[5-data_cnt + 8*byte_cnt] = SO_in;
                            Password_regU_in[4-data_cnt + 8*byte_cnt] = SI_in;
                        end
                        data_cnt = data_cnt + 4;
                    end
                    else
                    begin
                        if (byte_cnt <= 7)
                            Password_regU_in[7-data_cnt + 8*byte_cnt] = SI_in;
                        data_cnt = data_cnt + 1;
                    end
                    if (data_cnt == 8)
                    begin
                        data_cnt = 0;
                        byte_cnt = byte_cnt + 1;
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (data_cnt==0 && byte_cnt==8)
                    begin
                        SR1V[0] = 1'b1;
                        PASSULCK_in = 1'b1;
                        if (Password_regU_in != Password_reg)
                            SR1V[5] = 1'b1;
                        else
                            if (!IRP[2])
                            begin
                                PR[0] = 1'b1;
                                PR[6] = 1'b1;
                            end
                    end
                end
            end

            PASS_ULCK :
            begin
                if (falling_edge_CSNeg_ipd)
                    opcode_cnt = 0;
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (opcode_cnt<=7)
                        begin
                            opcode[7-opcode_cnt]   = IO3_RESETNeg_in;
                            opcode[6-opcode_cnt] = WPNeg_in;
                            opcode[5-opcode_cnt] = SO_in;
                            opcode[4-opcode_cnt] = SI_in;
                        end
                        opcode_cnt = opcode_cnt + 4;
                    end
                    else
                    begin
                        if (opcode_cnt<=7)
                            opcode[7-opcode_cnt] = SI_in;
                        opcode_cnt = opcode_cnt + 1;
                    end
                    if (opcode_cnt == 8)
                    begin
                        Instruct = NONE;
                        if (opcode==8'b00000101)
                            Instruct = RDSR1; // 05h
                        else if (opcode==8'b00000111)
                            Instruct = RDSR2; // 07h
                        else if (opcode==8'b00110101)
                            Instruct = RDCR1; // 35h
                        else if (opcode==8'b00010101)
                            Instruct = RDCR2; // 15h
                        else if (opcode==8'b00110011)
                            Instruct = RDCR3; // 33h
                        else if (opcode==8'b01100101)
                            Instruct = RDAR; // 65h
                        else if (opcode==8'b00110000)
                            Instruct = CLSR; // 30h
                        else if (opcode==8'b01100110)
                            Instruct = RSTEN; // 66h
                    end
                end

                if (rising_edge_CSNeg_ipd)
                begin
                    if (opcode_cnt==8)
                    begin
                        if (Instruct==CLSR)
                        begin
                            if (SR2V[5])
                            begin
                                SR1V[0] = 1'b0;
                                SR1V[1] = 1'b0;
                                WREN_V = 1'b0;
                                SR2V[5] = 1'b0;
                                SR2V[6] = 1'b0;
                            end
                        end
                    end
                end
                if (rising_edge_PASSULCK_out)
                begin
                    PASSULCK_in=1'b0;
                    SR1V[0] = 1'b0;
                    SR1V[1] = 1'b0;
                end
            end

            IBL_LOCK :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == IBL && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct==IBL4 || (Instruct == IBL && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == IBL && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct==IBL4 || (Instruct == IBL && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == IBL4 && addr_cnt == 32) ||
                    (Instruct == IBL && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        sec = Address/(SecSize+1);
                        blk = sec/16;
                        if (blk==0 || blk==BlockNum)
                            IBL_Sec_Prot[sec] = 1'b0;
                        else
                        begin
                            for (i=0;i<=15;i=i+1)
                                IBL_Sec_Prot[blk*16 + i] = 1'b0;
                        end
                    end
                end

            end

            IBL_UNLOCK :
            begin
                if (rising_edge_SCK_ipd && !CSNeg_ipd)
                begin
                    if (QPI)
                    begin
                        if (Instruct == IBUL && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = IO3_RESETNeg_in;
                            Address[22-addr_cnt] = WPNeg_in;
                            Address[21-addr_cnt] = SO_in;
                            Address[20-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                        else if (Instruct==IBUL4 || (Instruct == IBUL && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = IO3_RESETNeg_in;
                            Address[30-addr_cnt] = WPNeg_in;
                            Address[29-addr_cnt] = SO_in;
                            Address[28-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 4;
                        end
                    end
                    else
                    begin
                        if (Instruct == IBUL && !CR2V[0])
                        begin
                            Address[23-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                        else if (Instruct==IBUL4 || (Instruct == IBUL && CR2V[0]))
                        begin
                            Address[31-addr_cnt] = SI_in;
                            addr_cnt = addr_cnt + 1;
                        end
                    end
                end
                if (rising_edge_CSNeg_ipd)
                begin
                    if ((Instruct == IBUL4 && addr_cnt == 32) ||
                    (Instruct == IBUL && ((!CR2V[0] && addr_cnt == 24) ||
                    (CR2V[0] && addr_cnt == 32))))
                    begin
                        sec = Address/(SecSize+1);
                        blk = sec/16;
                        if (blk==0 || blk==BlockNum)
                            IBL_Sec_Prot[sec] = 1'b1;
                        else
                        begin
                            for (i=0;i<=15;i=i+1)
                                IBL_Sec_Prot[blk*16 + i] = 1'b1;
                        end
                    end
                end
            end
        endcase

        if (falling_edge_CSNeg_ipd)
        begin
            normal_rd = 0;
            fast_rd = 1;
            ddr_rd = 0;
            reg_rd = 0;
            opcode_cnt = 0;
            addr_cnt = 0;
            dummy_cnt = 0;
            mode_cnt = 0;
            data_cnt   = 0;
            bit_cnt   = 0;
            read_cnt  = 0;
        end

        CR1V[7] = SR2V[0] | SR2V[1];

        if (rising_edge_QEN_out)
            QEN_in = 1'b0;
        if (rising_edge_QEXN_out)
            QEXN_in = 1'b0;

        end

    end // Functionality

    always @(posedge CSNeg_ipd)
    begin
        //Output Disable Control
        SOut_zd        = 1'bZ;
        SIOut_zd       = 1'bZ;
        IO3_RESETNegOut_zd = 1'bZ;
        WPNegOut_zd    = 1'bZ;
        DataDriveOut_SO    = 1'bZ;
        DataDriveOut_SI    = 1'bZ;
        DataDriveOut_IO3_RESET = 1'bZ;
        DataDriveOut_WP    = 1'bZ;
    end

    always @(PoweredUp, BP2, BP1, BP0, TBPROT, SEC, CMP)
    begin

        if (!CMP)
        begin
            Legacy_Sec_Prot = {(SecNum+1){1'b0}};
            case ({BP2,BP1,BP0})

            3'b000:
                Legacy_Sec_Prot = {(SecNum+1){1'b0}};

            3'b001:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-31)] = {32{1'b1}};
                    else
                        Legacy_Sec_Prot[SecNum] = 1'b1;
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[31 : 0] = {32{1'b1}};
                    else
                        Legacy_Sec_Prot[0] = 1'b1;
                end
            end

            3'b010:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-63)] = {64{1'b1}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-1)] = {2{1'b1}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[63 : 0] = {64{1'b1}};
                    else
                        Legacy_Sec_Prot[1:0] = {2{1'b1}};
                end
            end

            3'b011:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-127)] = {128{1'b1}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-3)] = {4{1'b1}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[127 : 0] = {128{1'b1}};
                    else
                        Legacy_Sec_Prot[3:0] = {4{1'b1}};
                end
            end

            3'b100:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-255)] = {256{1'b1}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-7)] = {8{1'b1}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[255 : 0] = {256{1'b1}};
                    else
                        Legacy_Sec_Prot[7:0] = {8{1'b1}};
                end
            end

           3'b101:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-511)] = {512{1'b1}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-7)] = {8{1'b1}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[511 : 0] = {512{1'b1}};
                    else
                        Legacy_Sec_Prot[7:0] = {8{1'b1}};
                end
            end

           3'b110:
            begin
                if (!TBPROT)
                begin
                        Legacy_Sec_Prot[SecNum : (SecNum-1023)] = {1024{1'b1}};
                end
                else
                begin
                        Legacy_Sec_Prot[1023 : 0] = {1024{1'b1}};
                end
            end

            3'b111:
                Legacy_Sec_Prot = {(SecNum+1){1'b1}};

            endcase
        end
        else // CMP=1
        begin
            Legacy_Sec_Prot = {(SecNum+1){1'b1}};
            case ({BP2,BP1,BP0})

            3'b000:
                Legacy_Sec_Prot = {(SecNum+1){1'b1}};

            3'b001:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-31)] = {32{1'b0}};
                    else
                        Legacy_Sec_Prot[SecNum] = 1'b0;
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[31 : 0] = {32{1'b0}};
                    else
                        Legacy_Sec_Prot[0] = 1'b0;
                end
            end

            3'b010:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-63)] = {64{1'b0}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-1)] = {2{1'b0}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[63 : 0] = {64{1'b0}};
                    else
                        Legacy_Sec_Prot[1:0] = {2{1'b0}};
                end
            end

            3'b011:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-127)] = {128{1'b0}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-3)] = {4{1'b0}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[127 : 0] = {128{1'b0}};
                    else
                        Legacy_Sec_Prot[3:0] = {4{1'b0}};
                end
            end

            3'b100:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-255)] = {256{1'b0}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-7)] = {8{1'b0}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[255 : 0] = {256{1'b0}};
                    else
                        Legacy_Sec_Prot[7:0] = {8{1'b0}};
                end
            end

           3'b101:
            begin
                if (!TBPROT)
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[SecNum : (SecNum-511)] = {512{1'b0}};
                    else
                        Legacy_Sec_Prot[SecNum : (SecNum-7)] = {8{1'b0}};
                end
                else
                begin
                    if (!SEC)
                        Legacy_Sec_Prot[511 : 0] = {512{1'b0}};
                    else
                        Legacy_Sec_Prot[7:0] = {8{1'b0}};
                end
            end

           3'b110:
            begin
                if (!TBPROT)
                begin
                        Legacy_Sec_Prot[SecNum : (SecNum-1023)] = {1024{1'b0}};
                end
                else
                begin
                        Legacy_Sec_Prot[1023 : 0] = {1024{1'b0}};
                end
            end

            3'b111:
                Legacy_Sec_Prot = {(SecNum+1){1'b0}};
            endcase

        end
    end

    always @(Legacy_Sec_Prot, PRP_Sec_Prot, IBL_Sec_Prot, WPS)
    begin
        Block_Prot = {(BlockNum) {1'b0}};
        HalfBlock_Prot = {(HalfBlockNum) {1'b0}};
        if (!WPS)  // Legacy block protect active
        begin
            if (!PRPR[10]) // Enable Pointer Region Protection
            begin
                for(i=0;i<=SecNum;i=i+1)
                begin
                    Sec_Prot[i] = PRP_Sec_Prot[i] | Legacy_Sec_Prot[i];
                    if (Sec_Prot[i])
                    begin
                        Block_Prot[i/16] = 1'b1;
                        HalfBlock_Prot[i/8] = 1'b1;
                    end
                end
            end
            else
            begin
                for(i=0;i<=SecNum;i=i+1)
                begin
                    Sec_Prot[i] = Legacy_Sec_Prot[i];
                    if (Sec_Prot[i])
                    begin
                        Block_Prot[i/16] = 1'b1;
                        HalfBlock_Prot[i/8] = 1'b1;
                    end
                end
            end
        end
        else // WPS=1 Individual Block Lock active
        begin
            if (!PRPR[10]) // Enable Pointer Region Protection
            begin
                for(i=0;i<=SecNum;i=i+1)
                begin
                    Sec_Prot[i] = PRP_Sec_Prot[i] | !IBL_Sec_Prot[i];
                    if (Sec_Prot[i])
                    begin
                        Block_Prot[i/16] = 1'b1;
                        HalfBlock_Prot[i/8] = 1'b1;
                    end
                end
            end
            else
            begin
                for(i=0;i<=SecNum;i=i+1)
                begin
                    Sec_Prot[i] =!IBL_Sec_Prot[i];
                    if (Sec_Prot[i])
                    begin
                        Block_Prot[i/16] = 1'b1;
                        HalfBlock_Prot[i/8] = 1'b1;
                    end
                end
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // functions & tasks
    ///////////////////////////////////////////////////////////////////////////

    task READ_ALL_REG;
        input integer Addr;
        output [7:0] RDAR_reg;

        reg [7:0] RDAR_reg;
    begin
        if (Addr == 32'h00000000)
            RDAR_reg = SR1NV;
        else if (Addr == 32'h00000002)
            RDAR_reg = CR1NV;
        else if (Addr == 32'h00000003)
            RDAR_reg = CR2NV;
        else if (Addr == 32'h00000004)
            RDAR_reg = CR3NV;
        else if (Addr == 32'h00000005)
            RDAR_reg = DLRNV;
        else if (Addr == 32'h00000020)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[7:0];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000021)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[15:8];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000022)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[23:16];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000023)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[31:24];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000024)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[39:32];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000025)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[47:40];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000026)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[55:48];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000027)
        begin
            if (IRP[2])
                RDAR_reg = Password_reg[63:56];
            else
                RDAR_reg = 8'bXX;
        end
        else if (Addr == 32'h00000030)
            RDAR_reg = IRP[7:0];
        else if (Addr == 32'h00000031)
            RDAR_reg = IRP[15:8];
        else if (Addr == 32'h00000039)
            RDAR_reg = PRPR[15:8];
        else if (Addr == 32'h0000003A)
            RDAR_reg = PRPR[23:16];
//         else if (Addr == 32'h0000003B)  // DINIC
//             RDAR_reg = PRPR[31:24];
        else if (Addr == 32'h00800000)
            RDAR_reg = SR1V;
        else if (Addr == 32'h00800001)
            RDAR_reg = SR2V;
        else if (Addr == 32'h00800002)
            RDAR_reg = CR1V;
        else if (Addr == 32'h00800003)
            RDAR_reg = CR2V;
        else if (Addr == 32'h00800004)
            RDAR_reg = CR3V;
        else if (Addr == 32'h00800005)
            RDAR_reg = DLRV;
        else if (Addr == 32'h00800040)
            RDAR_reg = PR;
        else
            RDAR_reg = 8'bXX;//N/A
    end
    endtask

    task EndProgramming;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        PGM_ACT = 1'b0;
        cnt = 0;
        for (i=0;i<=wr_cnt;i=i+1)
        begin
            Mem[Addr_tmp + i - cnt] = WData[i];
            if ((Addr_tmp + i) == AddrHIGH)
            begin
                Addr_tmp = AddrLOW;
                cnt = i + 1;
            end
        end
    end
    endtask

    task EndSECRProgramming;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        PGM_SEC_REG_ACT = 1'b0;
        cnt = 0;
        for (i=0;i<=wr_cnt;i=i+1)
        begin
            SECRMem[Addr_tmp + i - cnt] = WData[i];
            if ((Addr_tmp + i) == AddrHIGH)
            begin
                Addr_tmp = AddrLOW;
                cnt = i + 1;
            end
        end
    end
    endtask

    task EndSecErasing;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        SECT_ERS_ACT = 1'b0;
        AddrLOW  = SectorErase*(SecSize+1);
        AddrHIGH = AddrLOW + SecSize;
        for (i=AddrLOW;i<=AddrHIGH;i=i+1)
            Mem[i] = MaxData;
    end
    endtask

    task EndHalfBlockErasing;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        HALF_BLOCK_ERS_ACT = 1'b0;
        AddrLOW  = HalfBlockErase*(HalfBlockSize+1);
        AddrHIGH = AddrLOW + HalfBlockSize;
        for (i=AddrLOW;i<=AddrHIGH;i=i+1)
            Mem[i] = MaxData;
    end
    endtask

    task EndBlockErasing;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        BLOCK_ERS_ACT = 1'b0;
        AddrLOW  = BlockErase*(BlockSize+1);
        AddrHIGH = AddrLOW + BlockSize;
        for (i=AddrLOW;i<=AddrHIGH;i=i+1)
            Mem[i] = MaxData;
    end
    endtask

    task EndChipErasing;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        CHIP_ERS_ACT = 1'b0;
        for (i=0;i<=AddrRANGE;i=i+1)
            Mem[i] = MaxData;
    end
    endtask

    task EndSECRErasing;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        SECT_ERS_SEC_REG_ACT = 1'b0;
        AddrLOW  = sec_region*(SecRegSize+1);
        AddrHIGH = AddrLOW + SecRegSize;
        for (i=AddrLOW;i<=AddrHIGH;i=i+1)
            SECRMem[i] = MaxData;
    end
    endtask

    task EndWRR_NV;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        WRR_NV_ACT = 1'b0;
        if ((byte_cnt==1) || (byte_cnt==2) ||
        (byte_cnt==3) || (byte_cnt==4))
        begin
            SR1_in = WRR_in[7:0];
            SR1NV[7:2] = SR1_in[7:2]; // SRP0, SEC, TBPROT, BP2-BP0
            SR1V[7:2] = SR1NV[7:2];
        end
        if ((byte_cnt==2) || (byte_cnt==3) || (byte_cnt==4))
        begin
            CR1_in = WRR_in[15:8];

            CR1NV[6] = CR1_in[6];  //CMP
            CR1V[6] = CR1NV[6];

            if (CR1_in[5])  // OTP LB3
            begin
                CR1NV[5] = CR1_in[5];
                CR1V[5] = CR1NV[5];
            end

            if (CR1_in[4])  // OTP LB2
            begin
                CR1NV[4] = CR1_in[4];
                CR1V[4] = CR1NV[4];
            end

            if (CR1_in[3])  // OTP LB1
            begin
                CR1NV[3] = CR1_in[3];
                CR1V[3] = CR1NV[3];
            end

            if (CR1_in[2])  // OTP LB0
            begin
                CR1NV[2] = CR1_in[2];
                CR1V[2] = CR1NV[2];
            end

            if (!QIO_ONLY_OPN)    // QUAD
            begin
                CR1NV[1] = CR1_in[1];
                CR1V[1] = CR1NV[1];
            end

            if (CR1_in[0])  // OTP SRP1
            begin
                CR1V[0] = 1'b1;
                if (IRP[2:0] == 3'b111)
                    CR1NV[0] = 1'b1;
            end
        end
        if ((byte_cnt==3) || (byte_cnt==4))
        begin
            CR2_in = WRR_in[23:16];

            CR2NV[7] = CR2_in[7]; // IO3R
            CR2V[7] = CR2NV[7];

            CR2NV[6:5] = CR2_in[6:5]; // OI
            CR2V[6:5] = CR2NV[6:5];

            if (!QPI_ONLY_OPN)   // QPI
            begin
                CR2NV[3] = CR2_in[3];
                CR2V[3] = CR2NV[3];
            end
            CR2NV[2] = CR2_in[2]; // WPS
            CR2V[2] = CR2NV[2];

            CR2NV[1] = CR2_in[1]; // Address length
            CR2V[0] = CR2NV[1]; // Address length
        end
        if (byte_cnt==4)
        begin
            CR3_in = WRR_in[31:24];
            CR3NV[6:0] = CR3_in[6:0]; // WL, WE, RL
            CR3V[6:0] = CR3NV[6:0];
        end
    end
    endtask

    task EndWRR_V;
    begin
        SR1V[0] = 1'b0; //WIP
        WREN_V = 1'b0;
        if ((byte_cnt==1) || (byte_cnt==2) ||
        (byte_cnt==3) || (byte_cnt==4))
        begin
            SR1_in = WRR_in[7:0];
            SR1V[7:2] = SR1_in[7:2]; // SRP0, SEC, TBPROT, BP2-BP0
        end
        if ((byte_cnt==2) || (byte_cnt==3) || (byte_cnt==4))
        begin
            CR1_in = WRR_in[15:8];
            CR1V[6] = CR1_in[6];  //CMP
            if (!QIO_ONLY_OPN)    // QUAD
            begin
                if (CR1_in[1] && !CR1V[1])       // enter QUAD mode
                    QEN_in = 1'b1;
                else if (!CR1_in[1] && CR1V[1]) // exit QUAD mode
                    QEXN_in = 1'b1;
                CR1V[1] = CR1_in[1];
            end
            if (CR1_in[0])  // SRP1
                CR1V[0] = CR1_in[0];
        end
        if ((byte_cnt==3) || (byte_cnt==4))
        begin
            CR2_in = WRR_in[23:16];

            CR2V[7] = CR2_in[7]; // IO3R

            CR2V[6:5] = CR2_in[6:5]; // OI

            if (!QPI_ONLY_OPN)   // QPI
            begin
                if (CR2_in[3] && !CR2V[3])       // enter QPI mode
                    QEN_in = 1'b1;
                else if (!CR2_in[3] && CR2V[3]) // exit QPI mode
                    QEXN_in = 1'b1;
                CR2V[3] = CR2_in[3];
            end

            CR2V[2] = CR2_in[2]; // WPS
            CR2V[0] = CR2_in[0]; // Address length
        end
        if (byte_cnt==4)
        begin
            CR3_in = WRR_in[31:24];
            CR3V[6:5] = CR3_in[6:5]; // WL
            CR3V[4] = CR3_in[4];     // WE
            CR3V[3:0] = CR3_in[3:0]; // RL
        end
    end
    endtask

    task EndWRAR_NV;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        WRAR_NV_ACT = 1'b0;
        if (Address_wrar==24'h0)
        begin
            SR1_in = WRAR_in;
            SR1NV[7:2] = SR1_in[7:2]; // SRP0, SEC, TBPROT, BP2-BP0
            SR1V[7:2] = SR1NV[7:2];
        end
        else if (Address_wrar==24'h2)
        begin
            CR1_in = WRAR_in;

            CR1NV[6] = CR1_in[6];  //CMP
            CR1V[6] = CR1NV[6];

            if (CR1_in[5])  // OTP LB3
            begin
                CR1NV[5] = CR1_in[5];
                CR1V[5] = CR1NV[5];
            end

            if (CR1_in[4])  // OTP LB2
            begin
                CR1NV[4] = CR1_in[4];
                CR1V[4] = CR1NV[4];
            end

            if (CR1_in[3])  // OTP LB1
            begin
                CR1NV[3] = CR1_in[3];
                CR1V[3] = CR1NV[3];
            end

            if (CR1_in[2])  // OTP LB0
            begin
                CR1NV[2] = CR1_in[2];
                CR1V[2] = CR1NV[2];
            end

            if (!QIO_ONLY_OPN)    // QUAD
            begin
                CR1NV[1] = CR1_in[1];
                CR1V[1] = CR1NV[1];
            end

            if (CR1_in[0])  // OTP SRP1
            begin
                CR1V[0] = 1'b1;
                if (IRP[2:0] == 3'b111)
                    CR1NV[0] = 1'b1;
            end
        end
        else if (Address_wrar==24'h3)
        begin
            CR2_in = WRAR_in;

            CR2NV[7] = CR2_in[7]; // IO3R
            CR2V[7] = CR2NV[7];

            CR2NV[6:5] = CR2_in[6:5]; // OI
            CR2V[6:5] = CR2NV[6:5];

            if (!QPI_ONLY_OPN)   // QPI
            begin
                CR2NV[3] = CR2_in[3];
                CR2V[3] = CR2NV[3];
            end
            CR2NV[2] = CR2_in[2]; // WPS
            CR2V[2] = CR2NV[2];

            CR2NV[1] = CR2_in[1]; // Address length
            CR2V[0] = CR2NV[1]; // Address length
        end
        else if (Address_wrar==24'h4)
        begin
            CR3_in = WRAR_in;
            CR3NV[6:0] = CR3_in[6:0]; // WL, WE, RL
            CR3V[6:0] = CR3NV[6:0];
        end
        else if (Address_wrar==24'h5)
        begin
            for (i=0;i<=7;i=i+1)
                if (!DLRNV[i]) // OTP Non-volatile DDR Data Learning Pattern reg
                    DLRNV[i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h20 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[i]) // OTP Non-volatile Password register
                    Password_reg[i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h21 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[8+i])
                    Password_reg[8+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h22 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[16+i])
                    Password_reg[16+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h23 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[24+i])
                    Password_reg[24+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h24 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[32+i])
                    Password_reg[32+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h25 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[40+i])
                    Password_reg[40+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h26 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[48+i])
                    Password_reg[48+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h27 && IRP[2])
        begin
            for (i=0;i<=7;i=i+1)
                if (Password_reg[56+i])
                    Password_reg[56+i] = WRAR_in[i];
        end

        else if (Address_wrar==24'h30)
        begin
            if (IRP[6])
                IRP[6] = WRAR_in[6];  //OTP
            if (IRP[4])
                IRP[4] = WRAR_in[4];

            if (WRAR_in[2:0]==3'b110 || WRAR_in[2:0]==3'b101 ||
            WRAR_in[2:0]==3'b011)
                IRP[2:0] = WRAR_in[2:0];
        end
        else if (Address_wrar==24'h39)
            PRPR[15:8] = WRAR_in;
        else if (Address_wrar==24'h3A)
            PRPR[23:16] = WRAR_in;

    end
    endtask

    task EndWRAR_V;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        WREN_V = 1'b0;
        if (Address_wrar==24'h800000)
        begin
            SR1_in = WRAR_in[7:0];
            SR1V[7:2] = SR1_in[7:2]; // SRP0, SEC, TBPROT, BP2-BP0
        end
        else if (Address_wrar==24'h800002)
        begin
            CR1_in = WRAR_in;
            CR1V[6] = CR1_in[6];  //CMP
            if (!QIO_ONLY_OPN)    // QUAD
            begin
                if (CR1_in[1] && !CR1V[1])       // enter QUAD mode
                begin
                    CR1V[1] = CR1_in[1];
                    QEN_in = 1'b1;
                end
                else if (!CR1_in[1] && CR1V[1]) // exit QUAD mode
                begin
                    CR1V[1] = CR1_in[1];
                    QEXN_in = 1'b1;
                end
            end
            if (CR1_in[0])  // SRP1
                CR1V[0] = CR1_in[0];
        end
        else if (Address_wrar==24'h800003)
        begin
            CR2_in = WRAR_in;

            CR2V[7] = CR2_in[7]; // IO3R

            CR2V[6:5] = CR2_in[6:5]; // OI

            if (!QPI_ONLY_OPN)   // QPI
            begin
                if (CR2_in[3] && !CR2V[3])       // enter QPI mode
                begin
                    CR2V[3] = CR2_in[3];
                    QEN_in = 1'b1;
                end
                else if (!CR2_in[3] && CR2V[3]) // exit QPI mode
                begin
                    CR2V[3] = CR2_in[3];
                    QEXN_in = 1'b1;
                end
            end

            CR2V[2] = CR2_in[2]; // WPS

            CR2V[0] = CR2_in[0]; // Address length
        end
        else if (Address_wrar==24'h800004)
        begin
            CR3_in = WRAR_in;
            CR3V[6:5] = CR3_in[6:5]; // WL
            CR3V[4] = CR3_in[4];     // WE
            CR3V[3:0] = CR3_in[3:0]; // RL
        end
        else if (Address_wrar==24'h800005)
            DLRV = WRAR_in;
    end
    endtask

    task EndIRPP;
    begin
        SR1V[0] = 1'b0; //WIP
        IRP_ACT = 1'b0;
        if (IRP[6])
            IRP[6] = IRP_in[6];
        if (IRP[4])
            IRP[4] = IRP_in[4];
        if (IRP_in[2:0]==3'b110 || IRP_in[2:0]==3'b101 ||
        IRP_in[2:0]==3'b011)
            IRP[2:0] = IRP_in[2:0];
    end
    endtask

    task EndPassProgramming;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        PASS_PGM_ACT = 1'b0;
        for (i=0;i<=63;i=i+1)
        begin
            if (Password_reg[i]) // OTP Non-volatile Password register
                Password_reg[i] = Password_reg_in[i];
        end
    end
    endtask

    task EndSPRP;
    begin
        SR1V[0] = 1'b0; //WIP
        SR1V[1] = 1'b0; //WEL
        SET_PNTR_PROT_ACT = 1'b0;
        PRPR = PRPR_in;
    end
    endtask

    always @(PRPR)
    begin
        if (!PRPR[10]) // Enable Pointer Region Protection
        begin
            if (PRPR[11]) // Protect All Sectors
                PRP_Sec_Prot = {(SecNum+1) {1'b1}};
            else
            begin
                sec = PRPR[22:12];
                if (!PRPR[9]) // Bottom unprotected
                begin
                    PRP_Sec_Prot = {(SecNum+1) {1'b1}};
                    for (i=0; i<=SecNum; i=i+1)
                    begin
                        if (i<=sec)
                            PRP_Sec_Prot[i] = 1'b0;
                    end
                end
                else  // Bottom protected
                begin
                    PRP_Sec_Prot = {(SecNum+1) {1'b0}};
                    for (i=0; i<=SecNum; i=i+1)
                    begin
                        if (i<sec)
                            PRP_Sec_Prot[i] = 1'b1;
                    end
                end
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // edge controll processes
    ///////////////////////////////////////////////////////////////////////////

    always @(posedge PoweredUp)
    begin
        rising_edge_PoweredUp = 1;
        #1 rising_edge_PoweredUp = 0;
    end

    always @(posedge SCK_ipd)
    begin
       rising_edge_SCK_ipd = 1'b1;
       #1 rising_edge_SCK_ipd = 1'b0;

       rising_edge_SCK_D = 1'b1;
       #1 rising_edge_SCK_D = 1'b0;
    end

    always @(negedge SCK_ipd)
    begin
       falling_edge_SCK_ipd = 1'b1;
       #1 falling_edge_SCK_ipd = 1'b0;

       falling_edge_SCK_D = 1'b1;
       #1 falling_edge_SCK_D = 1'b0;
    end

    always @(posedge CSNeg_ipd)
    begin
        rising_edge_CSNeg_ipd = 1'b1;
        #1 rising_edge_CSNeg_ipd = 1'b0;
        rising_edge_CSNeg_d = 1'b1;
        #1 rising_edge_CSNeg_d = 1'b0;
    end

    always @(negedge CSNeg_ipd)
    begin
        falling_edge_CSNeg_ipd = 1'b1;
        #1 falling_edge_CSNeg_ipd = 1'b0;
    end

    always @(posedge reseted)
    begin
        rising_edge_reseted = 1;
        #1 rising_edge_reseted = 0;
    end

    always @(posedge PSTART)
    begin
        rising_edge_PSTART = 1'b1;
        #1 rising_edge_PSTART = 1'b0;
    end

    always @(posedge PDONE)
    begin
        rising_edge_PDONE <= 1'b1;
        #1 rising_edge_PDONE <= 1'b0;
    end

    always @(posedge WSTART_NV)
    begin
        rising_edge_WSTART_NV = 1;
        #1 rising_edge_WSTART_NV = 0;
    end

    always @(posedge WSTART_V)
    begin
        rising_edge_WSTART_V = 1;
        #1 rising_edge_WSTART_V = 0;
    end

    always @(posedge WDONE)
    begin
        rising_edge_WDONE = 1'b1;
        #1 rising_edge_WDONE = 1'b0;
    end

    always @(posedge ESTART)
    begin
        rising_edge_ESTART = 1'b1;
        #1 rising_edge_ESTART = 1'b0;
    end

    always @(posedge EDONE)
    begin
        rising_edge_EDONE = 1'b1;
        #1 rising_edge_EDONE = 1'b0;
    end

    always @(negedge RST)
    begin
        falling_edge_RST = 1'b1;
        #1 falling_edge_RST = 1'b0;
    end

    always @(posedge RES_out)
    begin
        rising_edge_RES_out = 1'b1;
        #1 rising_edge_RES_out = 1'b0;
    end

    always @(negedge RES_in)
    begin
        falling_edge_RES_in = 1'b1;
        #1 falling_edge_RES_in = 1'b0;
    end

    always @(posedge PRGSUSP_out)
    begin
        rising_edge_PRGSUSP_out = 1'b1;
        #1 rising_edge_PRGSUSP_out = 1'b0;
    end

    always @(posedge ERSSUSP_out)
    begin
        rising_edge_ERSSUSP_out = 1'b1;
        #1 rising_edge_ERSSUSP_out = 1'b0;
    end

    always @(posedge QEN_out)
    begin
        rising_edge_QEN_out = 1'b1;
        #1 rising_edge_QEN_out = 1'b0;
    end

    always @(posedge QEXN_out)
    begin
        rising_edge_QEXN_out = 1'b1;
        #1 rising_edge_QEXN_out = 1'b0;
    end

    always @(posedge PASSULCK_out)
    begin
        rising_edge_PASSULCK_out = 1'b1;
        #1 rising_edge_PASSULCK_out = 1'b0;
    end

    always @(posedge SFT_RST_out)
    begin
        rising_edge_SFT_RST_out = 1'b1;
        #1 rising_edge_SFT_RST_out = 1'b0;
    end

    always @(posedge HW_RST_out)
    begin
        rising_edge_HW_RST_out = 1'b1;
        #1 rising_edge_HW_RST_out = 1'b0;
    end

    integer DQt_01;

    reg  BuffInDQ;
    wire BuffOutDQ;

    BUFFER    BUF_DOut   (BuffOutDQ, BuffInDQ);

    initial
    begin
        BuffInDQ   = 1'b1;
    end

    always @(posedge BuffOutDQ)
    begin
        DQt_01 = $time;
    end

    always @(DataDriveOut_SO, DataDriveOut_SI,
        DataDriveOut_IO3_RESET, DataDriveOut_WP)
    begin
        if (DQt_01 > CLK_PER)
        begin
            glitch = 1;
            SOut_zd        <= #DQt_01 DataDriveOut_SO;
            SIOut_zd       <= #DQt_01 DataDriveOut_SI;
            IO3_RESETNegOut_zd <= #DQt_01 DataDriveOut_IO3_RESET;
            WPNegOut_zd    <= #DQt_01 DataDriveOut_WP;
        end
        else
        begin
            glitch = 0;
            SOut_zd        <= DataDriveOut_SO;
            SIOut_zd       <= DataDriveOut_SI;
            IO3_RESETNegOut_zd <= DataDriveOut_IO3_RESET;
            WPNegOut_zd    <= DataDriveOut_WP;
        end
    end

endmodule

module BUFFER (OUT,IN);
    input IN;
    output OUT;
    buf   ( OUT, IN);
endmodule
