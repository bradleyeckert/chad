{ ==============================================================================
Graphics
}

\ Expects PANES = # of graphic panes, FONTHT = medium font height
\ Initpane needs dimensions as well as HDC (device context) and hDlg (dialog window handle).
\ Once these are set up, the current pane uses those HDC and hDlg handles.

LIBRARY GDI32

PANES 6 * CELLS BUFFER: Gpanes  \ separate graphic panes
PAD VALUE PANE          \ Select the current window pane to draw rectangles on

: SetPane       ( n -- )  PANES 1- MIN  4 * CELLS Gpanes + TO PANE ;
: ORGX          ( -- X )  PANE @ ;
: ORGY          ( -- Y )  PANE CELL+ @ ;
: WIDTH         ( -- X )  PANE 2 CELLS + @ ;
: HEIGHT        ( -- Y )  PANE 3 CELLS + @ ;
: hDlg_G        ( -- Y )  PANE 4 CELLS + ;
: HDC_G         ( -- Y )  PANE 5 CELLS + ;

0 SetPane

0 VALUE BRUSH

: SET_FCOLOR  ( colorref -- )
   BRUSH IF BRUSH DeleteObject DROP THEN    \ throw away old brush
   CreateSolidBrush TO BRUSH ;              \ set new current color

: RGB>CR    ( r g b -- colorref )  16 LSHIFT SWAP 8 LSHIFT OR OR ;
: SETRGB    ( r g b -- )   RGB>CR SET_FCOLOR ;
: RGB       ( r g b -- )   CREATE RGB>CR , DOES> @ SET_FCOLOR ;  \ create a fill color
: RGBW      ( r g b -- )   RGB>CR $FF000000 OR CONSTANT ;        \ create a white-referenced color

: SETFG     ( colorref -- )  HDC_G @ SWAP SetTextColor DROP ;
: SETBG     ( colorref -- )  HDC_G @ SWAP SetBkColor DROP ;
: RGBF      ( r g b -- )   CREATE RGB>CR , DOES> @ SETFG ;       \ create a text foreground color
: RGBB      ( r g b -- )   CREATE RGB>CR , DOES> @ SETBG ;       \ create a text background color

255 255 255 RGB White    255 255 255 RGBF White_FG    255 255 255 RGBB White_BG
  0   0   0 RGB Black      0   0   0 RGBF Black_FG      0   0   0 RGBB Black_BG
224 224 224 RGB LTGRAY                                224 224 224 RGBB LTGRAY_BG
128 128 128 RGB GRAY
255   0   0 RGB LTRED    255   0   0 RGBF LTRED_FG    255   0   0 RGBB LTRED_BG
  0 255   0 RGB LTGREEN    0 255   0 RGBF LTGREEN_FG    0 255   0 RGBB LTGREEN_BG
  0   0 255 RGB LTBLUE     0   0 255 RGBF LTBLUE_FG     0   0 255 RGBB LTBLUE_BG
255 208 208 RGB PINK     255 208 208 RGBF PINK_FG     255 208 208 RGBB PINK_BG
  0 128   0 RGB DKGREEN    0 128   0 RGBF DKGREEN_FG    0 128   0 RGBB DKGREEN_BG
  0   0 192 RGB DKBLUE     0   0 192 RGBF DKBLUE_FG     0   0 192 RGBB DKBLUE_BG
255 255   0 RGB LTYELLOW 255 255   0 RGBF LTYELLOW_FG 255 255   0 RGBB LTYELLOW_BG
  0 255 255 RGB LTCYAN
White

16 CELLS BUFFER: B
 2 VALUE XORG           \ absolute origin of window
 2 VALUE YORG

: reposition    ( b r t l -- b r t l )
   LOCALS| X0 Y0 X1 Y1 |
   Y1 ORGY +  X1 ORGX +
   Y0 ORGY +  X0 ORGX + ;

: Rect          ( bottom right top left -- )
   reposition                           \ relative pels
   HDC_G @ BRUSH SelectObject DROP      \ draw a RECT on the pane using the current brush
   SP@ HDC_G @ SWAP BRUSH FillRect DROP  2DROP 2DROP ;

FUNCTION: GetPixel  ( hdc X Y -- color )

: PEL!  ( color x y -- )
   ROT >R >R >R HDC_G @ R> R> R> SetPixel DROP
;
: PEL@  ( x y -- color )
   HDC_G @ -ROT GetPixel
;

: PELXY         ( X Y -- Y' X' )        \ convert from dialog units to pel units; Note XY reversal
   LOCALS| Y X |
   B  0 !+  0 !+  X !+  Y !+  DROP
   hDlg_G @  B MapDialogRect DROP
   B 2 CELLS + 2@ ;

: RepoXY        ( X Y -- X' Y' )        \ relative to absolute pel units
   SWAP 2DUP reposition 2DROP SWAP ;

: PELX   ( X -- X' )  DUP PELXY NIP ;   \ convert from dialog units to pel units in X
: PELY   ( Y -- Y' )  DUP PELXY DROP ;  \ convert from dialog units to pel units in Y

: P>D    ( x y -- x' y' )               \ convert from pels to dialog units
   8192 DUP PELXY >R >R
   8192 R> */  SWAP
   8192 R> */  SWAP
;

\ Define custom fonts for use by .text

FUNCTION: CreateFont ( H W e o wt it un so cs op cp q p 'face -- HFONT )

FW_SEMIBOLD             VALUE F_WEIGHT
OUT_DEFAULT_PRECIS      VALUE F_OUTPREC
CLIP_DEFAULT_PRECIS     VALUE F_CLIPPREC
ANTIALIASED_QUALITY     VALUE F_QUALITY

: Font"  ( height <name> string" -- ) ( -- )
   CREATE , ," 0 C,
   DOES> @+ SWAP >R                     \ select the new font
   0 0 0 F_WEIGHT                       \ Height Width escapement orientation weight
   0 0 0 0                              \ i u s charset
   F_OUTPREC F_CLIPPREC F_QUALITY 0     \ attributes
   R> CHAR+ CreateFont
   HDC_G @ SWAP SelectObject DROP
;

\ Noto is a very good, free open embeddable font supported by Google.
\ It renders well and won't cause license problems.

FONTHT 6 * Font" H0 Noto Sans"
FONTHT 5 * Font" H1 Noto Sans"
FONTHT 4 * Font" H2 Noto Sans"
FONTHT 3 * Font" H3 Noto Sans"
FONTHT 2*  Font" H4 Noto Sans"
FONTHT 3 2 */ Font" H5 Noto Sans"
FONTHT     Font" H6 Noto Sans"
FONTHT 3 4 */ Font" H7 Noto Sans"
FONTHT 2/  Font" H8 Noto Sans"

: atext         ( X Y addr len -- )     \ paint text at an absolute position
   LOCALS| len addr Y X |               \ positioned in dialog units
   addr len PAD ZPLACE
   HDC_G @ X Y PELXY SWAP  PAD len TextOut DROP ;

: .Text         ( X Y addr len -- )     \ paint text on the currently selected pane
   LOCALS| len addr Y X |               \ positioned in dialog units
   addr len PAD ZPLACE
   HDC_G @  X Y PELXY SWAP  RepoXY  PAD len TextOut DROP ;

FUNCTION: TextOutW                       ( a b c d e -- x )
\ len is a count of 16-bit chars
: .wText        ( X Y addr len -- )     \ paint text on the currently selected pane
   LOCALS| len addr Y X |               \ positioned in dialog units
   HDC_G @  X Y PELXY SWAP  RepoXY  addr len TextOutW DROP ;

\ Define custom pens for use by LineTo and MoveTo

FUNCTION: CreatePen ( style width colorref -- HPEN )

: PEN:  ( width r g b -- )
   CREATE 0 , RGB>CR , ,
   DOES> DUP >R
   @+ DUP IF R> DROP NIP                \ pen is already created
   ELSE DROP                            \ need to create a pen
      2@  PS_SOLID -ROT CreatePen
      DUP R> !
   THEN
   HDC_G @ SWAP SelectObject DROP ;

: LineBegin ( X Y -- )                  \ set the current line position
   RepoXY HDC_G @ -ROT B MoveToEx DROP ;    \ in pels

: LineEnd  ( X Y -- )                   \ draw line to the next endpoint
   RepoXY HDC_G @ -ROT LineTo DROP ;        \ in pels

1  0 0 0 PEN: black_pen                 \ used to draw rectangle outlines
3  0 0 0 PEN: thick_black_pen
1  255 0 0 PEN: red_pen
1  0 128 0 PEN: green_pen
1  0 0 255 PEN: blue_pen
1  0 0 192 PEN: dkblue_pen
1  0 255 255 PEN: cyan_pen
1  255 255 255 PEN: white_pen
1  128 128 128 PEN: gray_pen
1  255 255 192 PEN: mellow_pen
1  255 255 0 PEN: yellow_pen
black_pen

: OUTLINE   ( -- )                      \ draw an outline around the border
   0 0 2DUP LineBegin
   SWAP WIDTH + SWAP  2DUP LineEnd
   HEIGHT +  2DUP LineEnd
   NIP 0 SWAP LineEnd
   0 0 LineEnd
;

: .BMP          ( X Y bitmap-addr -- )
   LOCALS| BMP Y X |                    \ draw a BMP on the pane
   [OBJECTS  BITMAP MAKES BM  OBJECTS]
   BMP  HDC_G @  X ORGX +  Y ORGY +  BM DRAW ;

: CursorXY      ( -- x y )              \ get cursor position relative to current pane
   B GetCursorPos DROP
   B 2@ XORG - ORGX -
   SWAP YORG - ORGY - ;

: ClearPane  ( -- )
   HEIGHT WIDTH 0 0 Rect
;

: InitPane      ( X0 Y0 width height HDC hDlg -- )   \ Initialize the current graphic pane
   hDlg_G !  HDC_G !                    \ save the owner of the graphic context
   LOCALS| H W Y X |
   X Y  PELXY  PANE 2!
   W H  PELXY  PANE 2 CELLS + 2!
   HEIGHT WIDTH 0 0 Rect ;              \ clear the background

: INPANE?       ( pane -- X Y f )       \ cursor is within the given pane?
   SetPane  CursorXY
   OVER 0 WIDTH  WITHIN
   OVER 0 HEIGHT WITHIN AND ;

FUNCTION: StretchBlt ( hdcDest nXOriginDest nYOriginDest nWidthDest nHeightDest hdcSrc nXOriginSrc nYOriginSrc nWidthSrc nHeightSrc dwRop -- b )
FUNCTION: SetStretchBltMode ( hdc mode -- b )
FUNCTION: SetBrushOrgEx ( hdc X Y null -- b )

0 VALUE HALFTONE
0 VALUE MyBMP
FUNCTION: GetBitmapBits ( hbmp cbBuffer lpvBits -- b )

BITMAP SUBCLASS GBITMAP
   PUBLIC
   : PUTBMP  ( X Y bitmap-addr -- )     \ place 1:1 BMP at X,Y
      >R  hDlg_G @ W !  Y !  X !
      W @ GetDC HDC_G !  R> RENDER
      W @ HDC_G @  ReleaseDC DROP
   ;
   : _FITBMP  ( X0 Y0 W H bitmap-addr Wd Hd -- )     \ fit BMP to window
      LOCALS| Hd Wd |
      BMP!  >R >R >R >R
      hDlg_G @ W !  1 1 RepoXY  Y ! X !
      W @ GetDC HDC_G !
      HALFTONE IF
         HDC_G @ HALFTONE SetStretchBltMode DROP  \ use hi-def mode
         HDC_G @ 0 0 0 SetBrushOrgEx DROP         \ MS says do this after setting HALFTONE
      ELSE
         HDC_G @ WHITEONBLACK SetStretchBltMode DROP  \ favor white when shrinking
      THEN
      (BMPHANDLE)
      Palette? IF
         HDC_G @ hPalette @ 0 SelectPalette
         hOldPalette !
         HDC_G @ RealizePalette DROP
      THEN
      HDC_G @ CreateCompatibleDC hMemDC !
      hMemDC @ hBitmap @ SelectObject hOldBitmap !
      HDC_G @ X @ Y @  Wd Hd   hMemDC @  R> R> R> R>  SRCCOPY StretchBlt DROP
      hMemDC @ hOldBitmap @ SelectObject DROP
      Palette? IF
         HDC_G @ hOldPalette @ 0 SelectPalette DROP
      THEN
      hMemDC @ DeleteDC DROP
      Palette? IF  hPalette @ DeleteObject DROP  THEN
      hBitmap @ DeleteObject DROP
      W @ HDC_G @ ReleaseDC DROP
   ;
   : _1:1BMP  ( X0 Y0 bitmap-addr Wd Hd -- )     \ copy BMP to window
      LOCALS| Hd Wd |
      BMP!  2>R
      hDlg_G @ W !  1 1 RepoXY  Y ! X !
      W @ GetDC HDC_G !
      (BMPHANDLE)
      Palette? IF
         HDC_G @ hPalette @ 0 SelectPalette
         hOldPalette !
         HDC_G @ RealizePalette DROP
      THEN
      HDC_G @ CreateCompatibleDC hMemDC !
      hMemDC @ hBitmap @ SelectObject hOldBitmap !
      HDC_G @ X @ Y @  Wd Hd   hMemDC @  2R> SRCCOPY BitBlt DROP
      hMemDC @ hOldBitmap @ SelectObject DROP
      Palette? IF
         HDC_G @ hOldPalette @ 0 SelectPalette DROP
      THEN
      hMemDC @ DeleteDC DROP
      Palette? IF  hPalette @ DeleteObject DROP  THEN
      hBitmap @ DeleteObject DROP
      W @ HDC_G @ ReleaseDC DROP
   ;
   : UNRENDER ( bitmap-addr -- ) BMP!
      (BMPHANDLE)
      HDC_G @ CreateCompatibleDC hMemDC !
      Palette? IF
         hMemDC @ hPalette @ 0 SelectPalette
         hOldPalette !
         hMemDC @ RealizePalette DROP
      THEN
      hMemDC @ hBitmap @ SelectObject hOldBitmap !
      hMemDC @  0 0 32 40  HDC_G @
         0 0 SRCCOPY BitBlt DROP  \ result is "okay"

      \ need to save the hBitmap to a buffer to keep it
      MyBMP 0= IF
         65536 ALLOCATE THROW TO MyBMP
         MyBMP 65536 ERASE                \ output buffer
      THEN
      hBitmap @ 65536 MyBMP GetBitmapBits .  \ not work
      hMemDC @ 65536 MyBMP GetBitmapBits .  \ not work

      hMemDC @ hOldBitmap @ SelectObject DROP
      Palette? IF
         hMemDC @ hOldPalette @ 0 SelectPalette DROP
      THEN
      hMemDC @ DeleteDC DROP
      Palette? IF  hPalette @ DeleteObject DROP  THEN
      hBitmap @ DeleteObject DROP
   ;

END-CLASS

\ fit window of BMP to window pane

: FITBMP  ( X0 Y0 H W bitmap-addr -- )
   [OBJECTS GBITMAP MAKES JOE OBJECTS]
   WIDTH 1-  HEIGHT 1-  JOE _FITBMP ;

: MOVEBMP  ( X0 Y0 bitmap-addr -- )
   [OBJECTS GBITMAP MAKES JOE OBJECTS]
   WIDTH 1-  HEIGHT 1-  JOE _1:1BMP ;

: RAWBMP  (  bitmap-addr -- )
   [OBJECTS GBITMAP MAKES JOE OBJECTS]
   JOE UNRENDER ;

CREATE EMPTYBOILER
   54 c,                            \ boilerplate size
   char B c, char M c,
   54 ,        0 , 54 , 40 ,        \ filesize, reserved4, offset4, headsize
   0 , 0 ,     1 h, 24 h, 0 ,       \ dims=0,0 24-bit color, no compression
   0 ,         2835 , 2835 ,        \ imgsize, resolution
   0 , 0 , 0 , 0 , 0 ,

: BMPBOILER  ( width height addr -- )  \ put a boilerplate on the BMP
   >R EMPTYBOILER COUNT R@  SWAP MOVE  \ default boilerplate
   2DUP * 3 *  DUP R@ 34 + !        \ image size
   54 +  R@ 2 + !                   \ file size
   R@ 22 + !  R> 18 + !             \ height and width
;

\ It would be really nice to copy the HDC_G bitmap onto a smaller BMP.
\ This would avoid the slowness of PEL@.
\ Maybe RAWBMP

4096 BUFFER: EzBMP

: zz  ( -- )
   EzBMP 4096 erase
   EMPTYBOILER COUNT EzBMP  SWAP MOVE
   EzBMP RAWBMP ;

{
\ get screen BMP into a buffer
FUNCTION: GetDIBits ( hdc hbmp uStartScan cScanLines lpvBits lpbi uUsage -- b )

VARIABLE hbmpRAW
64 BUFFER: DIbmpinfo

: GETRAW  ( -- size )
   MyBMP 0= IF
      65536 ALLOCATE THROW TO MyBMP
   THEN
   DIbmpinfo 64 -1 FILL
   32 40 DIbmpinfo BMPBOILER        \ specify color format
   MyBMP 65536 ERASE                \ output buffer

   HDC_G @  DUP  CreateCompatibleDC  DUP >R
   32 40  CreateCompatibleBitmap  DUP hbmpRAW !  \ hdc hbmp
   .s \ seem to have hdc and hbmp here
   >R  0 0 32 40  R> 0 0 SRCCOPY BitBlt . \ report result of bitblt, 0=error


\   2DUP SelectObject h.  \ gives an error
\   0 40  MyBMP DIbmpinfo   DIB_RGB_COLORS
\   GetDIBits ( hdc hbmp uStartScan cScanLines lpvBits lpbi uUsage -- lines )
\   .
   hbmpRAW @ 65536 MyBMP GetBitmapBits .
   HDC_G @ 65536 MyBMP GetBitmapBits .
   R> DeleteDC DROP
;
}


\ Dialog resizing stuff

: RESIZE_GET  ( dlgID -- )          \ load dialog item size and position to PAD
   hDlg_G @ SWAP GetDlgItem
   DUP B GetWindowRect DROP         \ get current X,Y,W,H into B
   DROP
;
: B>XYWH  ( -- X Y W H )            \ dims in dialog units
   B @+ SWAP @+ SWAP @+ SWAP @      ( X0 Y0 X1 Y1 )
   2OVER D-
;
: RESIZE_SET  ( dlgID X Y W H  -- )
   >R >R >R >R
   hDlg_G @ SWAP GetDlgItem
   R> R> R> R>
   TRUE MoveWindow DROP
;
: .RECT  ( dlgID -- )
   RESIZE_GET
   B @+ . @+ . @+ . @ .             \ rectangle dims in pels
;

