	.TITLE	Spare Time Gizmos VT1802 Video Terminal Firmware
	.SBTTL	Bob Armstrong [24-APR-2024]



;     888     888 88888888888 d888   .d8888b.   .d8888b.   .d8888b.  
;     888     888     888    d8888  d88P  Y88b d88P  Y88b d88P  Y88b 
;     888     888     888      888  Y88b. d88P 888    888        888 
;     Y88b   d88P     888      888   "Y88888"  888    888      .d88P 
;      Y88b d88P      888      888  .d8P""Y8b. 888    888  .od888P"  
;       Y88o88P       888      888  888    888 888    888 d88P"      
;        Y888P        888      888  Y88b  d88P Y88b  d88P 888"       
;         Y8P         888    8888888 "Y8888P"   "Y8888P"  888888888  
;
;          Copyright (C) 2024 By Spare Time Gizmos, Milpitas CA.

;++
;   This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
;   This program is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
; for more details.
;
;   You should have received a copy of the GNU General Public License along
; with this program; if not, write to the Free Software Foundation, Inc.,
; 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;--
;0000000001111111111222222222233333333334444444444555555555566666666667777777777
;1234567890123456789012345678901234567890123456789012345678901234567890123456789

	.MSFIRST \ .PAGE \ .CODES

	.NOLIST
	.LIST
	
	.SBTTL	VT1802 Overview

;++
;   The VT1802 is a stand alone serial ASCII terminal based on the CDP1802 CPU
; and the Intel 8275 CRT controller.  The VT1802 generates an 80 column by 24
; or 25 line monochrome text display.  The display scan rate is 15.750kHz
; horizontal and 60Hz vertical with either TTL CGA monochrome or analog CVBS
; RS-170 outputs.
;
;   The VT1802 uses a 7x8, 8x8 or 9x8 pixel character font which is stored in
; an external EPROM.  Up to 256 glyphs can be stored in the EPROM, allowing
; for a full upper and lower case ASCII set plus an number of special symbols.
; In addition, the 8275 can generate simple straight line graphics which are
; fully supported by the VT1802.  And lastly, the 8275 supports several
; character attributes including blinking, strikethru, reverse video and 
; highlight which are also implemented by the VT1802.
;
;   The VT1802 uses a CDP1854 UART and a CDP1863 baud rate generator.  It can
; operate at all standard rates from 110 to 9600bps, and can use either CTS/DTR
; hardware flow control or XON/XOFF software flow control.  A PS/2 keyboard is
; used for input, and an AT89C4051 auxiliary processor decodes the PS/2
; prototocol to generate ASCII key codes.  A second CDP1863 is provided to
; generate audio frequencies to drive a speaker and which can play simple
; musical tunes.
;
;   The VT1802 firmware also contains a copy of the RCA BASIC3 interpreter and
; can operate in local mode as a stand alone BASIC computer.  Up to 24K of RAM
; is available to BASIC for storing programs and data, and programs can be
; uploaded to or downloaded from a host computer over the serial port using the
; XMODEM protocol.  The VT1802 BASIC has been extended to include functions
; that allow input and output to be redirected to either the serial port or to
; the PS/2 keyboard and VT display.
;
;   A BASIC PLAY statement allows playing of simple music using the CDP1863
; sound generator, and the BASIC TIME and WAIT functions keep track of the
; time of day using VRTC interrupts.   And lastly, a BASIC KEY function allows
; for non-blocking console input from either the serial port or PS/2 keyboard.
;--
	.SBTTL	"Revision History"

;++
; 001	-- Start by stealing from the Elf2K project!
;
; 002	-- Steal some code from the VIS1802 and Elf2K video card projects.
;
; 003	-- Missing a call to LDCURS in CRET.
;
; 004	-- LDCURS should disable interrupts while loading the 8275.
;
; 005	-- EOFISR does PUSHR(P1) when it should be PUSHR(T1)!!
;
; 006	-- Eliminate the PS/2 keyboard buffer (the APU already has one).
;
; 007	-- Add TEST command to display a test pattern.
;
; 008	-- Add TERM command to test terminal emulation.
;
; 009	-- Changes for the rev B PC boards.
;	    Add support for the DIP switches to set baud and serial format.
;	    Add support for the CDP1863 baud rate generator.
;
; 010	-- Add CTS and XON/XOFF flow control (stolen from VIS).
;
; 011	-- Add support for CDP1863 sound generator.  Use it for the ^G BELL.
;	    Add music player, identical to the VIS1802.
;
; 012	-- VTPUTC needs to return with DF=0 (otherwise CONPUT will loop!).
;
; 013	-- Implement <ESC>r (reverse video) and <ESC>n (normal video) for
;	    compatibility with the VIS1802.  These are just special cases of
;	    the <ESC>Nx field attribute code.
;
; 014	-- Implement <ESC>l to access the 8275 line drawing attributes.
;
; 015	-- Make the pixel clock and cpu clock assembly options.
;
; 016	-- Adjust the timing parameters for 14.31818MHz to give even more
;	    overscan.  This produces a reasonable image on my LCD TV!
;
; 017	-- Implement <ESC>Z (identify) and Control-E (ENQ).  Both return the
;	    sequence <ESC>/K (VT52 w/o copier).
;
; 018	-- Disable interrupts in SCRUP and SCRDWN while we mess with TOPLIN.
;
; 019	-- Change the ROWEND ISR to test for DMAPTR .GE. SCREND .
;
; 020	-- Make VTPUTC trim all characters, EXCEPT the subsequent bytes of
; 	    escape sequences, to 7 bits.
;
; 021	-- Firmware crashes when we receive a null!  There's a missing
;	    "SEX SP" in VTPUTC.
;
; 022	-- Serial interrupts always set the UART to 8N1 when clearing the TR
;	    bit.  Remember the actual format in SLUFMT and use that instead.
;
; 023	-- Implement TXSBRK and make the terminal emulator transmit a serial
;	    break with the PS/2 BREAK key is pressed.
;
; 024	-- Make the PS/2 MENU key exit from terminal emulation and start the
;	    command scanner.  This works in any mode.
;
; 025	-- Fill the part of the screen after the last displayed character with
;	    i8275 "end of screen stop DMA" control codes.  This helps stop
; 	    screen flicker when there's a lot of serial port interrupts.
;
; 026	-- If flow control is used, SERCLR needs to enable the other end (by
;	    setting CTS or sending an XON).
;
; 027	-- NORMA1 shouldn't do an ANI $7F because WFAC needs it to write field
;	    attribute codes to the screen!
;
; 028	-- Change the default timing for a 14.318MHz pixel clock to use 9 pixels
;           per glyph and to generate 25 rows of text.
;
; 029	-- The 8275 datasheet contains this tidbit - "If the line number of the
;	    underline is greater than 7, then the top and bottom scan lines will
;	    be blanked."  I've no idea what this is good for, but apparently the
;	    8275 really does this.  That means if we have 9 or 10 scan lines per
;	    glyph and we try to put the underline on line 9 or 10, we lose two
;	    rows off our glyphs!  For 9 scanlines per character row and 8 lines
;	    per glyph, that's unbearable!  So change the the underline line to
;	    the middle of the row and call it a strike thru instead!
;
; 030	-- Add a demo of the line drawing functions to the splash screen.
;
; 031	-- Remove CPU clock restrictions, calculate the needed constants.
;
; 032	-- Move screen buffer to top of memory to simplify test for wrap.
;
; 033	-- Remove FRAME counter not being used. UPDATE is the same thing.
;
; 034	-- Check for end of screen and reset the DMAPTR if needed in the
;	     middle of the serial ISR between receive and transmit.
;
; 035	-- Remove DMA burst space to stop flicker. Allow interrupts while
;	     scrolling and speed up scrolling. Reduce time interrupts
;	     disabled in LDCURS. Streamline serial receive and buffer
;	     handling, remove buffer count variable.
;
; 036	-- Fix SCRDWN to erase the correct line. Fix DMA burst setting.
;
; 037	-- Speed improvement in main terminal loop and enable interrupt
;            during cursor load.
;
; 038	-- Add assembly options (CPUCLOCK, PIXELCLOCK, and GLYPHWIDTH) to
;	    splash screen.
;
; 039	-- Align LINTAB to speed up access in critical path. Rewrite the
;	     normal (regular printable) character handling routine to speed
;	     up termianl output.
;
; 040	-- Change LINTAB to LSB first to make arithmetic easier. Remove a
;	     few cycles from EOF ISR. Don't update cursor location when it is
;	     hidden anyway. Separate out core of VTPUTC so that terminal
;	     can skip save and restore of registers.
;
; 041	-- Don't check framing error on UART unless DA is set as it only
;	     changes when a character is received. Cleanup VTPUTT a little.
;	     Make ISR handle multiple events per invocation to reduce latency
;	     and overhead when interrupts happen during interrupts.
;
; 042	-- Major restructuring around the termainal main loop and subroutine
;	     calls for the basic I/O functions, adapting a quick call scheme
;	     for those time critical things. Changed the jump tables from
;	     plain addresses to LBR instructions to avoid need for SEP stuff.
;	     Other changes and restructuring to support this.
;
;--
VEREDT	.EQU	42	; and the edit level
;
; TODO list-
;   Drawing boxes and lines should be easier - maybe some kind of escape
; sequences with (column,row) coordinates for endpoints?
;
;   Still have some annoying flicker when scrolling.  Why?  Is it just
; interrupt latency for the end of row screen wrap around?
;
;   Need escape sequences for playing tones and music (should be compatible
; with the VIS1802!).
;
;   Use some extra RAM (we have lots!) to implement a second text display
; page.  Direct the terminal output to one page and the BASIC output to the
; other, and then use some PS/2 key to flip between them.  
;
;  Implement some simple POST diagnostics at startup?
;
;  Add auto newline <ESC>v and w.
;
;  Distinguish between auto new line and auto line wrap?
;
;  Cleanup the startup code and remove some of the junk commands.
;
;  Expect an 1805 CPU and try to speed up the code by replacing the macros
;    with built-in 1805 instructions, especially RLDI, DBNZ, SCAL, SRET, etc.
;    SCAL/SRET may be problematic with BASIC3...


	.SBTTL	i8275 Video Configuration

MAXCOL	   .EQU	80	; characters displayed per row
CURSORTYPE .EQU  0	; 0->blinking block, 1->blinking underline
			; 2->non-blinking block, 3->non-blinking underline

;   These are the video timing parameters for a 14.31818MHz dot clock, 8 pixels
; per glyph, and an 80x26 display.  This setup gives longer retrace times and
; works better with older, analog, CVBS monitors.  For this timing, set
; MAXROW=26 and HRTCCNT=32.
;
;   The "alternate" 14.31818MHz timing uses 9 pixels per glyph and gives an
; 80x25 display.  This gives a better looking display (more space between the)
; characters) but may not be enough horizontal retrace time for some monitors.
	.IF PIXELCLOCK == 14318180
	.IF GLYPHWIDTH == 9
MAXROW    .EQU	25	; rows displayed per screen
HRTCCNT   .EQU	22	; characters per HRTC
	.ENDIF
	.IF GLYPHWIDTH == 8
MAXROW    .EQU	26	; rows displayed per screen
HRTCCNT   .EQU	32	; characters per HRTC
	.ENDIF
; These parameters are independent of the pixels per glyph ...
VRTCCNT   .EQU	4	; rows per VRTC
SCANLINES .EQU	9	; scan lines per font glyph
UNDERLINE .EQU	5	; scan line for underlining 
	.ENDIF

;   These are the timing parameters for a 12.000MHz dot clock, 8 pixels per
; glyph, and an 80x24 display.  This gives shorter retrace times, but larger
; characters and fills more of the the screen for a real CGA type monitor.
;
;   And like before, there is an "alternate" 12MHz timing that uses 7 pixels
; per glyph for an 80x25 display. This gives very squished together characters,
; but it does give more overscan and longer retrace times.
	.IF PIXELCLOCK == 12000000
	.IF GLYPHWIDTH == 8
MAXROW    .EQU	24	; rows displayed per screen
VRTCCNT   .EQU	2	; rows per VRTC
HRTCCNT   .EQU	16	; characters per HRTC
SCANLINES .EQU	10	; scan lines per font glyph
UNDERLINE .EQU	5	; scan line for underlining 
	.ENDIF
	.IF GLYPHWIDTH == 7
MAXROW    .EQU	25	; rows displayed per screen
VRTCCNT   .EQU	4	; rows per VRTC
HRTCCNT   .EQU	28	; characters per HRTC
SCANLINES .EQU	9	; scan lines per font glyph
UNDERLINE .EQU	5	; scan line for underlining 
	.ENDIF
	.ENDIF

	.SBTTL	VT1802 Hardware Definitions

; Memory layout ...
ROMBASE	 .EQU $0000	   	; EPROM starts at $0000
ROMSIZE  .EQU $8000	   	;  ... and the EPROM is 32K bytes
ROMEND	 .EQU ROMBASE+ROMSIZE-1	;  ... address of the last byte in EPROM
CHKSUM	 .EQU ROMBASE+ROMSIZE-2	; EPROM checksum tored in the last two bytes
BASIC	 .EQU $4000		; BASIC interpreter start address
HLPTXT	 .EQU $7800		; help text stored here in EPROM
RAMBASE	 .EQU $8000	   	; RAM starts at $8000
RAMSIZE  .EQU $8000	   	;  ... 32K of RAM
RAMEND   .EQU RAMBASE+RAMSIZE-1	;  ... address of the last byte in RAM
SCRNSIZE .EQU MAXROW*MAXCOL	; size of display frame buffer (exactly)
DPBASE   .EQU RAMEND-(SCRNSIZE|$FF)-512; our data occupies the last part of RAM

; I/O ports implemented on the VT1802 ...
FLAGS	.EQU	1	; (w/o) flags register
SLUBUF	.EQU	2	; (r/w) CDP1854 UART data register
SLUCTL	.EQU	3	; (w/o) CDP1854 UART control register
SLUSTS	.EQU	SLUCTL	; (r/o) CDP1854 UART status register
DIPSW	.EQU	4	; (r/o) DIP switches
TONE	.EQU	4	; (w/o) CDP1863 tone generator
KEYDATA	.EQU	5	; (r/o) PS/2 keyboard data buffer
SLUBAUD	.EQU	5	; (w/o) CDP1863 baud rate generator
CRTPRM	.EQU	6	; (w/o) CRTC parameter port
CRTCMD	.EQU	7	; (w/o) CRTC command port
CRTSTS	.EQU	CRTCMD	; (r/o) CRTC status port

; Standard EF flag assignments for the VT1802 ...
#define B_CRTIRQ  B1	; branch on CRTC interrupt
#define BN_CRTIRQ BN1	; ...
#define B_SLUIRQ  B2	; branch on SLU interrupt
#define BN_SLUIRQ BN2	; ...
#define B_KEYIRQ  B3	; branch on keyboard interrupt
#define BN_KEYIRQ BN3	; ...
#define B_ROWIRQ  B4	; branch on CRTC row end interrupt
#define BN_ROWIRQ BN4	; ...

; Turn the sound on or off ...
#define SOUND_ON  SEQ	; enable the CDP1863 to drive the speaker
#define SOUND_OFF REQ	; disable ...

; FLAGS register definitions ...
;   The FLAGS register is a single 73HC73 flip flop that implements two control
; bits - CTS, and the CPU OK LED.  Since these are J-K flip flops, any bit can
; be set, reset, or toggled independently of the others.
FL.CCTS	.EQU	$10	; deassert RS-232 clear to send
FL.SCTS	.EQU	$20	; assert     "      "    "   "
FL.LON	.EQU	$40	; CPU OK LED on
FL.LOFF	.EQU	$80	;  "   "  "  off

	.SBTTL	i8275 and CDP1854 Defintions

; i8275 CRTC command bytes ...
CC.REST	.EQU	$00	; reset command
CC.STRT	.EQU	$20	; start display command
CC.STOP	.EQU	$40	; stop display command
CC.LCUR	.EQU	$80	; load cursor command
CC.EI	.EQU	$A0	; enable interrupt command
CC.DI	.EQU	$C0	; disable interrupt command
CC.CPRE	.EQU	$E0	; preset counters command

; i8275 CRTC status register bits ...
CC.IEN	.EQU	$40	; interrupt enable bit
CC.IRQ	.EQU	$20	; interrupt request (end of frame)
CC.LPEN	.EQU	$10	; light pen hit detected
CC.ICMD	.EQU	$08	; improper command
CC.VDEN	.EQU	$04	; video enable
CC.DMAU	.EQU	$02	; DMA underrun
CC.FIFO	.EQU	$01	; FIFO overrun

; i8275 CRTC character codes ...
CC.LINE	.EQU	$C0	; line drawing code
CC.EORS	.EQU	$F1	; end of row, stop DMA
CC.EOSS	.EQU	$F3	; end of screen, stop DMA

; i8275 field attribute codes ...
HLGTATTR .EQU	$81	; highlight
BLNKATTR .EQU	$82	; blink
GPA1ATTR .EQU	$84	; general purpose attribute 1
GPA2ATTR .EQU	$88	;   "  "   "   "    "   "   2
RVIDATTR .EQU	$90	; reverse video
UNDRATTR .EQU	$A0	; strikethru
LINEATTR .EQU	$C0	; line drawing codes

	.SBTTL	CDP1854 and CDP1863 Definitions
	
; CDP1863 baud rate generator definitions ...
;   The CDP1863 is a simple 8 bit programmable "divide by N" counter.  It's
; clocked by a 2.4576Mhz oscillator, and has an built in divide by 16 prescaler.
; Remember that the CDP1854 requires a 16x baud rate clock, so that gives us
; the simple formula DIVISOR = 9600/BAUD - 1 ...
#define BAUD_DIVISOR(b)	((9600/b)-1)

; CDP1854 status register bits ...
SL.THRE	.EQU	$80	; transmitter holding register empty
SL.TSRE	.EQU	$40	; transmitter buffer register empty
SL.PSI	.EQU	$20	; peripheral status interrupt
SL.ES	.EQU	$10	; extra status (RTS on the SBC1802)
SL.FE	.EQU	$08	; framing error
SL.PE	.EQU	$04	; parity error
SL.OE	.EQU	$02	; overrun error
SL.DA	.EQU	$01	; received data available

; CDP1854 control register bits ...
SL.TR	.EQU	$80	; transmit request (unused on SBC1802)
SL.BRK	.EQU	$40	; set to force transmit break
SL.IE	.EQU	$20	; interrupt enable
SL.WL2	.EQU	$10	; select number of data bits (5..8)
SL.WL1	.EQU	$08	;   "      "     "   "    "
SL.SBS	.EQU	$04	; set to select 1.5/2 stop bits
SL.EPE	.EQU	$02	; set for even parity
SL.PI	.EQU	$01	; set to inhibit parity
SL.8N1	.EQU	SL.WL2+SL.WL1+SL.PI	; select 8N1 format
SL.7E1	.EQU	SL.WL2+SL.EPE		; select 7E1 format

; Special ASCII control characters that get used here and there...
CH.NUL	.EQU	$00	; control-shift-@
CH.CTC	.EQU	$03	; control-C (abort command)
CH.BEL	.EQU	$07	; control-G (ring bell)
CH.BSP	.EQU	$08	; control-H (backspace)
CH.TAB	.EQU	$09	; control-I (horizontal tab)
CH.LFD	.EQU	$0A	; control-J (line feed)
CH.FFD	.EQU	$0C	; control-L (form feed)
CH.CRT	.EQU	$0D	; control-M (carriage return)
CH.CTO	.EQU	$0F	; control-O (suppress output)
CH.XON	.EQU	$11	; control-Q (resume output)
CH.CTR	.EQU	$12	; control-R (retype input)
CH.XOF	.EQU	$13	; control-S (pause output
CH.CTU	.EQU	$15	; control-U (erase input)
CH.ESC	.EQU	$1B	; control-[ (escape)
CH.DEL	.EQU	$7F	; rubout (delete)

; XMODEM protocol special characters ...
CH.SOH	.EQU	$01	; start of a data block
CH.EOT	.EQU	$04	; end of file
CH.ACK	.EQU	$06	; packet received OK
CH.NAK	.EQU	$15	; packet not OK - retransmit
CH.SUB	.EQU	$1A	; filler for partial data blocks

	.SBTTL	Software Configuration

; Configuration options ...
HERTZ	  .EQU	60	; VRTC interrupt frequency
CMDMAX	  .EQU	64	; maximum command line length
BELLTIME  .EQU  HERTZ/2	; delay (in VRTC ticks) for ^G bell

; Buffer size definitions ...
;   Be sure to read the comments in the circular buffer routines and on the
; page where the buffers are allocated before you change these!  They aren't
; arbitrary values!
RXBUFSZ	 .EQU	 64	; serial port receiver buffer size
RXSTOP	 .EQU	 48	;  ... send XOFF/clear CTS when RXBUF has .GE. 48 chars
RXSTART	 .EQU	 16	;  ... send XON/assert CTS when RXBUF has .LE. 16 chars
TXBUFSZ	 .EQU	 32	; serial port transmitter buffer size
KEYBUFSZ .EQU    16	; PS/2 keyboard buffer size

; XMODEM protocol constants ..
XDATSZ	.EQU	128	; data (payload) size in XMODEM record
XPKTSZ	.EQU	XDATSZ+5; overall XMODEM packet size (header+data)
XTIMEO	.EQU	5000	; protocol timeout, in 2ms units (10s)

;   Special key codes sent by the PS/2 APU whenever function, arrow, keypad,
; or other special keys are pressed.  There are actually a lot of these, but
; most are just translated to VT52 escape sequences.  These are just the ones
; we handle specially.
KEYBREAK .EQU	$80	; PAUSE/BREAK key
KEYMENU	 .EQU	$95	; MENU key
KEYUP	 .EQU	$90	; UP ARROW key
KEYDOWN	 .EQU	$91	; DOWN ARROW key
KPENTER	 .EQU	$AF	; KEYPAD ENTER key
KEYVERS  .EQU	$C0	; mask for APU version number

; Standard register mnemonics ...
PC0	.EQU	0	; PC register for initialization
DMAPTR	.EQU	0	; register used for DMA
INTPC	.EQU	1	; PC register for interrupt service
SP	.EQU	2	; stack pointer
PC	.EQU	3	; normal PC register after startup
CALLPC	.EQU	4	; PC register dedicated to the CALL routine
RETPC	.EQU	5	; PC register dedicated to the RETURN routine
A	.EQU	6	; call linkage register
;   Note that the registers BASIC does NOT need preserved are RA, RC, RD
; and RE.  The assignments below are selected so that those correspond to
; our T1, P1, P2 and P3 (although not necessarily in that order!) ...
T1	.EQU	$A	; the first of 4 temporary registers
T2	.EQU	8	;  "  second " "   "   "     "   "  
T3	.EQU	9	;  "  third  " "   "   "     "   "  
T4	.EQU	7	;  "  fourth " "   "   "     "   "
P1	.EQU	$E	; first of 3 parameter/permanant registers
P2	.EQU	$D	; second " "	"		"
P3	.EQU	$C	; third  " "	"		"
P4	.EQU	$B	; and fourth...
AUX	.EQU	$F	; used by SCRT to preserve D

	.SBTTL	"General Macros"

; Advance the current origin to the next page...
#define PAGE		.ORG ($ + $FF) & $FF00

; Return the high and/or low bytes of a 16 bit value...
#define HIGH(X)		(((X)>>8) & $FF)
#define LOW(X)		( (X)     & $FF)

; Make a 16 bit word out of two 8 bit bytes ...
#define WORD(x)		((x) & $FFFF)
#define MKWORD(H,L)	((H)<<8) | (L))

; Macros for some common BIOS functions...
#define OUTSTR(pstr)	RLDI(P1,pstr)\ CALL(TSTR)
#define OUTCHR(c)	LDI c\ CALL(TCHAR)

;   INLMES() simply prints out an ASCII string "in line", which saves us the
; trouble of defining a label and a .TEXT constant for OUTSTR().  The catch
; is that TASM HAS A 16 CHARACTER LIMIT ON THE LENGTH OF A MACRO ARGUMENT!
; That's not many when it comes to messages, so use INLMES with caution...
#define	INLMES(str)	CALL(TMSG)\ .TEXT str \ .BYTE 0

;   Annoyingly, the 1802 has no instructions to explicitly set or clear the
; DF flag which, since we often use that as a way to return a true/false result,
; would have been really handy!  To fix that, we'll invent our own.  Note that
; these do not actually change the current contents of D!
#define CDF	ADI 0
#define SDF	SMI 0

;   The standard assembler defines the mnemonics BL (branch if less), BGE
; (branch if greater or equal), etc.  These all simply test the DF flag and
; are normally used after a subtract operation.  These are all short branches
; however, and while there are equivalent long branch instructions that also
; test DF, those don't have these same mnemonics.  Let's fix that...
#define LBPZ	LBDF
#define LBGE	LBDF
#define LSGE	LSDF
#define LBM	LBNF
#define LBL	LBNF
#define LSL	LSNF

;   This macro delays for 2 ms which is calculated from the clock frequency.
; Since each loop of the delay takes two instructions, which is eight machine
; cycles, we multiply this times 2000 which is the number of microseconds in
; 2 ms giving 16000 as the divisor.  Unfortunately this doesn't work when the
; CPUCLOCK is > 4Mhz because the delay constant would exceed 255.  In that
; case we divide by 32000 and repeat the loop twice.  That also doubles the
; roundoff error, but this is pretty non-critical.
	.IF	(CPUCLOCK <= 4000000)
DLYCONS	.EQU	CPUCLOCK/16000
#define DLY2MS	LDI DLYCONS\ SMI 1\ BNZ $-2
	.ELSE
DLYCONS	.EQU	CPUCLOCK/32000
#define DLY2MS	LDI DLYCONS\ SMI 1\ BNZ $-2\ LDI DLYCONS\ SMI 1\ BNZ $-2
	.ENDIF

; Enable and disable interrupts (P = PC) ...
#define ION	SEX PC\ RET\ .BYTE (SP<<4) | PC
#define IOFF	SEX PC\ DIS\ .BYTE (SP<<4) | PC

;   This macro does the equivalent of an "OUT immediate" instruction with the
; specified port and data.  It assumes the P register is set to the PC.
#define	OUTI(p,n)	SEX PC\ OUT p\ .BYTE n

; Standard subroutine call and return macros...
#define CALL(ADDR)	SEP CALLPC\ .WORD ADDR
#define RETURN		SEP RETPC

; Quick subroutine call macro...
#define QCALL(ADDR)	LDI LOW($)+5\ LBR ADDR
#define QRETURN		INC SP\ LDN SP\ PLO PC

;   Push or pop the D register from the stack.  Note that POPD assumes the SP
; is in the usual position (pointing to a free byte on the TOS) and it does the
; IRX for you!  That's because 1802 stack operations are BOTH pre-increment AND
; pre-decrement, which doesn't work out so well. 
#define PUSHD		STXD
#define POPD		IRX\ LDX

	.SBTTL	16 Bit Register Operations

;   Register load immedate.  RLDI is exactly equivalent to the 1805 instruction
; by the same name.
#define RLDI(R,V)	LDI HIGH(V)\ PHI R\ LDI LOW(V)\ PLO R
#define RLDI2(R,H,L)	LDI (H)\ PHI R\ LDI (L)\ PLO R

; Clear a register...
#define RCLR(R)		LDI $00\ PHI R\ PLO R

;   Register load via pointer.   RLXA is exactly equivalent to the 1805
; instruction by the same name, but there is no equivalent for RLDA.
#define RLDA(R,N)	LDA N\ PHI R\ LDA N\ PLO R
#define RLXA(R)		LDXA \ PHI R\ LDXA \ PLO R

;   Copy the 16 bit source register to the destination. Note that the closest
; equivalent 1805 operation would be RNX - copy register N to register X.
; Unfortunately the 1802 has no "PLO X" or "PHI X" operation, so there's no way
; to emulate that exactly.
#define RCOPY(D,S)	GHI S\ PHI D\ GLO S\ PLO D

;   Push a 16 bit register on the stack.  Note that RSXD and PUSHR are exactly
; the same - the PUSHR mnemonic is just for convenience.
#define RSXD(R)		GLO R\ STXD\ GHI R\ STXD
#define PUSHR(R)	RSXD(R)

;   Pop a 16 bit register from the stack.  Note that POPR is exactly the same
; as RLXA - the POPR mnemonic is just for convenience.  Unfortunately the 1802
; stack operations are BOTH pre-increment and pre-decrement, which doesn't work
; out so well.  POPR/RLXA always needs to be preceeded by an IRX, and also the
; LAST pop operation needs to do an LDX rather than LDXA (or else you need to
; stick a DEC SP in there somewhere).  That's why POPRL exists.
#define POPR(R)		RLXA(R)
#define POPRL(R)	LDXA\ PHI R\ LDX\ PLO R

; Decrement register and branch if not zero ...
#define DBNZ(R,A)	DEC R\ GLO R\ LBNZ A\ GHI R\ LBNZ A

; Shift a sixteen bit register left 1 bit (with or w/o carry in) ...
#define RSHL(R)		GLO R\ SHL\  PLO R\ GHI R\ SHLC\ PHI R
#define RSHLC(R)	GLO R\ SHLC\ PLO R\ GHI R\ SHLC\ PHI R

; Shift a sixteen bit register right 1 bit (with or w/o carry in) ...
#define RSHR(R)		GHI R\ SHR\  PHI R\ GLO R\ SHRC\ PLO R
#define RSHRC(R)	GHI R\ SHRC\ PHI R\ GLO R\ SHRC\ PLO R

; Double precision add register S to register D (i.e. D = D + S) ...
#define DADD(D,S)	GLO D\ STR SP\ GLO S\ ADD\ PLO D\ GHI D\ STR SP\ GHI S\ ADC\ PHI D

; Double precision subtract register S from register D (i.e. D = D - S) ...
#define DSUB(D,S)	GLO S\ STR SP\ GLO D\ SM\  PLO D\ GHI S\ STR SP\ GHI D\ SMB\ PHI D

	.SBTTL	RAM Storage Map

;++
;   This page defines all the RAM locations we use.  It's important that the
; only thing you put here are .BLOCK statements and not any actual code or
; data, because the .HEX file generated by assembling this file gets programmed
; into the EPROM and any RAM addresses would be outside that.  If you want any
; RAM locations initialized to non-zero values then you'll have to put code
; in SYSINI to do that.
;
;   Even though we have a full 32K RAM available to us, we really only need
; a small chunk of that.  We'd like to jam our memory up against the top end
; of RAM so that the part from $8000 and up can be used by BASIC or whatever
; other interesting things we have in EPROM.
;
;   Lastly, note that BASIC3 sets its "RAMTOP" to $F500-1, and so our DPBASE
; cannot be less than that (unless you fix BASIC too!).
;--
	.IF	DPBASE < $F500
	.ECHO	"**** DPBASE TOO LOW - FIX BASIC! *****\n"
	.ENDIF
	.ORG	DPBASE

; Other random VT52 emulator context variables...

;   WARNING!! DO NOT CHANGE THE ORDER OF THE FIVE VARIABLES IN THIS BLOCK!
; The code DEPENDS on these bytes being in this particular order!!!
;
; A note about VISCUR in particular... this byte is a flag that is zero if
; the cursor should be hidden, or CC.LCUR if it should be visible. The true
; value is because the block of the three bytes [VISCUR, CURSX, CURSY] are
; output to the 8275 in sequence to set the cursor position.
;
ACSMOD:	.BLOCK	1	; zero for normal character set else alternate
TOPLIN: .BLOCK	1	; number of the top line on screen (0 to MAXROW-1)
VISCUR:	.BLOCK	1	; zero to hide the cursor else CC.LCUR to show
CURSX:	.BLOCK	1	; the column number of the cursor (0 to MAXCOL-1)
CURSY:	.BLOCK	1	; the row number of the cursor (0 to MAXROW-1)

; DON'T CHANGE THE GROUPING OF ESCSTA, CURCHR and SAVCHR!!
ESCSTA:	.BLOCK	1	; current ESCape state machine state
CURCHR:	.BLOCK	1	; character we're trying to output
SAVCHR:	.BLOCK	1	; save one character for escape sequences

; Other variables ...
TTIMER:	.BLOCK	1	; timer for tones and ^G bell beeper
SERBRK:	.BLOCK	1	; serial port break flag
UPTIME:	.BLOCK	4	; total time (in VRTC ticks) since power on
SLUFMT:	.BLOCK	1	; serial port format (8N1 or 7E1)

; Flags from the keyboard input routine ...
; DON'T CHANGE THE ORDER OR GROUPING OF THESE!!
KEYVER:	.BLOCK	1	; keyboard APU firmware version
KEYBRK:	.BLOCK	1	; non-zero if the BREAK key was pressed
KEYMNU:	.BLOCK	1	; non-zero if the MENU key was pressed
KPDALT:	.BLOCK	1	; 0 for numeric keypad, 0xFF for application
KEYPBK:	.BLOCK	2	; "push back" buffer for escape sequences

;   These two locations are used for (gasp!) self modifying code.  The first
; byte gets either an INP or OUT instruction, and the second a "SEP PC".  The
; entire fragment runs with T1 as the program counter and is used so that
; we can compute an I/O instruction to a variable port address...
IOT:	.BLOCK	3

;   These are temporary locations used by the XMODEM transmit and receive
; routines, and in order to save RAM space we share them with the TIMBUF
; above.  Note that the order of these four locations is critical, so don't
; change that!
XINIT:	.BLOCK	1	; send initial ACK or NAK for XRDBLK
XBLOCK:	.BLOCK	1	; current XMODEM block number
XCOUNT:	.BLOCK	1	; current XMODEM buffer byte count
XDONE:	.BLOCK	1	; non-zero when we receive EOT from the host

;   These are the GET and PUT pointer pairs for the UART transmitter. These
; must remain together, and in this order, GET first then PUT.
TXGETP:	.BLOCK	1	; serial port transmitter buffer pointers 
TXPUTP:	.BLOCK	1	; ...

;   These bytes are used for managing the UART receiver. First are the GET
; and put pointers for the circular buffer. FLOCTL determines if flow control
; is enabled, and TXONOF is used for XON/XOFF flow control.  These bytes MUST
; AL BE TOGETHER and in this exact order!
RXGETP:	.BLOCK	1	; serial port receiver buffer pointers
RXPUTP:	.BLOCK	1	; ...
FLOCTL:	.BLOCK	1	; flow control mode: $01->CTS, $FF->XON/XOFF, 0->none
TXONOF:	.BLOCK	1	; $00 -> receiving normally, $01 -> transmit XON
			; $FF -> transmit XOFF, $FE -> XOFF transmitted

;   These are the GET and PUT pointer pairs for the keyboard buffer.
KEYGETP:.BLOCK	1	; and keyboard buffer pointers
KEYPUTP:.BLOCK	1	; ...

;   These locations are used by the TRAP routine to save the current context.
; Note that the order of these bytes is critical - you can't change 'em without
; also changing the code at TRAP:...
SAVEXP:	.BLOCK	1	; saved state of the user's X register
SAVED:	.BLOCK	1	;   "    "    "   "    "    D    "
SAVEDF:	.BLOCK	1	;   "    "    "   "    "    DF   "
REGS:	.BLOCK	16*2	; All user registers after a breakpoint

; These locations are used by the music player ...
; DON'T CHANGE THE ORDER OR GROUPING OF THESE!!
OCTAVE:	.BLOCK	1	; 0->MIDDLE C, $01->up one octave, $FF->down one octave
TEMPO:	.BLOCK	1	; duration (in ticks) of a quarter note
NOTIME:	.BLOCK	1	; current note duration

;   The CONGET and CONPUT locations contain an LBR to either the SERGET/PUT 
; or VTPUTC/GETKEY routines.  Likewise, CONBRK tests the console break flag
; and should point to either the ISSBRK or ISKBRK routines.  Lastly, CONECHO
; is used by the CONGET routine to echo user input.  These vectors are used
; by this monitor for all console I/O, and storing them in RAM allow us to
; redirect the console to either the serial port or the PS/2 keyboard and
; video display.  
;
; DON'T CHANGE THE ORDER OR GROUPING OF THESE!!
CONGET:	.BLOCK	3	; contains an LBR to SERGET or GETKEY
CONECHO:.BLOCK	3	; contains an LBR to the input echo routine
CONBRK:	.BLOCK	3	; contains an LBR to ISSBRK or ISKBRK
CONPUT:	.BLOCK	3	; contains an LBR to SERPUT or VTPUTC

; Command line buffer...
CMDBUF:	.BLOCK	CMDMAX+1; buffer for a line of text read from the terminal

;++
;   We place our stack at the end of this RAM page and then let it grow
; downward from there.  Whatever you do, it's important that we leave here
; exactly page aligned, so that the buffers on the next page can start on a
; power of two address.  Read the buffer comments to see why!
;
;   We then figure out how many bytes are left between the last variable and
; the end of this page, and that's the stack size.  Double check that it's
; enough. What's enough? That's pretty arbitrary but we make an educated guess.
;--
STACK	.EQU	(($+$FF) & $FF00) - 1	; top of this firmware's stack
STKSIZE	.EQU	STACK-$			; space allocated for that stack
	.ECHO	"STACK SIZE "\ .ECHO STKSIZE\ .ECHO " BYTES\n"
	.IF (STKSIZE < 64)
	.ECHO	"**** NOT ENOUGH ROOM FOR THE STACK! *****\n"
	.ENDIF
	.ORG	STACK+1


;++
;   Thexe are the circular buffers used by the interrupt service routines.
; All in all, there are three such buffers -
;
;	TXBUF	- characters waiting to be transmitted via the serial port
;	RXBUF	- characters received from the serial port
;	KEYBUF	- data received from the PS/2 keyboard
;
;   One might ask why we need a KEYBUF, because a) data received from the
; keyboard goes directly to the serial port TXBUF, and b) the PS/2 APU chip has
; a built in buffer anyway.  It's because we want to be able to "look ahead"
; and detect keys like MENU, SETUP or BREAK when running BASIC (or perhaps when
; the UART is transmitting at a slow baud rate).
;
;   IMPORTANT!   To make life and coding easier, and faster for the ISRs, on
; the 1802 (which is not the smartest MCU around, after all) these buffers
; have several restrictions!
;
;   1) The ??GETP and ??PUTP pointers are indices, relative to the buffer
;      base, of the next character for the GET and PUT routines, respectively.
;      If the GETP equals the PUTP before a GET then the buffer is empty, and
;      if after incrementing the PUTP it would equal the GETP for a GET, then
;      the buffer is full!
;
;   2) Buffer sizes must always be a power of two, and not more than 256.  So
;      16, 32, 64, 128 or 256 are the only practical and reasonable sizes.
;      This allows us to handle GETP/PUTP wrap around with a simple AND.
;
;   3) The actual buffers must be aligned on a natural boundary; for example,
;      a 64 byte buffer must be aligned on a 64 byte boundary (i.e. such that
;      the lower 6 bits of the buffer address are zeros).  This allows us to
;      index into the buffer without having to worry about carry operations.
;
;   4) The order of the GETP/PUTP pointers for each buffer can't change.
;      It's always GET pointer first, then PUT pointer.
;
;   5) The RAM initialization code in the startup sets all these values to
;      zero.  For the GET/PUT pointers, that's an empty buffer (perfect!).
;--
	.IF (($ & $FF) != 0)
	.ECHO	"***** CIRCULAR BUFFERS NOT PAGE ALIGNED! *****\n"
	.ENDIF
RXBUF:	.BLOCK	RXBUFSZ		; then RXBUF (64 bytes) is next
TXBUF:	.BLOCK	TXBUFSZ		; and finally TXBUF (32 bytes)
KEYBUF:	.BLOCK	KEYBUFSZ	; and KEYBUF (32 bytes)


;++
;   This is the buffer used by the XMODEM protocol and is always 128 bytes
; of payload plus 4 overhead bytes (three header bytes and a checksum).
; Unlike the circular buffers above it doesn't require any special kind of
; alignment, however we are careful to arrange the total size of this buffer
; plus the circular buffers so that they'll all fit in one 256 byte page.
;
;   BTW, needless to say, this part of RAM CANNOT BE UPLOADED OR DOWNLOADED!
;--
XHDR1:	.BLOCK	1		; received SOH or EOT
XHDR2:	.BLOCK	1		; received block number
XHDR3:	.BLOCK	1		; received "inverse" block number
XBUFFER:.BLOCK	XDATSZ		; 128 bytes of received data
XHDR4:	.BLOCK	1		; received checksum

	.IF ($ > (RAMEND-SCRNSIZE))
	.ECHO	"**** TOO MANY RAM BYTES - ADJUST DPBASE *****\n"
	.ENDIF


;   This is the ASCII frame buffer and contains all the characters on the
; screen at the moment.  The row refresh ISR loads data directly into the 8275
; from here.  Note that there is a table at LINTAB: which must contain at least
; MAXROW entries.  If you change MAXROW, it might be a good idea to check that
; table too!
;
;   The frame buffer is sized to the exact number of characters on the screen
; and placed against the top of memory. This way the end of the screen can be
; tested for because the MSB of the pointer will be zero. This will especially
; help to streamline the end-of-row interrupt reset for wrapping the display.
	.ORG	RAMEND-SCRNSIZE+1
SCREEN:	.BLOCK	SCRNSIZE		; the whole screen lives here!

	.SBTTL	Startup and BASIC Vectors

;++
;   This code gets control immediately after a hardware reset, and contains
; the initial startup code and copyright notice.  We just disable interrupts
; and load the PC (R3) with the address of the SYSINI code, and branch there.
; Note that the hardware resets the CPU OK LED to off, and that'll stay off
; until we finish initialization.
;--
	.ORG	ROMBASE		; the VT1802 EPROM is mapped here
	DIS\ .BYTE $00		; disable interrupts (just in case!)
	RLDI(PC, SYSINI)	; switch to P=3
	SEP	PC		; and go start the self test/initialization


;++
;   Address $000F in the EPROM contains a count (always negative) of the
; number of entry vectors defined, and then the table of entry vectors starts
; at address $0010.  Every vector is three bytes and contains an LBR to
; the appropriate routine.  This table is used by BASIC, or whatever other
; code is stored in the EPROM, to call terminal routines.
;--
	.ORG	ROMBASE+$000F
	.BYTE	-23		; number of entry vectors
	LBR	SCALL		;  0 - our standard call routine
	LBR	SRETURN		;  1 - our standard return routine
	LBR	TRAP		;  2 - breakpoint trap
	LBR	TCHAR		;  3 - send characters to the console
	LBR	INCHRW		;  4 - read keystrokes from the keyboard
	LBR	CONBRK		;  5 - check for console BREAK key
	LBR	SERPUT		;  6 - get character from serial port
	LBR	SERGET		;  7 - send character to serial port
	LBR	ISSBRK		;  8 - test for serial framing error
	LBR	TIN		;  9 - redirect console input to PS/2 keyboard
	LBR	TOUT		; 10 - redirect console output to video display
	LBR	SIN		; 11 - redirect console input to serial port
	LBR	SOUT		; 12 - redirect console output to serial port
	.IF (BASIC != 0)
	LBR	RSTIO		; 13 - restore console redirection
	LBR	BSAVE		; 14 - save BASIC program/data with XMODEM
	LBR	BLOAD		; 15 - load BASIC program/data with XMODEM
	LBR	BEXIT		; 16 - re-enter monitor
	LBR	TRAP		; 17 - switch between text and graphics modes
	LBR	TRAP		; 18 - plot a single point in graphics mode
	LBR	TRAP		; 19 - draw a line in graphics mode
	LBR	BPLAY		; 20 - play music
	LBR	BKEY		; 21 - test for a keypress
	LBR	BWAIT		; 22 - delay for a number of ticks
	LBR	BTIME		; 23 - return current UPTIME
	.ENDIF

	.SBTTL	Copyright and System Information

;   This macro will convert a 3 digit decimal number, 0..999, into three
; ASCII characters with leading zeros.  It's crude, but it works!
#define TODEC(x)	.BYTE '0'+((x)%10)
#define	TODEC3(x)	.BYTE '0'+((x/100)%10), '0'+((x/10)%10), '0'+(x%10)

;++
;   The firmware version, name, copyright notice and date all live here.  These
; strings should appear at or near to the beginning of the EPROM, because we
; don't want them to be hard to find, after all!
;--
SYSNAM:	.TEXT	"SPARE TIME GIZMOS VT1802 V"
	.BYTE	'0'+(VEREDT/100)
	.BYTE	'0'+((VEREDT/10)%10)
	.BYTE	'0'+(VEREDT%10)
	.BYTE	0
	.INCLUDE "sysdat.asm"
RIGHTS1:.TEXT	"Copyright (C) 2024 Spare Time Gizmos.\000"
RIGHTS2:.TEXT	" All rights reserved\000"
	.IF (BASIC != 0)
BRIGHTS:.TEXT	"RCA BASIC3 V1.1 BY Ron Cenker\000"
	.ENDIF

;   We've accumulated a lot of assembly options - different CPU clocks, pixel
; clocks, and font sizes.  It causes a lot of problems when run the software
; with one set of options on hardware that's built a different way.  Let's
; embed all the configuration options in here so we can at least tell how
; this EPROM image was assembled.
SYSOPT:	.TEXT	"CPU Clock "
	.BYTE	'0'+(CPUCLOCK/1000000)
	.TEXT	"."
	TODEC3((CPUCLOCK/1000) % 1000)
	.TEXT	"MHz Pixel Clock "
;   Yes, you'd like to use TODEC here, but it doesn't work!  There's some
; kind of bug in TASM that makes it give the wrong results.  Sorry
	.BYTE	'0'+(PIXELCLOCK/10000000)
	.BYTE	'0'+((PIXELCLOCK/1000000)%10)
	.TEXT	"."
	TODEC3((PIXELCLOCK/1000) % 1000)
	.TEXT	"MHz "
	TODEC(GLYPHWIDTH)
	.TEXT	" pixels/glyph\000"

	.SBTTL	Hardware Initializtion

;++
;   This is the hardware initialization after a power up or reset.  The first
; thing is to initialize the RAM contents, and then set up the stack and
; SCRT registers to we can call subroutines.  After that we initialize the
; CDP1854 UART, CDP1863 baud rate generator, PS/2 keyboard, and then finally
; the i8275 CRT controller.  The very last step is to initialize the DMA and
; interrupt registers and enable interrupts.
;--
SYSINI:	SOUND_OFF		; just in case

; Zero everything in RAM ...
	RLDI(T1,RAMEND)\ SEX T1	; start from the top of RAM and work down
RAMIN1:	LDI 0\ STXD\ GHI T1	; zero another byte
	XRI	HIGH(RAMBASE)-1	; have we done everything down to $8000?
	LBNZ	RAMIN1		; loop until we roll over from $8000 -> $7FFF

; Initialize the standard call/return technique ...
	RLDI(SP,STACK)
	RLDI(CALLPC,SCALL)	; initialize the CALLPC and ...
	RLDI(RETPC,SRETURN)	;  ... RETPC registers ...

; Initialize the hardware ...
	CALL(SERINI)		; initialize the CDP1854 and CDP1863
	CALL(VTINI)		; initialize the i8275 display
	RLDI(INTPC,ISR)		; point R1 to the interrupt service code
	ION			; take a a big leap of faith!

	CALL(TOUT)		; output to terminal temporarily
	INLMES("\007\014\033d")	; ring bell, clear screen, show cursor

	CALL(DSPON)		; turn the 8275 video on
	OUTI(FLAGS,FL.LON)	; turn the CPU OK LED OM

				; and fall into the software startup next

	.SBTTL	Software Initialization

;++
;--
	CALL(RSTIO)		; select the correct console device

; Display the splash screen if requested ...
	SEX SP\ INP DIPSW	; read the switches
	SHL\ LBNF SYSIN2	; skip this if no splash screen requested

;  Display the splash screen.  Note that this routine will return whenever any
; input is received from either the keyboard or the serial port!
	CALL(SPLASH)		; ...

; Now figure out whether we start in BASIC or terminal mode ...
SYSIN2:	SEX SP\ INP DIPSW	; read the switches again
	SHL\ SHL\ LBDF SYSIN3	; SW7 selects BASIC startup
	LBR	TERM		; startup the terminal emulator instead ...

; Print the system name, firmware and BIOS versions, and checksum...
SYSIN3:	CALL(TCRLF)		; ...
	OUTSTR(SYSNAM)		; "VT1802 FIRMWARE"
	INLMES(" CHECKSUM ")	; and the EPROM checksum
	RLDI(P1,CHKSUM)		; stored here by the romcksum program
	SEX P1\ RLXA(P2)	; ...
	CALL(THEX4)		; type that in HEX
	CALL(TCRLF)		; that's all for this line
	OUTSTR(RIGHTS1)		; then print the copyright notice
	OUTSTR(RIGHTS2)		; ...
	.IF	(BASIC != 0)
	CALL(TCRLF)		; ...
	OUTSTR(BRIGHTS)		; print the BASIC copyright notice toe
	.ENDIF
	CALL(TCRLF)		; ...
	OUTSTR(SYSOPT)		; print the assembly options used here
	CALL(TCRLF)\ CALL(TCRLF); ...

; If BASIC isn't installed, then just fall into the command scanner!
	.IF	(BASIC != 0)
	LBR	BASIC		; start up BASIC and we're done
	.ENDIF

	.SBTTL	Command Scanner

;++
;   This is the monitor main loop - it prints a prompt, scans a command,
; looks up the command name, and then dispatches to the appropriate routine.
;--
MAINTE:	OUTSTR(TEMSG)		; print a message if entering from terminal

MAIN:	RLDI(CALLPC,SCALL)	; reset our SCRT pointers, just in case
	RLDI(RETPC,SRETURN)	; ...
	RLDI(SP,STACK)\ SEX SP	; reset the stack pointer to the TOS

; Print the prompt and scan a command line...
	INLMES(">>>")		; print our prompt
	RLDI(P1,CMDBUF)		; address of the command line buffer
	RLDI(P3,CMDMAX)		; and the length of the same
	CALL(READLN)		; read a command line
	LBDF	MAIN		; branch if the line was terminated by ^C

;   Parse the command name, look it up, and execute it.  By convention while
; we're parsing the command line (which occupies a good bit of code, as you
; might imagine), P1 is always used as a command line pointer...
	RLDI(P1,CMDBUF)		; P1 always points to the command line
	CALL(ISEOL)		; is the line blank???
	LBDF	MAIN		; yes - just go read another
	RLDI(P2,CMDTBL)		; table of top level commands
	CALL(COMND)		; parse and execute the command
	LBR	MAIN		; and the do it all over again


;   This routine will echo a question mark, then all the characters from
; the start of the command buffer up to the location addressed by P1, and
; then another question mark and a CRLF.  After that it does a LBR to MAIN
; to restart the command scanner.  It's used to report syntax errors; for
; example, if the user types "BASEBALL" instead of "BASIC", he will see
; "?BASE?"...
CMDERR:	LDI	$00		; terminate the string in the command buffer
	INC	P1		; ...
	STR	P1		; at the location currently addressed by P1
;   Enter here (again with an LBR) to do the same thing, except at this
; point we'll echo the entire command line regardless of P1...
ERRALL:	CALL(TQUEST)		; print a question mark
	OUTSTR(CMDBUF)		; and whatever's in the command buffer
	CALL(TQUEST)		; and another question mark
	CALL(TCRLF)		; end the line
	LBR	MAIN		; and go read a new command

	.SBTTL	Lookup and Dispatch Command Verbs

;++
;   This routine is called with P1 pointing to the first letter of a command
; (usually the first thing in the command buffer) and P2 pointing to a table
; of commands.  It searches the command table for a command that matches the
; command line and, if it finds one, dispatches to the correct action routine.
;
;   Commands can be any number of characters (not necessarily even letters)
; and may be abbreviated to a minimum length specified in the command table.
; For example, "BA", "BAS", "BASI" and "BASIC" are all valid for the "BASIC"
; command, however "BASEBALL" is not.
;
;   See the code at CMDTBL: for an example of how this table is formatted.
;--
COMND:	PUSHR(P3)\ PUSHR(P4)	; save registers P3 and P4
	CALL(LTRIM)		; ignore any leading spaves
	RCOPY(P3,P1)		; save the pointer so we can back up
COMND1:	RCOPY(P1,P3)		; reset the to the start of the command
	LDA P2\ PLO P4		; get the minimum match for the next command
	LBZ	ERRALL		; end of command table if it's zero

;   Compare characters on the command line with those in the command table
; and, as long as they match, advance both pointers....
COMND2:	LDN	P2		; take a peek at the next command table byte
	LBZ	COMN3A		; branch if it's the end of this command
	LDN P1\ CALL(FOLD)	; get the next command character
	SEX P2\ SM		; does the command line match the table?
	LBNZ	COMND3		; nope - skip over this command
	INC P2\ INC P1\ DEC P4	; increment table pointers and decrement count
	LBR	COMND2		; keep comparing characters

;   Here when we find something that doesn't match.  If enough characters
; DID match, then this is the command; otherwise move on to the next table
; entry...
COMND3:	SEX P2\ LDXA		; be sure P2 is at the end of this command
	LBNZ	COMND3		; keep going until we're there
	SKP			; skip over the INC
COMN3A:	INC	P2		; skip to the dispatch address
	GLO	P4		; how many characters matched?
	LBZ	COMND4		; branch if an exact match
	SHL			; test the sign bit of P4.0
	LBDF	COMND4		; more than an exact match

; This command doesn't match.  Skip it and move on to the next...
	INC P2\ INC P2		; skip two bytes for the dispatch address
	LBR	COMND1		; and then start over again

; This command matches!
COMND4:	SEX SP\ IRX		; restore P3 and P4
	POPR(P4)\ POPRL(P3)	; ...
	RLDI(T1,COMND5)		; switch the PC temporarily
	SEP	T1		; ...
COMND5:	SEX	P2		; ...
	POPR(PC)		; load the dispatch address into the PC
	LDI	0		; always return with D cleared!
	SEX SP\ SEP PC		; branch to the action routine

	.SBTTL	Primary Command Table

;++
;   This table contains a list of all the firmware command names and the
; addresses of the routines that execute them.  Each table entry is formatted
; like this -
;
;	.BYTE	2, "BASIC", 0
;	.WORD	BASIC
;
; The first byte, 2 in this case, is the minimum number of characters that must
; match the command name ("BA" for "BASIC" in this case).  The next bytes are
; the full name of the command, terminated by a zero byte, and the last two
; bytes are the address of the routine that processes this command.
;--

; This macro makes it easy to create a command table entry ...
#define CMD(len,name,routine)	.BYTE len, name, 0\ .WORD routine

; And here's the actual table of commands ...
CMDTBL:	CMD(2, "INPUT",      INPUT)	; test input port
	CMD(3, "OUTPUT",     OUTPUT)	;  "   output  "
	.IF (BASIC != 0)
	CMD(3, "BASIC",	     RBASIC)	; run BASIC
	.ENDIF
	CMD(1, "EXAMINE",    EXAM)	; examine/dump memory bytes
	CMD(1, "DEPOSIT",    DEPOSIT)	; deposit data in memory
	CMD(3, "REGISTERS",  SHOREG)	; show registers
	CMD(2, "XSAVE",	     XSAVE)	; save memory via XMODEM
	CMD(2, "XLOAD",	     XLOAD)	; load memory via XMODEM
	CMD(2, "HELP",	     PHELP)	; print help text
	CMD(3, "SPLASH",     SPLASH)	; display the startup splash screen
	CMD(4, "TERM",	     TTERM)	; terminal mode
	CMD(3, "TIN",	     TIN)	; select PS/2 keyboard for input
	CMD(3, "SIN",	     SIN)	; select serial port for input
	CMD(4, "TOUT",	     TOUT)	; select video display for output
	CMD(4, "SOUT",	     SOUT)	; select serial port for output
	CMD(2, "PLAY",       PLAY)	; play a melody
	CMD(3, "ODE", 	     PDEMO)	; play demo tune
	CMD(1, ":",          IHEX)	; load Intel .HEX format files
	CMD(1, ";",	     MAIN)	; a comment
; The table always ends with a zero byte...
	.BYTE	0

	.SBTTL	Examine Memory Command

;++
;  The E[XAMINE] command allows you to examine one or more bytes of memory in
; both hexadecimal and ASCII. This command accepts two formats of operands -
;
;	>>>E xxxx yyyy
;	- or -
;	>>>E xxxx
;
;   The first one will print the contents of all locations from xxxx to yyyy,
; printing 16 bytes per line.  The second format will print the contents of
; location xxxx only.  All addresses are in hex, of course.
;--
EXAM:	CALL(HEXNW)		; scan the first parameter and put it in P2
	RCOPY(P3,P2)		; save that in a safe place
	CALL(ISEOL)		; is there more?
	LBDF	EXAM1		; no - examine with one operand
	CALL(HEXNW)		; otherwise scan a second parameter
	RCOPY(P4,P2)		; and save it in P4 for a while
	CALL(CHKEOL)		; now there had better be no more
	CALL(P3LEP4)		; are the parameters in the right order??
	LBNF	CMDERR		; error if not
	CALL(MEMDMP)		; go print in the memory dump format
	RETURN			; and then on to the next command

; Here for the one address form of the command...
EXAM1:	RCOPY(P2,P3)		; copy the address
	CALL(THEX4)		; and type it out
	INLMES("> ")		; ...
	LDN	P3		; fetch the contents of that byte
	CALL(THEX2)		; and type that too
	CALL(TCRLF)		; type a CRLF and we're done
	RETURN			; ...

	.SBTTL	Generic Memory Dump

;++
;   This routine will dump, in both hexadecimal and ASCII, the block of memory
; between P3 and P4.  It's used by the EXAMINE command, but it can also be
; called from other random places, such as the dump disk sector command, and
; can be especially handy for chasing down bugs...
;
;CALL:
;	P3/ starting RAM address
;	P4/ ending RAM address
;	CALL(MEMDMP)
;--
MEMDMP:	GLO P3\ ANI $F0\ PLO P3	; round P3 off to $xxx0
	GLO P4\ ORI $0F\ PLO P4	; and round P4 off to $xxxF
	CALL(TMSG)		; print column headers
	.TEXT	"       0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F\r\n\000"

; Print the address of this line (the first of a row of 16 bytes)...
MEMDM2:	RCOPY(P2,P3)		; copy the address of this byte
	CALL(THEX4)		; and then type it in hex
	INLMES("> ")		; type a > character after the address
	SKP			; skip the INC P3 the first time around

; Now print a row of 16 bytes in hexadecimal...
MEMDM3:	INC	P3		; on to the next byte...
	CALL(TSPACE)		; leave some room between bytes
	LDN	P3		; get the next byte from memory
	CALL(THEX2)		; and type the data in two hex digits

; Here to advance to the next data byte...
MEMDM4:	GLO P3\ ANI $0F\ XRI $0F; have we done sixteen bytes??
	LBNZ	MEMDM3		; no - on to the next address

; Print all sixteen bytes again, put this time in ASCII...
MEMDM5:	CALL(TSPACE)		; leave a few blanks
	CALL(TSPACE)		; ...
	GLO P3\ ANI $F0\ PLO P3	; restore the address back to the beginning
	LBR	MEMD61		; skip the INC P3 the first time around

; If the next byte is a printing ASCII character, $20..$7E, then print it.
MEMDM6:	INC	P3
MEMD61:	LDN	P3		; on to the next byte
	PHI	AUX		; save the original byte
	ANI	$60		; is it a control character??
	LBZ	MEMDM7		; yep - print a dot
	GHI	AUX		; no - get the byte again
	ANI $7F\ XRI $7F	; is it a delete (rubout) ??
	LBZ	MEMDM7		; yep - print a dot
	XRI $7F\ CALL(TCHAR)	; no - restore the original byte and type
	LBR	MEMDM8		; on to the next byte

; Here if the character isn't printing - print a "." instead...
MEMDM7:	OUTCHR('.')		; do just that
MEMDM8:	GLO P3\ ANI $0F\ XRI $0F; have we done sixteen bytes?
	LBNZ	MEMDM6		; nope - keep printing

; We're done with this line of sixteen bytes....
	CALL(TCRLF)		; finish the line
	CALL(CONBRK)		; does the user want to stop early?
	LBDF	MEMDM9		; branch if yes
	INC	P3		; on to the next byte
	GHI P3\ STR SP		; did we roll over from $FFFF to $0000?
	GLO P3\ OR		; check both bytes for zero
	LBZ	MEMDM9		; return now if we rolled over
	CALL(P3LEP4)		; have we done all of them?
	LBDF	MEMDM2		; nope, keep going
MEMDM9:	RETURN			; yep - all done

	.SBTTL	Deposit Memory Command

;++
;   The D[EPOSIT] stores bytes in memory, and it accepts an address and a list
; of data bytes as operands:
;
;	>>>D xxxx dd dd dd dd dd dd dd dd ....
;
; This command would deposit the bytes dd ... into memory addresses beginning
; at xxxx.  Any number of data bytes may be specified; they are deposited into
; sequential addresses...
;--
DEPOSIT:CALL(HEXNW) 		; scan the address first
	RCOPY(P3,P2)		; then save the address where it is safe
	CALL(ISSPAC)		; we'd better have found a space
	LBNF	CMDERR		; error if not

; This loop will read and store bytes...
DEP1:	CALL(HEXNW)		; read another parameter
	CALL(ISSPAC)		; and we'd better have found a space or EOL
	LBNF	CMDERR		; error if not
	GLO P2\ STR P3		; store it in memory at (P3)
	LDN P3\ PHI P2		; verify that memory was changed
	STR SP\	GLO P2\ XOR	; compare what we read with what we wrote
	LBNZ	MEMERR		; branch if error
	INC	P3		; on to the next address
	CALL(ISEOL)		; end of line?
	LBNF	DEP1		; nope - keep scanning
	RETURN			; yes - all done now

; Here if memory can't be written ...
MEMERR:	INLMES("?MEM ERR @")
	PUSHR(P2)		; save the good/bad data
	RCOPY(P2,P3)		; print the address first
	CALL(THEX4)		; ...
	INLMES(" RD=")
	POPD\ CALL(THEX2);
	INLMES(" WR=")
	POPD\ CALL(THEX2)
	LBR	TCRLF

;++
; This routine will zero P2 bytes of RAM starting from location P1.
;--
CLRMEM:	LDI 0\ STR P1\ INC P1	; write one byte with zeros
	DBNZ(P2,CLRMEM)		; and loop until they're all done
	RETURN			; ...

	.SBTTL	INPUT Command

;++
;   The IN[put] command reads the specified I/O port, 1..7, and prints the
; byte received in hexadecimal.
;
;	>>>INP <port>
;--
INPUT:	CALL(HEXNW)		; read the port number
	CALL(CHKEOL)		; and that had better be all
	RLDI(P4,IOT)		; point P4 at the IOT buffer
	GLO P2\ ANI 7		; get the port address
	LBZ	CMDERR		; error if port 0 selected
	ORI $68\ STR P4		; turn it into an input instruction
	INC	P4		; point to IOT+1
	LDI $D0+PC\ STR P4	; load a "SEP PC" instruction
	DEC	P4		; back to IOT:

; Execute the I/O instruction and type the result...
	INLMES("Port ")
	LDN P4\ ANI 7\ ORI '0'	; convert the port number to ASCII
	CALL(TCHAR)		; ...
	INLMES(" = ")		; ...
	SEP	P4		; execute the input and hold your breath!
	CALL(THEX2)		; type that in hex
	LBR	TCRLF		; finish the line and we're done here!

	.SBTTL	OUTPUT Command

;++
;   The OUT[put] command writes the specified byte to the specified I/O port.
; For example
;
;	>>>OUT <port> <byte>
;
; Like INPUT, this command always accesses ports in I/O group 1.  If you want
; to access the VIS chip set, then use the VIS command instead.
;--
OUTPUT:	CALL(HEXNW2)		; P3 == port, P4 == data byte
	CALL(CHKEOL)		; there should be no more
	RLDI(P2,IOT)		; point P2 at the IOT buffer
	GLO P3\ ANI 7		; get the port address
	LBZ	CMDERR		; error if port 0 selected
	ORI $60\ STR P2\ INC P2	; turn it into an output instruction
	GLO P4\ STR P2\ INC P2	; store the data byte inline
	LDI $D0+PC\ STR P2	; store a "SEP PC" instruction
	DEC P2\ DEC P2		; back to IOT:
	SEX	P2		; set X=P for IOT
	SEP	P2		; now call the output routine
	RETURN			; and we're done

	.SBTTL	XMODEM Load and Save

;++
;   The XSAVE command uploads a chunk of memory to the host as a binary "file"
; using the XMODEM protocol, and the XLOAD command downloads the same to RAM.
; XMODEM does have flow control, checksums, error detection and (best of all)
; error correction, which are all good.  Unlike Intel HEX files however, it
; does NOT have any kind of address information so it's up to you to make sure
; that any binary file is loaded into RAM at the right address!
;
;	>>>XSAVE bbbb eeee
; 	- or -
;	>>>XLOAD bbbb eeee
;
; where "bbbb" and "eeee" are the addresses of the first and last bytes to be
; saved or loaded (similar to the EXAMINE command).
;
;   XMODEM always saves data in 128 byte blocks so for XSAVE if the size of the
; block to be saved is not a multiple of 128, then the last record will be
; padded with SUB ($1A, Control-Z) bytes.  That's the XMODEM tradition.  For
; XLOAD, if the host sends more data than the specified address range allows,
; the extra data will be ignored.  That means that as long as XSAVE and XLOAD
; have the same parameters, the extra SUB bytes will be ignored.
;--
XLOAD:	CALL(HEXNW2)		; we always have two parameters
	CALL(CHKEOL)		; and then that should be everything
	CALL(P3LEP4)		; make sure "bbbb" .LE. "eeee"
	LBNF	CMDERR		; abort if they aren't
	RCOPY(P1,P3)		; save the starting address temporarily
	CALL(P4SBP3)		; and then compute eeee-bbbb -> P3
	CALL(XOPENR)		; open an XMODEM channel with the host
	RCOPY(P2,P3)		; put the byte count in P2
	RCOPY(P3,P1)		; and the start address in P3
	CALL(XREAD)		; read the data with XMODEM
	LBR	XCLOSER		; close the XMODEM connection and we're done

; Here to upload RAM via XMODEM ...
XSAVE:	CALL(HEXNW2)		; we always have two parameters
	CALL(CHKEOL)		; and then that should be everything
	CALL(P3LEP4)		; make sure "bbbb" .LE. "eeee"
	LBNF	CMDERR		; abort if they aren't
	RCOPY(P1,P3)		; save the starting address
	CALL(P4SBP3)		; compute the byte count
	CALL(XOPENW)		; open an XMODEM upload channel
	LBDF	XTOERR		; timeout error
	RCOPY(P2,P3)		; put the byte count in P2
	RCOPY(P3,P1)		; and the RAM address in P3
	CALL(XWRITE)		; send the data with XMODEM
	LBR	XCLOSEW		; close the connection and we're done

; Here for timeout ...
XTOERR:	OUTSTR(XTOMSG)		; print "?TIMEOUT"
	LBR	MAIN		; and abort
XTOMSG:	.BYTE	"?TIMEOUT\r\n", 0

	.SBTTL	Load Intel HEX Records

;   This routine will parse an Intel .HEX file record from the command line and,
; if the record is valid, deposit it in memory.  All Intel .HEX records start
; with a ":", and the command scanner just funnels all lines that start that
; way to here.  This means you can just send a .HEX file to the SBC1802 thru
; your terminal emulator, and there's no need for a special command to download
; it.  And since each Intel .HEX record ends with a checksum, error checking
; is automatic.
;
;   Intel .HEX records look like this -
;
;	>>>:bbaaaattdddddddddddd......ddcc
;
; Where
;
;	bb   is the count of data bytes in this record
;	aaaa is the memory address for the first data byte
;	tt   is the record type (00 -> data, 01 -> EOF)
;	dd   is zero or more bytes of data
;	cc   is the record checksum
;
;   All values are either two, or in the case of the address, four hex digits.
; All fields are fixed length and no spaces or characters other than hex digits
; (excepting the ":" of course) are allowed.
;
;   While this code is running, the following registers are used -
;
;	P1   - pointer to CMDBUF (contains the HEX record)
;	P2   - hex byte/word returned by GHEX2/GHEX4
;	P3   - memory address (from the aaaa field in the record)
;	T1.0 - record length (from the bb field)
;	T1.1 - record type (from the tt field)
;	T2.0 - checksum accumulator (8 bits only!)
;	T2.1 - temporary used by GHEX2/GHEX4
;
;   Lastly, note that when we get here the ":" has already been parsed, and
; P1 points to the first character of the "bb" field.
;
IHEX:	CALL(GHEX2)\ PLO T1	; record length -> T1.0
	LBNF	CMDERR		; syntax error
	CALL(GHEX4)		; out the load address in P3
	LBNF	CMDERR		; syntax error
	CALL(GHEX2)\ PHI T1	; record type -> T1.1
	LBNF	CMDERR		; syntax error

; The only allowed record types are 0 (data) and 1 (EOF)....
	LBZ	IHEX1		; branch if a data record
	SMI	1		; is it one?
	LBZ	IHEX4		; yes - EOF record

; Here for an unknown hex record type...
	OUTSTR(URCMSG)\	RETURN

;   Here for a data record - begin by accumulating the checksum.  Remember
; that the record checksum includes the four bytes (length, type and address)
; we've already read, although we can safely skip the record type since we know
; it's zero!
IHEX1:	GHI P3\ STR SP		; add the two address bytes
	GLO P3\ ADD\ STR SP	; ...
	GLO T1\ ADD		; and add the record length
	PLO	T2		; accumulate the checksum here

; Read the number of data bytes specified by T1.0...
IHEX2:	GLO	T1		; any more bytes to read???
	LBZ	IHEX3		; nope - test the checksum
	CALL(GHEX2)		; yes - get another data value
	LBNF	CMDERR		; syntax error
	STR SP\ SEX SP		; save the byte on the stack for a minute
	GLO T2\ ADD\ PLO T2	; and accumulate the checksum
	LDN SP\ STR P3		; store the byte in memory at (P3)
	LBDF	MEMERR		; memory error
	INC P3\ DEC T1		; increment the address and count the bytes
	LBR	IHEX2		; and keep going

; Here when we've read all the data - verify the checksum byte...
IHEX3:	CALL(GHEX2)		; one more time
	LBNF	CMDERR		; syntax error
	STR SP\ GLO T2\ ADD	; add the checksum byte to the total so far
	LBNZ	IHEX6		; the result should be zero
	INLMES("OK")		; successful (believe it or not!!)
	LBR	TCRLF		; ...

;  Here for an EOF record.  Note that we carelessly ignore everything on the
; EOF record, including any data AND the checksum.  Strictly speaking we're
; not supposed to do that, but EOF records never have any data.
IHEX4:	INLMES("EOF")
	LBR	TCRLF

;   And here if the record checksum doesn't add up.  Ideally we should just
; ignore this entire record, but unfortunatley we've already stuffed all or
; part of it into memory.  It's too late now!
IHEX6:	OUTSTR(HCKMSG)
	RETURN

; HEX file parsing messages ...
HCKMSG:	.TEXT	"?CHECKSUM ERROR\r\n\000"
URCMSG:	.TEXT	"?UNKNOWN RECORD\r\n\000"

	.SBTTL	Scan Two and Four Digit Hex Values

;   These routines are used specifically to read Intel .HEX records.  We can't
; call the usual HEXNW, et al, functions here since they need a delimiter to
; stop scanning.  Calling HEXNW would just eat the entire remainder of the
; .HEX record and return only the last 16 bits!  So instead we have two special
; functions, GHEX2 and GHEX4, that scan fixed length fields.

;   This routine will read a four digit hex number pointed to by P1 and return
; its value in P3.  Other than a doubling of precision, it's exactly the same
; as GHEX2...
GHEX4:	CALL(GHEX2)\ PHI P3	; get the first two digits
	LBNF	GHEX40		; quit if we don't find them
	CALL(GHEX2)\ PLO P3	; then the next two digits
	LBNF	GHEX40		; not there
	SDF			; and return with DF set
GHEX40:	RETURN			; all done


;   This routine will scan a two hex number pointed to by P1 and return its
; value in D.  Unlike F_HEXIN, which will scan an arbitrary number of digits,
; in this case the number must contain exactly two digits - no more, and no
; less.  If we don't find two hex digits in the string addressed by P1, the
; DF bit will be cleared on return and P1 left pointing to the non-hex char.
GHEX2:	LDN	P1		; get the first character
	CALL(ISHEX)		; is it a hex digit???
	LBNF	GHEX40		; nope - quit now
	SHL\ SHL\ SHL\ SHL	; shift the first nibble left 4 bits
	PHI	T2		; and save it temporarily
	INC P1\	LDN P1		; then get the next character
	CALL(ISHEX)		; is it a hex digit?
	LBNF	GHEX20		; not there - quit now
	STR SP\ GHI T2\ OR	; put the two digits together
	INC P1\ SDF		; success!
GHEX20:	RETURN			; and we're all done

	.SBTTL	HELP Command

;++
;   The HELP command prints a canned help file, which is stored in EPROM in
; plain ASCII. 
;--
PHELP:	CALL(CHKEOL)		; HELP has no arguments
	RLDI(P1,HLPTXT)		; nope - just print the whole text
	LBR	TSTR		; ... print it and return

	.SBTTL	TERM Emulator

;++
;   The following code uses a "quick call" subroutine convention rather than
; SCRT for speed reasons. The quick call format only stores a one-byte return
; address representing the address within the page the call occurred from.
; The return is effected by a simple PLO PC from a location within the same
; page as the caller. Calling convention looks like:
;
;	LDI $+5\ LBR SUBR
;
; This passes the return address to the subroutine in D, which it pushes to
; the stack.  The return at the end of the subroutine is then simply:
;
;	IRX\ LDX\ PLO PC
;
; As can be seen, this only takes eleven machine cycles versus the 66 cycles
; that standard call costs, but obviously with limitations, including that
; the subroutine must return from the same page it was called from. This is
; accomplished by a return stub that can be jumped to.
;
; To hide a little bit of this, macros have been created for the above:
;
;	QCALL(SUBR)
;	QRETURN
;
; Since D is used to pass the return address, and destroyed on return, it
; can't be used to pass values, so will will generally do that in AUX.1 when
; single-byte arguments are used.
;
; For the cases where a function needs to be used through standard call,
; there is a simple wrapper around the quick call to save registers and 
; change argument passing between AUX and D as needed.
;--

;++
;   This is your basic terminal emulator.  It simply copies characters from
; the serial port to the screen, and from the keyboard to the serial port.
; Notice that this routine loops forever, however you can get to the command
; scanner by pressing either the MENU key on the PS/2 keyboard or sending a
; long break on the serial port.
;
;   TTERM is an alternate entry used by the TERM command.
;--

TTERM:	CALL(CHKEOL)
	OUTSTR(TTMSG)

TERM:	RLDI(T1,KEYBRK)		; clear both the KEYMNU and KEYBRK flags
	LDI 0\ STR T1\ DEC T1
	STR T1\ DEC T1
	RLDI(T1,SERBRK)		; and clear the serial break flag too
	LDI 0\ STR T1		; ...

	LBR TERM1\ PAGE		; make short branches and calls align

TERM1:	RLDI(T1,KEYMNU)		; was the menu key pressed ?
	LDN T1\ BZ TERM2	; no - go check for serial break
	LDI 0\ STR T1		; yes - clear the menu key flag
	LBR MAINTE		; and start up the command scanner

TERM2:	LDI LOW(SERBRK)\ PLO T1	; was a serial break received ?
	LDN T1\ BZ TERM3	; no - go check for keyboard break
	LDI 0\ STR T1		; yes - clear the serial break flag

TERM3:	LDI LOW(KEYBRK)\ PLO T1	; was the BREAK key pressed ?
	LDN T1\ BZ TERM4	; no - go check for serial input
	LDI 0\ STR T1		; yes - clear the KEYBRK flag
	CALL(TXSBRK)		; and send a break on the serial port

TERM4:	QCALL(SERGEQ)		; anything in the buffer
	BDF TERM5		; no - check the PS/2 keyboard
	QCALL(VTPUTQ)
	BR TERM4

TERM5:	QCALL(GETKEQ)		; anything waiting from the keyboard?
	BDF TERM1		; no - back to checking the serial port
	QCALL(SERPUQ)		; yes - send it to the serial port
	BR TERM1		; and keep going

SHRET:	QRETURN			; get the return address

	.SBTTL	Serial Port Standard Call Wrapper Routines

;++
;   This is an SCRT wrapper around the SERGEQ quick-call subroutine so that
; it can be used by BASIC and the monitor through CALL(SERGET). This gets one
; character from the serial port and returns it in D, except if none are
; available, in which case it sets DF. 
;--

SERGET:	PUSHR(T1)		; save a temporary register
	QCALL(SERGEQ)
	IRX\ POPRL(T1)		; restore T1 from stack
	GHI AUX\ RETURN

;++
;  This is just like SERGET, except that it will wait for input if none is
; available now.  There's no timeout on the wait!
;--

SERGEW:	PUSHR(T1)		; save a temporary register
SERGE3:	QCALL(SERGEQ)
	BDF SERGE3
	IRX\ POPRL(T1)		; restore T1 from stack
	GHI AUX\ RETURN

;++
;   This is an SCRT wrapper around the SERPUQ quick-call subroutine so that
; it can be used by BASIC and the monitor through CALL(SERPUT). This sends
; one character to the serial port, which is passed in D.
;--

SERPUT:	PHI AUX\ PUSHR(T1)	; save a temporary register
	QCALL(SERPUQ)
	IRX\ POPRL(T1)		; restore T1
	GHI AUX\ RETURN		; and we're done

;++
;   And this routine is just like SERPUT, except that it will wait for space
; to be available if the buffer is currently full.
;--

SERPUW:	PHI AUX\ PUSHR(T1)	; save a temporary register
SERPU3:	QCALL(SERPUQ)
	BDF SERPU3
	IRX\ POPRL(T1)		; restore T1
	GHI AUX\ RETURN		; and we're done

;++
;   This is an SCRT wrapper around the GETKEQ quick-call subroutine so that
; it can be used by BASIC and the monitor through CALL(GETKEQ). This gets
; one character from the keyboard and returns it in D, except if none are
; available, in which case it sets DF. 
;--

GETKEY:	PUSHR(T1)\ PUSHR(T2)	; save two working registers
	QCALL(GETKEQ)
	IRX\ POPR(T2)\ POPRL(T1); restore saved registers
	GHI AUX\ RETURN		; and we're done

	.SBTTL	Output Characters to the Screen

;++
;   This is a wrapper around the VTPUTQ routine to save the registers that
; BASIC or command mode may need preserved but that the terminal routine
; does not (which calls VTPUTQ directly). This saves the overhead of the
; save and restores where it is not needed. This also returns the character
; originally passed to it and clears DF.

VTPUTC:	PHI AUX\ SEX SP		; save character in a safe place
	PUSHR(T1)		; save the registers that we use 
	PUSHR(T2)		; ...
	PUSHR(P1)		; ...
	QCALL(VTPUTQ)
 	RLDI(T1,CURCHR)		; gotta get back the original data
	LDN T1\ PHI AUX		; save it for a moment
	SEX SP\ IRX\ POPR(P1)	; restore the registers we saved
	POPR(T2)\ POPRL(T1)	; ...
	CDF\ GHI AUX
	RETURN			; and we're done!


; Messages ...
TTMSG:	.TEXT	"[TERMINAL MODE]\r\n\000"
TEMSG:	.TEXT	"\r\n\n[COMMAND MODE]\r\n\000"

	.SBTTL	Start BASIC Interpreter

	.IF (BASIC != 0)
;++
;   The BASIC command runs BASIC from ROM.  The BASIC we is the BASIC3 v1.1
; from the RCA Microboard COSMAC Development System (aka the MCDS, not to be
; confused with the earlier COSMAC Development System, CDS).  This BASIC 
; takes 12K of ROM and was written for a "ROM high, RAM low" configuration.
; Better yet, it was also written to work with the UT62 ROM for the console
; I/O, which is compatible with the UT71 ROM that we emulate for MicroDOS.
;
;   BASIC runs using the ROM0 memory map and all we have to do is jump to
; it's starting address using R0 as the PC.  The rest takes care of itself.
;--
RBASIC:	CALL(CHKEOL)		; no arguments for this command
	LBR	BASIC		; load the BASIC entry point


;++
;   This routine is called by BASIC for the BYE command.  It will reinitialize
; everything, including SCRT and the console terminal, and then restarts the
; monitor.
;--
BEXIT:	RLDI(SP,STACK)		; reset the stack pointer
	RLDI(CALLPC,SCALL)	;  ... and re-initialize the CALLPC and
	RLDI(RETPC,SRETURN)	;  ... RETPC just to be safe
	CALL(RSTIO)		; reset the console I/O pointers
	LBR	MAIN		; and return to MAIN
	.ENDIF

	.SBTTL	BASIC LOAD/SAVE Support

	.IF (BASIC != 0)
;++
;   BASIC calls this routine to save either program or data using XMODEM.  When
; we get here, BASIC has already switched the SCRT routines to our own BIOS
; versions, so we're free to call any XMODEM or BIOS functions so long as we
; preserve all registers.  When BASIC calls us we have
;
;	RA (aka T4) = start address
;	RC (aka P3) = byte count
;
;   One thing - when somebody eventually tries to load this data back into
; BASIC, there's nothing to tell us how many bytes we should load nor where
; (in RAM) we should put it.  BASIC just assumes we know, and of course XMODEM
; doesn't save this information.  That means we have to save it, so we add four
; bytes to the start of the data to save the address and byte count.  We do
; this by pushing those registers onto the stack and then saving four bytes
; directly from the stack area, which is slightly clever but works great.
;
; Note that P2 (aka RD) is critical to BASIC and we have to preserve it!
;--
BSAVE:	CALL(XOPENW)		; open the XMODEM channel to the host
	LBDF	BASTMO		; branch if failure
	PUSHR($D)		; save BASIC's RD (aka P2)
	PUSHR($C)		; put the byte count on the stack first
	PUSHR($A)		; ... and then the RAM address
	RCOPY(P3,SP)\ INC P3	; point to the first of these four bytes
	RLDI(P2,4)		; ... and save four bytes
	CALL(XWRITE)		; ...
	IRX\ POPR(P3)		; now put the actual RAM address in P3
	POPRL(P2)		;  ... and the actual byte count in P2
	CALL(XWRITE)		; save the BASIC data
	IRX\ POPRL($D)		; restore BASIC's RD
	LBR	XCLOSEW		; close XMODEM and return


;++
;   And this routine will load a BASIC program or data via XMODEM and it's
; essentially the reverse of BSAVE, above.  Remember that BASIC doesn't tell
; us how many bytes to load nor where in RAM to put them - we have to get all
; that from the four byte header that BSAVE wrote.
;--
BLOAD:	CALL(XOPENR)		; open the XMODEM channel to the host
	PUSHR($D)		; save BASIC's RD (aka P2)
	DEC SP\ DEC SP\ DEC SP	; make some space on the stack
	RCOPY(P3,SP)\ DEC SP	; and set P3 to the address of this space
	RLDI(P2,4)		; ... it's always four bytes
	CALL(XREAD)		; read the header information first
	IRX\ POPR(P3)		; put the RAM address from the image in P3
	POPRL(P2)		; and the byte count in P2
	CALL(XREAD)		; load the BASIC data
	IRX\ POPRL($D)		; restore BASIC's  RD
	LBR	XCLOSER		; close XMODEM and return


; Here for BASIC SAVE/LOAD XMODEM time out ...
BASTMO:	OUTSTR(XTOMSG)		; say "?TIMEOUT"
	RETURN			; and give up
	.ENDIF

	.SBTTL	BASIC PLAY and KEY Support

	.IF (BASIC != 0)
;++
;   This routine is called by the BASIC PLAY statement, which plays tunes using
; the CDP1869 sound hardware.  
;
;	PLAY string
;
;   The argument to PLAY is a string of characters which specify the pitch, 
; duration, octave, volume, etc of the notes to be played according to rules
; documented in the PLAY routine later in this file.  
;
;   Syntactically BASIC treats PLAY like a REM statement and just completely
; ignores the remainder of the line.  Spaces are ignored, but otherwise the
; remainder of the line will be "played", and in particular, quotation marks
; around the string are NOT required (and should NOT be used).  And sadly,
; this also means that the string has to be a constant in the BASIC program;
; there's no way to use string variables or string functions to generate the
; music string.
;
;   BASIC passes us a pointer to the source line in RB, which we transfer to
; P1 for PLAY.  On return PLAY leaves P1 pointing to the first character that
; it could NOT interpret as a musical note, and we transfer that pointer back
; to RB before returning.  BASIC will check that this points to an end of line
; and will issue an error if it doesn't.
;--
BPLAY:	PUSHR(T2)		; need to save T2 for BASIC
	RCOPY(P1,$B)		; put the line pointer in P1
	CALL(PLAY1)		; and play music!
	RCOPY($B,P1)		; let BASIC know where we stopped
	IRX\ POPRL(T2)		; restore T2 and ...
	RETURN			;  ... we're done


;++
;   The KEY function in BASIC tests the current console for any input pending
; and, if there is something there, returns the ASCII value of that character.
; If the input buffer is empty the zero is returned.
;
;	LET K = KEY
;  or
;	IF KEY != 0 ...
;
;   Note that there are no parenthesis after the KEY - that's a quirk of the
; way BASIC3 works.
;
;   KEY respects the current TIN/SINP console assignment, and any input read
; by KEY is NOT echoed!   We return the result in R8.0.
;--
BKEY:	CALL(CONGET)		; then poll the console input device
	LSNF			; if DF=1 ...
	 LDI	 0		;  ... return zero
	PLO	R8		; save the result
	RETURN			; and that's it!
	.ENDIF

	.SBTTL	BASIC TIME and WAIT Support

	.IF (BASIC != 0)
;++
;   The BASIC TIME function returns the number of VRTC interrupts since the
; system was powered up.  This is a 32 bit value that only increases as time
; goes on.  It doesn't give you the actual time of day, but it does give a 
; convenient way to measure time in real units.
;
;	LET T = TIME
;
;   Note that, like KEY, there can be no parenthesis after TIME.  That's just
; a BASIC3 quirk.  The 32 bit result is returned in R8 (low 16 bits) and RA
; (high 16 bits).
;
;   BTW, it's critical to turn off interrupts while doing this.  It's always
; possible that the count might roll over from 0xFF, 0xFFFF, or even 0xFFFFFF
; while we're here, and if that happens while we're here then we could return
; a massively wrong result.
BTIME:	PUSHR(P1)		; save a working register (note T1 == R8!)
	RLDI(P1,UPTIME)		; and point to the current uptime count
	IOFF			; make sure the count DOESN'T change!
	LDA P1\ PLO $8		; return the result in R8 ...
	LDA P1\ PHI $8		;  ...
	LDA P1\ PLO $A		;  ... and RA ...
	LDA P1\ PHI $A		;  ...
	ION			; interrupts are safe again
	IRX\ POPRL(P1)		; restore P1
	RETURN			; and we're done here


;++
;   The BASIC WAIT statement delays execution for a number of VRTC interrupt
; "ticks".  
;
;	WAIT value
;
;   BASIC treats the argument as a 16 bit unsigned value and passes that to
; us in RA.  We add that value (which requires a 32 bit quad precision addition
; unfortunately!) to the current UPTIME and then just spin here until UPTIME
; counts past that value.
;
;   One complication - we call CONBRK repeatedly while we're waiting and if
; a BREAK is found we abort the wait and return immediately!
;--
BWAIT:	PUSHR(P1)\ PUSHR(T2)	; save some working room (T1 == RA!!)
	PUSHR(T3)		; ...
	RLDI(P1,UPTIME)		; point to the current uptime
	IOFF\ SEX P1		; don't allow UPTIME to change
	GLO $A\ ADD\ PLO T2\ IRX ; add WAIT argument to current time
	GHI $A\ ADC\ PHI T2\ IRX ;  ... store the result in T2 (low)
	LDXA\ ADCI 0\ PLO T3	;  ... and T3 (high)
	LDXA\ ADCI 0\ PHI T3	;  ...
	ION			; interrupts are safe again

; Now start waiting ...
BWAIT1:	CALL(CONBRK)		; test for a break
	LBDF	BWAIT2		; quit now if a break was found
	RLDI(P1,UPTIME)		; compare T3:T2 to UPTIME
	IOFF\ SEX P1		; again, don't allow UPTIME to change
	GLO T2\ SM\ IRX		; compute <end time> - <uptime>
	GHI T2\ SMB\ IRX	;  ... but don't store the result!
	GLO T3\ SMB\ IRX	;  ...
	GHI T3\ SMB		;  ...
	ION			; interrupts are safe again
	LBGE	BWAIT1		; keep waiting until <end time> - <uptime> < 0

; All done ...
BWAIT2:	SEX SP\ IRX\ POPR(T3)	; restore saved registers
	POPR(T2)\ POPRL(P1)	; ...
	RETURN			; and we're done waiting
	.ENDIF

	.SBTTL	Trap and Save Context

;++
; BREAKPOINT TRAPS
;   You can put an LBR to TRAP anywhere (say, in BASIC while you're debugging
; it!) and this routine will save the user registers, re-initialize the stack
; and SCRT, and then branch to MAIN to start the command scanner.  It uses R0
; to save the registers (remember that R1 is reserved for interrupts, which
; we need!) and assumes the PC is R3 and that R2 points to some kind of valid
; stack.
;--

;   Save (X,P) to the stack (the current P is moot, but it's useful to know
; what X is), and the current D and DF to the stack (assuming that there's a
; valid stack pointer in R2).
TRAP:	MARK			; save (X,P)
	SEX R2\ STXD		; save D on the user's stack
	LDI 0\ SHLC\ STR R2	; and save DF on the stack too

; Save registers RF thru R3 in memory at REGS:...
	RLDI(R0,REGS+32-1)\ SEX R0
	PUSHR(RF)
	PUSHR(RE)
	PUSHR(RD)
	PUSHR(RC)
	PUSHR(RB)
	PUSHR(RA)
	PUSHR(R9)
	PUSHR(R8)
	PUSHR(R7)
	PUSHR(R6)
	PUSHR(R5)
	PUSHR(R4)
	PUSHR(R3)
	DEC R0\ DEC R0		; skip over R2 (we'll fix that later)

;   The next two registers, R1 and R0, don't really contain useful data but
; we need to skip over those before we can save D, DF and X...
	PUSHR(R1)		; R1 is the ISR, but save it anyway
	LDI 0\ STXD\ STXD	; save R0 as all zeros

; Recover DF, D and X from the user's stack and save them in our memory...
	LDN	R2		; get the user's DF
	STXD			; store that at SAVEDF:
	INC R2\ LDN R2		; then get the user's D
	STXD			; and store that at SAVED:
	INC R2\ LDN R2		; and lastly get the user's (X,P)
	STXD			; and store it at SAVEXP:

;   Finally, update the value of register 2 that we saved so that it shows the
; current (and correct) value, before we pushed three bytes onto the stack...
	RLDI(R0,REGS+5)
	PUSHR(R2)

;   We're all done saving stuff.  Reset our stack pointer and the SCRT pointers
; (just in case) and then dump the breakpoint data.
	RLDI(CALLPC,SCALL)	; reset our SCRT pointers
	RLDI(RETPC,SRETURN)	; ...
	RLDI(SP,STACK)\ SEX SP	; and reset the stack pointer to the TOS
	CALL(SHOBPT)		; print the registers 
	LBR	MAIN		; go start up the command scanner

	.SBTTL	Display User Context

;++
;   This routine will display the user registers that were saved after the last
; breakpoint trap.   It's used by the "REGISTERS" command, and is also called
; directly whenever a breakpoint trap occurs.
;--

; Here to display the registers after a breakpoint trap ...
SHOBPT:	OUTSTR(BPTMSG)		; print "BREAKPOINT ..."
	LBR	SHORE1		; thenn go dump all the registers

; Here for the "REGisters" command...
SHOREG:	CALL(CHKEOL)		; should be the end of the line
				; Fall into SHORE1 ....

; Print a couple of CRLFs and then display X, D and DF...
SHORE1:	RLDI(T1,SAVEXP)		; point T1 at the user's context info
	INLMES("XP=")		; ...
	SEX T1\ LDXA		; get the saved value of (X,P)
	CALL(THEX2)		;  ... and print it in hex
	INLMES(" D=")		; ...
	SEX T1\ LDXA		; now get the saved value of D
	CALL(THEX2)		; ...
	INLMES(" DF=")		; ...
	SEX T1\ LDXA\ ADI '0'	; and lastly get the saved DF
	CALL(TCHAR)		; ... it's just one bit!
	CALL(TCRLF)		; finish that line

;   Print the registers R(0) thru R(F) (remembering, of course, that R0 and R3
; aren't really meaningful, on four lines four registers per line...
	LDI 0\ PLO P3		; count the registers here
SHORE2:	OUTCHR('R')		; type "Rn="
	GLO P3\ CALL(THEX1)	; ...
	OUTCHR('=')		; ...
	SEX T1\ POPR(P2)	; now load the register contents from REGS:
	CALL(THEX4)		; type that as 4 hex digits
	CALL(TTABC)		; and finish with a tab
	INC	P3		; on to the next register
	GLO	P3		; get the register number
	ANI	$3		; have we done a multiple of four?
	LBNZ	SHORE2		; nope - keep going

; Here to end the line...
	CALL(TCRLF)		; finish off this line
	GLO	P3		; and get the register number again
	ANI	$F		; have we done all sixteen??
	LBNZ	SHORE2		; nope - not yet
	LBR	TCRLF		; yes - print another CRLF and return

; Messages...
BPTMSG:	.TEXT	"\r\nBREAK AT \000"

;++
;   This routine is called whenever we want to send a character to the video
; terminal.  It checks to see whether we are in the middle of processing an
; escape sequence and, if we are, then it advances the state machine for that.
; If its not an escape sequence then we next check for a control character and
; handle those as needed.  And lastly, if it's just a plain ordinary printing
; character then we branch off to NORMAL to handle the alternate character set
; and reverse video.
;--
VTPUTQ:	STXD			; save the return address

	RLDI(T1,CURCHR)		; point to our local storage
	GHI AUX\ STR T1		; move the character to CURCHR

	DEC T1\ LDN T1		; load ESCSTA
	LBNZ ESCSEQ		; if not zero we are in an escape sequence

	GHI AUX\ ANI $7F	; get the character and trim to 7 bits
	SMI $7F\ LBZ SHRET	; if it's a RUBOUT then do nothing

	ADI $5F\ ADI $20	; is it a control character?
	LBDF CONTRL		; yes - print as control character

;;;	LBR NORMAL		; fall through to normal character


	.SBTTL	Write Normal Characters to the Screen

;++
;   This routine is called whenever a "normal" printing ASCII character is
; received.  This character will be written to the screen at the current
; cusror location.  After that, the cursor will move right one character unless
; the cursor is at the right edge of the screen, it which case it will wrap
; around to the next line.  The character to be written should be passed in D.
;
;   Like the VT52, we have both a "normal" mode and an alternate character set
; mode.  In graphics character set (aka ACS) mode, if we receive an ASCII
; character from 0x60..0x7E (i.e. a lower case character) then it's replaced
; with the corresponding character from the graphics set instead.  In our
; particular case, the graphics set is stored in the character generator ROM
; locations corresponding to codes 0x00..0x1F, so we have to convert the
; 0x60..0x7E code into this range.
;
;   Note that upper case ASCII characters in the range 0x20..0x5F are not
; affected by the character set mode.  Also note that our alternate font
; isn't necessarily the same as the VT52!
;--
NORMAL:	STR SP			; save the character for a minute

; Check the character set mode...
	LDI LOW(ACSMOD)\ PLO T1	; point to character set mode flag
	LDA T1\ BZ NORMA1	; get and branch if not ACS mode
	LDN SP\ SMI $60		; is this a lower case letter?
	BL NORMA1\ STR SP 	; if yes shift it down to 0x00..0x1F

; Now store the character in memory (finally!)
;   BTW, don't be tempted to do an "ANI $7F" here, because WFAC uses this
; to write field attribute codes to the screen!

NORMA1:	LDA T1\ INC T1\ INC T1	 ; get TOPLIN and move to CURSY
	SEX T1\ ADD\ SHL\ PLO T2 ; add CURSY then double and set index lsb
	LDI HIGH(LINTAB)\ PHI T2 ; set the page of the table index

	DEC T1			; point to CURSX
	LDA T2\ ADD\ PLO P1	; add low byte of address
	LDN T2\ ADCI 0\ PHI P1	; get high byte and add any carry into it

	LDN SP\ STR P1		; get character and put on screen

	LDN T1\ SMI MAXCOL-1	; get CURSX and check if last column
	BZ NORMA2		; yes - need to adjust row
	ADI MAXCOL\ STR T1	; no - add one to CURSX

NORMA4:	DEC T1			; move to VISCUR
	LDN T1\ BZ NORMA5	; the cursor is hidden, don't update

	OUT CRTCMD		; give the load cursor command
	OUT CRTPRM		; and output X ...
	OUT CRTPRM		; ... and then Y
NORMA5:	SEX SP\ LBR SHRET	; ... and return

NORMA2: STR T1\ INC T1		; zero the column and point to CURSY
	LDN T1\ SMI MAXROW-1	; get CURSY and check if last row
	BZ NORMA3		; yes - need to scroll up
	ADI MAXROW\ STR T1	; no - add one to CURSY
	DEC T1\ BR NORMA4	; update hardware cursor location

NORMA3:	DEC T1\ DEC T1		; move to VISCUR
	LDN T1\ LBZ SCRUP	; if the cursor hidden, don't update

	OUT CRTCMD		; give the load cursor command
	OUT CRTPRM		; and output X ...
	OUT CRTPRM		; ... and then Y

	LBR SCRUP		; scroll screen up one line


	.SBTTL	Interpret Escape Sequences

;++
;   This routine is called whenever an escape character is detected and what
; happens depends, of course, on what comes next.  Unfortunately, that's
; something of a problem in this case - in a real terminal we could simply
; wait for the next character to arrive, but in this case nothing's going
; to happen until we return control to the application. 
;
;   The only solution is to keep a "flag" which lets us know that the last
; character was an ESCape, and then the next time we're called we process
; the current character differently.  Since many escape sequences interpret
; more than one character after the ESCape, we actually need a little state
; machine to keep track of what we shold do with the current character.
;--
ESCAPE:	LDI EFIRST		; next state is EFIRST (ESCAP1)
	CALL(ESCSET)
	LBR SHRET

ESCSET:	STR SP			; save that for a second
	RLDI(T1,ESCSTA)		; point to the escape state
	LDN SP\ STR T1		; update the next escape state
	RETURN			; and then wait for another character

ESCNXT:	STR SP			; save that for a second
	RLDI(T1,ESCSTA)		; point to the escape state
	LDN SP\ STR T1		; update the next escape state
ESCRET:	LBR SHRET		; and then wait for another character

;   Here for the first character after the <ESC> - this alone is enough
; for most (but not all!) escape sequences.  To that end, we start off by
; setting the next state to zero, so if this isn't changed by the action
; routine this byte will by default be the last one in the escape sequence.
ESCAP1:	LDI 0\ CALL(ESCSET)	; set the next state to zero
	RLDI(T1,CURCHR)\ LDN T1	; get the current character back again
	SMI 'A'\ LBL ESCAP4	; is it less than 'A' ?
	SMI	'Z'-'A'+1	; check the other end of the sequence
	LBGE	ESCAP3		; ...
	LDN T1\ SMI 'A'		; convert the character to a zero based index
	LBR	ESCUPR

;   All our extended, non-standard escape sequences consist of <ESC> followed
; by a lower case letter.  If this isn't a standard VT52 escape sequence, then
; check for that next.
ESCAP3:	LDN	T1		; get the character after the <ESC> again
	SMI 'a'\ LBL ESCRET	; see if it's a lower case letter
	SMI	'z'-'a'+1	; ...
	LBGE	ESCRET		; just ignore it if it's not lower case letters
	LDN T1\ SMI 'a'		; convert to a zero based index
	LBR	ESCLWR

;   A real VT52 has two escape sequences where the <ESC> is NOT followed by
; a letter - <ESC> = (select alternate keypad mode) and <ESC> > (select
; numeric keypad mode).  They don't fit into our table scheme, so we just
; special case these ...
ESCAP4:	LDN T1\ SMI '='		; check for alternate keypad mode
	LBZ	ALTKPD		; select alternate keypad mode
	LDN T1\ SMI '>'		; and normal (numeric) keypad mode
	LBZ	NUMKPD		; ...
	LBZ	ESCRET		; just ignore anything else

	.SBTTL	Direct Cursor Addressing

;++
;   This routine implements the direct cursor addressing escape sequence.  The
; <ESC>Y sequence is followed by two data bytes which indicate the line and
; column (in that order) that the cursor is to move to. Both values are biased
; by 32 so that they are appear as printing ASCII characters.  The line number
; character should be in the range 32 to 55 (decimal), and the column number
; character may range from 32 to 112 (decimal).  If either byte is out of
; range, then the cursor will only move as far as the margin.
;
;   For example:
;	<ESC>Y<SP><SP>	- move to (0,0) (i.e. home)
;	<ESC>Y7o	- move to (79,23) (i.e. lower right)
;--

; Here for part 1 - <ESC>Y has been received so far...
DIRECT: LDI EYNEXT\ LBR ESCNXT	; next state is get Y

; Part 2 - the current character is Y, save it and wait for X...
DIRECY: RLDI(T1,CURCHR)		; get the current character
	LDA T1\ STR T1		; load CURCHR, save in SAVCHR
	LDI EXNEXT\ LBR ESCNXT	; next state is "get X"

; Part 3 - CURCHR is X and SAVCHR is Y.
DIRECX: RLDI(T1,CURCHR)		; point T1 at CURCHR/SAVCHR
	RLDI(T2,CURSX)		; and T2 at CURSX/CURSY

;  First handle the X coordinate.  Remember that the cursor moves to the
; corresponding margin if the coordinate give is less than 0 or greater than
; MAXCOL-1!
	LDN T1\ SMI ' '		; get X and adjust for the ASCII bias
	LBGE	DIREC1		; branch if greater than zero
	LDI 0\ LBR DIRE12	; less than zero - use zero instead
DIREC1:	SMI MAXCOL\ LBNF DIRE11	; would it be greater than MAXCOL-1?
	LDI MAXCOL-1\ LBR DIRE12; yes - just use MAXCOL-1 instead
DIRE11:	LDN T1\ SMI ' '		; the original coordinate is OK
DIRE12:	STR	T2		; and update CURSX

; Now handle the Y coordinate (in SAVCHR) the same way...
	INC T1\ INC T2		; point to CURSY
	LDN T1\ SMI ' '		; pretty much the same as before
	LBGE	DIREC2		; branch if greater than zero
	LDI 0\ LBR DIRE22	; nope - use zero instead
DIREC2:	SMI MAXROW\ LBNF DIRE21	; is it too big for the screen?
	LDI MAXROW-1\ LBR DIRE22; yes - use the bottom margin instead
DIRE21:	LDN T1\ SMI ' '		; the value is OK - get it back again
DIRE22:	STR	T2		; and update CURSY

;   Finally, update the cursor on the screen and we're done.  DON'T FORGET to
; change the next state (ESCSTA) to zero to mark the end of this sequence!
	LDI 0\ CALL(ESCSET)	; next state is zero (back to normal)
	LBR LDCURS

	.SBTTL	Select Graphics, Reverse Video and Alternate Keypad

;++
;   On the VT52, the <ESC>F command selects the alternate character set, and
; the <ESC>G command deselects it.  The SI (Shift In) and SO (Shift Out)
; control characters do the same...
;--

; Enable the alternate character set...
ENAACS:	RLDI(T1,ACSMOD)		; point to the ACS mode flag
	LDI $FF\ STR T1		; set it to non-zero to enable
	LBR SHRET		; and we're done

; Disable the alternate character set...
DSAACS:	RLDI(T1,ACSMOD)		; same as before
	LDI 0\ STR T1		; but set the ACS flag to zero
	LBR SHRET		; ...


;++
;   The sequence <ESC>r selects reverse video.  It's exactly the same as the
; sequence <ESC>NP and is for compatability with the VIS1802.
;--
ENARVV:	LDI 'P'\ LBR WFAC2	; store the reverse video attribute


;++
;   And the sequence <ESC>n selects normal video and is equivalent to the
; sequence <ESC>N@.  This too is for compatability with the VIS1802.
;--
DSARVV:	LDI '@'\ LBR WFAC2	; store the normal video attribute


;++
;   The sequence <ESC> = slects alternate keypad mode, and <ESC> > selects
; normal (numeric) keypad mode ...
;--

; Select alternate keypad mode ...
ALTKPD:	RLDI(T1,KPDALT)		; point to the alternate keypad mode flag
	LDI $FF\ STR T1		; and make it non-zero for alternate mode
	LBR SHRET		; ...

; Select numeric keypad mode ...
NUMKPD:	RLDI(T1,KPDALT)		; same as above!
	LDI $00\ STR T1		; but set it to zero for numeric keypad mode
	LBR SHRET		; ...

	.SBTTL	Write Field Attribute Code

;++
;   This routine is called to processes the Write Field Attribute escape
; sequence.  The <ESC>N sequence is followed by a single parameter byte, the
; the lower 6 bits of which are written to screen memory as an 8275 field
; attribute code (refer to the 8275 data sheet for more information).  The
; 8275 is set up in non-transparent attribute mode, so each attribute byte
; requires a character location on the screen (which is blanked by the VSP
; output).
;
;   This allows us to get blinking, reverse video, and strikethru, as well
; as select any one of four alternate character sets stored in the EPROM.
; Needless to say, the VT52 didn't have this function!
;
;   Sequence	Attribute
;   --------	------------
;   <ESC>N@	Normal video
;   <ESC>NA	highlight (bold)
;   <ESC>NB	blinking
;   <ESC>NH	alternate font 1 (GPA1)
;   <ESC>ND	alternate font 2 (GPA2)
;   <ESC>NL	alternate font 3 (GPA3)
;   <ESC>NP	reverse video
;   <ESC>N 	strikethru (<ESC>N space!, 0x1B 0x4E 0x20)
;
;   Note that attributes can be combined by ORing the bit patterns.  For
; example, <ESC>NC gives bold blinking, or <ESC>N" gives strikethru blinking.
; Also the special code <ESC>r is equivalent to <ESC>NP and selects reverse
; video.  Likewise <ESC>n is equivalent to <ESC>N@ and selects normal video.
; These two codes are implemented for compatability with the VIS1802.
;
;   And one last comment - if you're wondering why font 1 is <ESC>NH and font 2
; is <ESC>ND when it seems like they should be reversed, it's because there's
; an error in the VT1802 PCB and GPA1 is connected to A11 and GPA0 to A12.
; That swaps the codes for 1 and 2.
;--
WFAC:	LDI EANEXT\ LBR ESCNXT	; wait for the field attribute code

; Here when we receive the next byte...
WFAC1:	LDI 0\ CALL(ESCSET)	; first, set ESCSTA to zero
 	RLDI(T1,CURCHR)\ LDN T1	; and then get the current character
WFAC2:	ANI $3F\ ORI $80	; make it into a field attribute code
	STR	SP		; save it on the stack for NORMA1
	RLDI(T1,TOPLIN)		; point to top line of screen
	LBR	NORMA1		; and then go store it in screen memory

	.SBTTL	Write Line Drawing Code

;++
;   The <ESC>l sequence writes an i8275 line drawing attribute code to the
; screen memory.  The <ESC>l should be followed by a single character that
; specifies the line segment to be drawn, according to this list -
;
;   Sequence	Line
;   --------	------------
;   <ESC>l@	top left corner
;   <ESC>lD	top right corner
;   <ESC>lH	bottom left corner
;   <ESC>lL	bottom right corner
;   <ESC>lP	top intersect
;   <ESC>lT	right intersect
;   <ESC>lX	left intersect
;   <ESC>l\	bottom intersect
;   <ESC>l`	horizontal line
;   <ESC>ld	vertical line
;   <ESC>lh	crossed lines
;
;   Notice that, like the field attribute codes, the lower six bits of the
; character are simply the line drawing code that gets written to memory.
;--
WLINE:	LDI ELNEXT\ LBR ESCNXT	; wait for the line drawing code

; Here when we receive the next byte ...
WLINE1:	LDI 0\ CALL(ESCSET)	; end of escape sequence
 	RLDI(T1,CURCHR)\ LDN T1	; and then get the current character
	ANI $30\ XRI $30	; disallow the 8275 special function codes!
	LBZ	WLINE2		;  ... just ignore them
	LDN	T1		; ok - make it into a character attribute code
	ANI $3F\ ORI CC.LINE	; ...
	STR	SP		; save it on the stack for NORMA1
	RLDI(T1,TOPLIN)		; point to top line of screen
	LBR	NORMA1		; and then go store it in screen memory
WLINE2:	LBR SHRET		; just ignore illegal characters

	.SBTTL	Identify (Answerback) Function

;++
;   If we receive the escape sequence <ESC>Z (identify) then we respond by
; sending <ESC>/K (VT52 without copier).  If we receive a Control-E (ENQ) then
; we respond the same.  Not sure if a real VT52 did the latter, but it's the
; standard ASR-33 answerback code.   FWIW, I believe this is the only case
; where we send a reply back to the host!
;--
IDENT:	LDI	CH.ESC		; send <ESC>
IDENT1:	CALL(SERPUT)		; ...
	 LBDF	 IDENT1		; ... loop if the buffer is full
	LDI	'/'		; ...
IDENT2:	CALL(SERPUT)		; ...
	 LBDF	 IDENT2		; ...
	LDI	'K'		; and the last byte
IDENT3:	CALL(SERPUT)		; ...
	 LBDF	 IDENT3		; ...
	LBR SHRET

	.SBTTL	Raster Test

;++
;   This routine will implement the raster test escape sequence.  The <ESC>Q
; sequence is followed by a single printing character, and the cursor is then
; moved to the home position and the entire screen is filled with this
; character. If the next character after this function should happen to not be
; a printing character, then the screen is filled with blanks...
;
;   Note that this is an extension to the VT52 command set!
;--
RTEST:	LDI ERNEXT\ LBR ESCNXT	; wait for the next byte

; Here with the raster test character in CURCHR...
RTEST1:	LDI 0\ CALL(ESCSET)	; first set ESCSTA to zero
	RLDI(T1,CURCHR)\ LDN T1	; then get the current character
	SMI ' '\ LBNF ERASE	; make sure it is a printing character
	LDN	T1		; get the character back again
	XRI $7F\ LBZ ERASE	; make sure it isn't RUBOUT
	LDN T1\ LBR FILL	; otherwise go fill the screen with it

	.SBTTL	Control Character Dispatch Table

;++
;   This table is used by LBRI and VTPUTC to dispatch to the correct function
; for any ASCII code .LT. 32.  Any unused control characters should just
; point to NOOP, which simply returns with no action.
;--

	PAGE

CONTRL:	STR SP\ ADD\ ADD	; multiply index by three
	ADI LOW(CTLTAB)\ PLO R3	; add base and jump to it

CTLTAB:	LBR	NOOP		; 0x00 ^@ NUL
	LBR	NOOP		; 0x01 ^A SOH
	LBR	NOOP		; 0x02 ^B STX
	LBR	NOOP		; 0x03 ^C ETX
	LBR	NOOP		; 0x04 ^D EOT
	LBR	IDENT		; 0x05 ^E ENQ - identify (send answerback)
	LBR	NOOP		; 0x06 ^F ACK
	LBR	BELL		; 0x07 ^G BEL - ring the "bell"
	LBR	LEFT		; 0x08 ^H BS  - cursor left (backspace)
	LBR	TAB		; 0x09 ^I HT  - move right to next tab stop
	LBR	LINEFD		; 0x0A ^J LF  - cursor down and scroll up
	LBR	LINEFD		; 0x0B ^K VT  - vertical tab is the same as LF
	LBR	ERASE		; 0x0C ^L FF  - form feed erases the screen
	LBR	CRET		; 0x0D ^M CR  - move cursor to left margin
	LBR	DSAACS		; 0x0E ^N SO  - select normal character set
	LBR	ENAACS		; 0x0F ^O SI  - select alternate character set
	LBR	NOOP		; 0x10 ^P DLE
	LBR	NOOP		; 0x11 ^Q DC1
	LBR	NOOP		; 0x12 ^R DC2
	LBR	NOOP		; 0x13 ^S DC3
	LBR	NOOP		; 0x14 ^T DC4
	LBR	NOOP		; 0x15 ^U NAK
	LBR	NOOP		; 0x16 ^V SYN
	LBR	NOOP		; 0x17 ^W ETB
	LBR	NOOP		; 0x18 ^X CAN
	LBR	NOOP		; 0x19 ^Y EM
	LBR	NOOP		; 0x1A ^Z SUB
	LBR	ESCAPE		; 0x1B ^[ ESC - introducer for escape sequences
	LBR	NOOP		; 0x1C ^\
	LBR	NOOP		; 0x1D ^] GS
	LBR	NOOP		; 0x1E ^^ RS
	LBR	NOOP		; 0x1F ^_ US

NOOP:	LBR SHRET

	.SBTTL	Escape Sequence State Table

;++
;   Whenever we're processing an escape sequence, the index of the next
; state is stored in location ESCSTA.  When the next character arrives
; that value is used as an index into this table to call the next state.
;--
#define EQULBR(n,r)	LBR r\n .EQU ($-ESTATE)/3-1

ESCSEQ: STR SP\ ADD\ ADD	; multiply index by three
	ADI LOW(ESTATE)\ PLO R3	; add base and jump to it

ESTATE:	LBR NOOP		; 0 - never used
	EQULBR(EFIRST,ESCAP1)	; 1 - first character after <ESC>
	EQULBR(EYNEXT,DIRECY)	; 2 - <ESC>Y, get first byte (Y)
	EQULBR(EXNEXT,DIRECX)	; 3 - <ESC>Y, get second byte (X)
	EQULBR(ERNEXT,RTEST1)	; 4 - <ESC>Q, get first byte
	EQULBR(EANEXT,WFAC1)	; 5 - <ESC>N, get attribute byte
	EQULBR(ELNEXT,WLINE1)	; 6 - <ESC>l, get line attribute

	.SBTTL	Escape Sequence Dispatch Table

;++
;  All the standard VT52 escape sequences use <ESC> followed by an upper case
; letter (with the exception of the application/numeric keypad, but that's
; handled separately).  This table is used to decode the first character in a
; standard VT52 escape sequence.  Our own custom escape sequences use lower
; case letters, which are handled in the next table.
;--

	PAGE

ESCUPR:	STR SP\ ADD\ ADD	; multiply index by three
	ADI LOW(UPRTAB)\ PLO R3	; add base and jump to it

UPRTAB:	LBR	UP		; <ESC>A -- cursor up
	LBR	DOWN		; <ESC>B -- cursor down
	LBR	RIGHT		; <ESC>C -- cursor right
	LBR	LEFT		; <ESC>D -- cursor left
	LBR	ERASE		; <ESC>E -- erase screen
	LBR	ENAACS		; <ESC>F -- select alternate character set
	LBR	DSAACS		; <ESC>G -- select ASCII character set
	LBR	HOME		; <ESC>H -- cursor home
	LBR	RLF		; <ESC>I -- reverse line feed
	LBR	EEOS		; <ESC>J -- erase to end of screen
	LBR	EEOL		; <ESC>K -- erase to end of line
	LBR	NOOP		; <ESC>L -- unimplemented
	LBR	NOOP		; <ESC>M -- unimplemented
	LBR	WFAC		; <ESC>N -- write field attribute code
	LBR	NOOP		; <ESC>O -- unimplemented
	LBR	NOOP		; <ESC>P -- unimplemented
	LBR	NOOP		; <ESC>Q -- unimplemented
	LBR	RTEST		; <ESC>R -- raster test
	LBR	NOOP		; <ESC>S -- unimplemented
	LBR	NOOP		; <ESC>T -- unimplemented
	LBR	NOOP		; <ESC>U -- unimplemented
	LBR	NOOP		; <ESC>V -- unimplemented
	LBR	NOOP		; <ESC>W -- unimplemented
	LBR	NOOP		; <ESC>X -- unimplemented
	LBR	DIRECT		; <ESC>Y -- direct cursor addressing
	LBR	IDENT		; <ESC>Z -- identify


;++
;   And this table decodes escape sequences where the next character after
; the <ESC> is a lower case letter.  These are our own VT1802 custom sequences.
;--

ESCLWR:	STR SP\ ADD\ ADD	; multiply index by three
	ADI LOW(LWRTAB)\ PLO R3	; add base and jump to it

LWRTAB:	LBR	NOOP		; <ESC>a -- unimplemented
	LBR	NOOP		; <ESC>b -- unimplemented
	LBR	NOOP		; <ESC>c -- unimplemented
	LBR	ENACURS		; <ESC>d -- display cursor
	LBR	NOOP		; <ESC>e -- unimplemented
	LBR	NOOP		; <ESC>f -- unimplemented
	LBR	NOOP		; <ESC>g -- unimplemented
	LBR	DSACURS		; <ESC>h -- hide cursor
	LBR	NOOP		; <ESC>i -- unimplemented
	LBR	NOOP		; <ESC>j -- unimplemented
	LBR	NOOP		; <ESC>k -- unimplemented
	LBR	WLINE		; <ESC>l -- draw line
	LBR	NOOP		; <ESC>m -- unimplemented
	LBR	DSARVV		; <ESC>n -- disable reverse video
	LBR	NOOP		; <ESC>o -- unimplemented
	LBR	NOOP		; <ESC>p -- unimplemented
	LBR	NOOP		; <ESC>q -- unimplemented
	LBR	ENARVV		; <ESC>r -- enable reverse video
	LBR	NOOP		; <ESC>s -- unimplemented
	LBR	NOOP		; <ESC>t -- unimplemented
	LBR	NOOP		; <ESC>u -- unimplemented
	LBR	NOOP		; <ESC>v -- enable auto newline
	LBR	NOOP		; <ESC>w -- disable auto newline
	LBR	NOOP		; <ESC>x -- unimplemented
	LBR	NOOP		; <ESC>y -- unimplemented
	LBR	NOOP		; <ESC>z -- unimplemented

	.SBTTL	Advanced Cursor Motions

;++
;   TAB will move the cursor to the next tab stop, which are located in columns
; 9, 17, 25, and 33 (i.e. column 8i+1, 0<=i<=4). But after column 33, a tab
; will only advance the cursor to the next character, and once the cursor
; reaches the right margin a tab will not advance it any further.  This is 
; similar to the way a real terminal works, except that they usually have 80
; columns and 9 tab stops up to column 72.
;--
TAB:	RLDI(T1,CURSX)\ LDN T1	; get the current column of the cursor
	SMI	MAXCOL-8-1	; are we close to the right edge of the screen?
	LBGE	RIGHT		; just do a single right motion if we are
	LDN T1\ ANI $F8		; clear the low 3 bits of the address
	ADI 8\ STR T1		; advance to the next multiple of 8
	LBR	LDCURS		; and also change the picture on the screen


;++
;   Carriage return moves the cursor back to the left margin of the current
; line.  The vertical cursor position doesn't change.
;--
CRET:	RLDI(T1,CURSX)		; point to the X cursor location
	LDI 0\ STR T1		; and set it to the first column
	LBR	LDCURS		; now go tell the 8275

;++
;   CRIGHT is the opposite of carriage return - it moves the cursor to the 
; right margin of the current line ...
;--
CRIGHT:	RLDI(T1,CURSX)		; change the X cursor position
	LDI MAXCOL-1\ STR T1	; to the right margin
	LBR	LDCURS		; update the cursor and we're done


;++
;   This routine will implement the line feed function. This function will
; move the cursor down one line, unless the cursor happens to be on the
; bottom of the screen. In this case the screen is scrolled up one line and
; the cursor remains in the same location (on the bottom line of the screen).
;--
LINEFD: RLDI(T1,CURSY)\ LDN T1	; get the line location of the cursor
	SMI	MAXROW-1	; is it on the bottom of the screen ?
	LBL	DOWN		; just do a down operation if it is
	LBR	SCRUP		; otherwise go scroll the screen up

;++
;   This routine will implement the reverse line feed function.  This
; function will move the cursor up one line, unless the cursor happens to
; be on the top of the screen. In this case the screen is scrolled down one
; line and the cursor remains in the same location (on the screen).
;--
RLF:	RLDI(T1,CURSY)\ LDN T1	; is it on the top of the screen ?
	LBNZ	UP		; just do an up operation if it isn't
	LBR	SCRDWN		; otherwise go scroll the screen down

	.SBTTL	Screen Scrolling Routines

;++
;   This routine will scroll the screen up one line. The new bottom line on
; the screen (which used to be the top line) is then cleared to	all spaces.
; Note that this routine does not change the cursor location (normally it
; won't need to be changed).
;--
SCRUP:	RLDI(T1,TOPLIN)		; pointer to current top line on the screen
	LDN T1\ PLO P1		; get line and remember that for later
	SMI	MAXROW-1	; are we already at the last row on screen?
	LSZ\ ADI MAXROW		; if yes, set to zero, if not add one to row
	STR	T1		; save new row number
	GLO	P1		; then get back the number of the bottom line
	LBR	CLRLIN		; and then go clear it


;++
;   This routine will scroll the screen down one line. The new top line on the
; screen (which used to be the bottom line) is the cleared to all spaces.
; Note that this routine does not change the cursor location (normally it
; won't  need  to be changed).
;--
SCRDWN:	RLDI(T1,TOPLIN)\ LDN T1	; get the top line of the screen
	LSNZ\ LDI MAXROW	; keep if not zero, else get line after last
	SMI 1\ STR T1		; move to previous line and save
	LBR	CLRLIN		; and then go clear it

	.SBTTL	Clear Screen Function

;++
;  This  routine will implement the erase function. This will move the cursor
; to the home position and fill the entire screen with blank characters.
;--
ERASE:	LDI	' '		; fill the screen with a blank character
				; and fall into the fill routine

;++
;   This is a local routine to home the cursor and fill the screen with the
; character contained in D.  Note that the actual frame buffer is larger than
; the number of characters that can be displayed on the screen, and the 
; remainder of the frame buffer is filled with i8275 "end of screen, stop DMA"
; control codes.  This helps to stop screen flickering if the end of row
; interrupts are delayed.
;--
FILL:	PUSHD			; save the fill character for a while

	RLDI(T1,CURSX)		; (CURSX comes before CURSY)
	LDI 0\ STR T1		; set both CURSX and CURSY to zero
	INC T1\ STR T1		; ...

	POPD\ PLO T1		; get the fill character back
	RLDI(T2,SCREEN)		; then point to the start of the screen space
; Fill the active area of the screen with whatever character was given ...
FILL1:	GLO T1\ STR T2\ INC T2	; fill this location
	GHI T2			; have we reached the end of the screen?
	LBNZ FILL1		; no - keep going
	LBR LDCURS		; finally - all done!

	.SBTTL	Screen Erase Functions

;++
;   This routine will erase all characters from the current cursor location
; to the end of the screen, including the character under the cursor.
;--
EEOS:	RLDI(T1,TOPLIN)\ LDN T1	; find the line that's on the top of the screen
	CALL(LINADD)		; then calculate its address in P1
	RCOPY(T2,P1)		; put that address in T2 for a while
	CALL(WHERE)		; and find out where the cursor is
EEOS1:	LDI ' '\ STR P1		; clear this character
	INC	P1		; increment the pointer
	GHI P1 			; have we reached the end of the screen space ?
	LBNZ	EEOS2		; jump if we haven't
	RLDI(P1,SCREEN)		; yes -- wrap around to the start of the screen
EEOS2:	GLO P1\ STR SP		; get the low byte of the address (again!)
	GLO T2\ XOR		; have we reached the top of the screen yet ?
	LBNZ	EEOS1		; keep clearing if we haven't
	GHI P1\ STR SP		; maybe -- we need to check the high byte too
	GHI T2\ XOR		; ????
	LBNZ	EEOS1		; keep on going if we aren't there yet
	LBR SHRET		; otherwise that's all there is to it


;++
;   This routine will clear MAXCOL characters in the display RAM.  This is
; normally used to erase lines for scrolling purposes. It expects the address
; of the first byte to be passed in P1 this byte and the next MAXCOL-1 are set
; to a space character. The loop is unrolled by a factor of four for speed;
; this means that MAXCOL needs to be a multiple of four, which is not unusual.
;--
CLRLIN: SHL\ PLO T1		; index into the line address table
	LDI HIGH(LINTAB)\ PHI T1; now set the high byte
	LDA T1\ PLO P1		; that's the line address
	LDN T1\ PHI P1		; ...

	LDI MAXCOL/8\ PLO T1	; interation count for unrolled loop
	GLO P1\ ADI MAXCOL-1	; address of last byte on line
	PLO P1\ GHI P1\ ADCI 0	; add carry to msb if neededsave it
	PHI P1\ SEX P1		; save and set x=p1

CLRLI1:	LDI ' '			; get a space
	STXD\ STXD\ STXD\ STXD	; and set next four bytes to it
	STXD\ STXD\ STXD\ STXD	; and set next four bytes to it
	DEC T1\ GLO T1		; check loop count
	LBNZ CLRLI1		; repeat until done
	SEX SP\ LBR SHRET	; and that's all for now

;++
;   This routine will erase all characters from the current cursor location to
; the end of the line, including the character under the cursor.
;--
EEOL:	CALL(WHERE)		; set P1 = address of the cursor
	RLDI(T1,CURSX)		; get the current column of the cursor
	LDN T1\ SMI MAXCOL	; figure how many characters until EOL
	PLO	T1		; and save that for later
EEOL1:	LDI ' '\ STR P1		; clear this character to a blank
	INC P1\ INC T1\ GLO T1	; advance to the next character
	LBNZ	EEOL1		; keep going until EOL
	LBR SHRET		; then that's all there is

	.SBTTL	Basic Cursor Motions

;++
;   This routine will implement the home function which moves the cursor to the
; upper left corner of the screen.  Nothing else changes, and no characters
; on the screen are altered.
;--
HOME:	RLDI(T1,CURSX)		; (CURSX comes before CURSY)
	LDI 0\ STR T1		; set both CURSX and CURSY to zero
	INC T1\ STR T1		; ...
	LBR	LDCURS		; then let the user see the change


;++
;   This routine will implement the cursor left function. This will move the
; cursor left one character. If, however, the cursor is already against the
; left  margin of the screen, then no action occurs.
;--
LEFT:	RLDI(T1,CURSX)		; get the cursor column number
	LDN T1\ SMI 1		; and move it left one space
	LBNF	CURRET		; return now if the result is .LT. 0
	STR	T1		; no -- change the software location
	LBR	LDCURS		; and go change the picture on the screen


;++
;   This routine will implement the cursor right function. This will move the
; cursor right one character. If, however, the cursor is already against the
; right margin of the screen, then no action occurs.
;--
RIGHT:	RLDI(T1,CURSX) 		; get the cursor X location
	LDN T1\ XRI MAXCOL-1	; don't allow it to move past this
	LBZ	CURRET		; already at the right margin - quit now
RIGHT1:	LDN T1\ ADI 1\ STR T1	; nope - its safe to increment the cursor
	LBR	LDCURS		; and tell the 8275 about the change


;++
;   This routine will implement the cursor up function.  This will move the
; cursor up one character line. If, however, the cursor is already at the top
; of the screen, then no action occurs.
;--
UP:	RLDI(T1,CURSY)		; get the row which contains the cursor
	LDN T1\ SMI 1		; and move it up one character row
	LBNF	CURRET		; return now if the new position is .LT. 0
	STR	T1		; no -- change the virtual location
	LBR	LDCURS		; and change the picture


;++
;   This routine will implement the cursor down function. This will move the
; cursor down one character line. If, however, the cursor is already at the
; bottom of the screen, then no action occurs.
;--
DOWN:	RLDI(T1,CURSY)		; get the row number where the cursor is
	LDN T1\ XRI MAXROW-1	; don't allow the Y position to exceed this
	LBZ	CURRET		; return if we can't move any more
	LDN T1\ ADI 1\ STR T1	; nope - its safe to increment the cursor
	LBR	LDCURS		; and go tell the 8275

	.SBTTL	Cursor Functions

;++
;   This routine will update the 8275 cursor location so that it agrees with
; the software location.  This is called after most cursor motion functions
; to actually change the picture on the screen...  Uses (but doesn't save) T1!
;
;   If the VISCUR flag is zero, then the cursor display is "hidden" and
; you don't see a cursor on the screen.  The cursor has already been hidden
; in this case by moving it to an off-screen address, we just need to not
; reset it so it stays hidden.
;--
LDCURS:	RLDI(T1,VISCUR)\ LDN T1	; is the cursor hidden ?
	LBZ LDCUR2		; yes -- nothing to do then

; Here to show the real cursor ...
LDCUR1:	SEX T1
	OUT CRTCMD	; give the load cursor command
	OUT CRTPRM		; and output X ...
	OUT CRTPRM		; ... and then Y
LDCUR2:	SEX SP\ LBR SHRET	; ... and return

;++
;   This subroutine will compute the actual address of the character under the
; cursor.  This address depends on the cursor location (obviously) and also
; the value of TOPLIN (which represents the number of the top line on the
; screen after scrolling).  The address computed is returned in P1.
;--
WHERE:	RLDI(T1,TOPLIN)\ LDA T1	; get TOPLIN first
	INC T1\ INC T1		; move to CURSY
	SEX T1\ ADD		; compute TOPLIN+CURSY
	CALL(LINADD)		; set P1 = address of the cursor line
	RLDI(T1,CURSX)		; (LINADD trashes T1!)
	GLO P1\ SEX T1\ ADD	; and add CURSX
	PLO	P1		; put it back
	GHI P1\ ADCI 0\ PHI P1	; and propagate the carry
CURRET:	RETURN			; leave the address in P1 and we're done...


;++
;   The <ESC>h sequence will disable display of the cursor.  The cursor still
; exists as far as the software is concerned, and all the functions that are
; relative to the current cursor position work normally.  All this does is make
; the blinking block disappear from the screen.
;
;   The i8275 doesn't actually have a way to hide or disable the display of
; the cursor, so what we do here is set the cursor to a location that is off
; of the screen, and zero the VISCURS byte so that LDCURS knows not to set
; the location any more since that would unhide it.
;--
DSACURS:RLDI(T1,VISCUR)	; point to the cursor display flag
	LDI 0\ STR T1		; set to zero to hide the cursor

	SEX PC\ OUT CRTCMD	; give the load cursor command
	.BYTE CC.LCUR		; ...
	OUT CRTPRM\ .BYTE 80 	; off-screen regardless of MAXCOL/MAXROW
	OUT CRTPRM\ .BYTE 64	; ...
	SEX SP\ LBR SHRET	; return

;++
;   The <ESC>d sequence will undo the effects of an <ESC>h and re-enable
; display of the cursor ...
;--
ENACURS:RLDI(T1,VISCUR)	; ...
	LDI CC.LCUR\ STR T1	; set the VISCUR flag to CC.LCUR
	LBR LDCUR1		; and display the cursor

	.SBTTL	Compute the Address of Any Line

;++
;   This subroutine will calculate the address of any line on the screen.
; The absolute number of the line (i.e. not relative to any scrolling) should
; be passed in the D and the resulting address is returned in P1...  Uses
; (but doesn't save!) T1...
;--
LINADD: SHL\ PLO T1		; index into the line address table
	LDI HIGH(LINTAB)\ PHI T1; now set the high byte
	LDA T1\ PLO P1		; that's the line address
	LDN T1\ PHI P1		; ...
	RETURN			; and then that's all there is to do

;++
;   This table is used to translate character row numbers into actual screen
; buffer addresses.  It is indexed by twice the row number (0, 2, 4, ... 48) and
; contains the corresponding RAM address of that line, least significant byte
; first, as this aids with arithmetic as we can do LSB first with LDA.
;
;   This table is page aligned so that the LSB of the first entry starts the
; page, this saves having to add one later. Also, the table repeats twice
; so that we can add TOPLIN and CURSY and use it directly as an index without
; wrapping the value around; the modulo operation is built into the table.
;
;   Needless to say, it should have at least MAXROW (times two) entries!
; Note that some display modes have as many as 26 displayed lines.
;--
	.ORG	(($-1)|$FF)+1
	.LSFIRST				; set to lsb first
LINTAB:	.WORD	SCREEN+(( 0%MAXROW)*MAXCOL)	; line #0
	.WORD	SCREEN+(( 1%MAXROW)*MAXCOL)	; line #1
	.WORD	SCREEN+(( 2%MAXROW)*MAXCOL)	; line #2
	.WORD	SCREEN+(( 3%MAXROW)*MAXCOL)	; line #3
	.WORD	SCREEN+(( 4%MAXROW)*MAXCOL)	; line #4
	.WORD	SCREEN+(( 5%MAXROW)*MAXCOL)	; line #5
	.WORD	SCREEN+(( 6%MAXROW)*MAXCOL)	; line #6
	.WORD	SCREEN+(( 7%MAXROW)*MAXCOL)	; line #7
	.WORD	SCREEN+(( 8%MAXROW)*MAXCOL)	; line #8
	.WORD	SCREEN+(( 9%MAXROW)*MAXCOL)	; line #9
	.WORD	SCREEN+((10%MAXROW)*MAXCOL)	; line #10
	.WORD	SCREEN+((11%MAXROW)*MAXCOL)	; line #11
	.WORD	SCREEN+((12%MAXROW)*MAXCOL)	; line #21
	.WORD	SCREEN+((13%MAXROW)*MAXCOL)	; line #13
	.WORD	SCREEN+((14%MAXROW)*MAXCOL)	; line #14
	.WORD	SCREEN+((15%MAXROW)*MAXCOL)	; line #15
	.WORD	SCREEN+((16%MAXROW)*MAXCOL)	; line #16
	.WORD	SCREEN+((17%MAXROW)*MAXCOL)	; line #17
	.WORD	SCREEN+((18%MAXROW)*MAXCOL)	; line #18
	.WORD	SCREEN+((19%MAXROW)*MAXCOL)	; line #19
	.WORD	SCREEN+((20%MAXROW)*MAXCOL)	; line #20
	.WORD	SCREEN+((21%MAXROW)*MAXCOL)	; line #21
	.WORD	SCREEN+((22%MAXROW)*MAXCOL)	; line #22
	.WORD	SCREEN+((23%MAXROW)*MAXCOL)	; line #23
	.WORD	SCREEN+((24%MAXROW)*MAXCOL)	; line #24
	.WORD	SCREEN+((25%MAXROW)*MAXCOL)	; line #25
	.WORD	SCREEN+((26%MAXROW)*MAXCOL)	; line #26
	.WORD	SCREEN+((27%MAXROW)*MAXCOL)	; line #27
	.WORD	SCREEN+((28%MAXROW)*MAXCOL)	; line #28
	.WORD	SCREEN+((29%MAXROW)*MAXCOL)	; line #29
	.WORD	SCREEN+((30%MAXROW)*MAXCOL)	; line #30
	.WORD	SCREEN+((31%MAXROW)*MAXCOL)	; line #31
	.WORD	SCREEN+((32%MAXROW)*MAXCOL)	; line #32
	.WORD	SCREEN+((33%MAXROW)*MAXCOL)	; line #33
	.WORD	SCREEN+((34%MAXROW)*MAXCOL)	; line #34
	.WORD	SCREEN+((35%MAXROW)*MAXCOL)	; line #35
	.WORD	SCREEN+((36%MAXROW)*MAXCOL)	; line #36
	.WORD	SCREEN+((37%MAXROW)*MAXCOL)	; line #37
	.WORD	SCREEN+((38%MAXROW)*MAXCOL)	; line #38
	.WORD	SCREEN+((39%MAXROW)*MAXCOL)	; line #39
	.WORD	SCREEN+((40%MAXROW)*MAXCOL)	; line #40
	.WORD	SCREEN+((41%MAXROW)*MAXCOL)	; line #41
	.WORD	SCREEN+((42%MAXROW)*MAXCOL)	; line #42
	.WORD	SCREEN+((43%MAXROW)*MAXCOL)	; line #43
	.WORD	SCREEN+((44%MAXROW)*MAXCOL)	; line #44
	.WORD	SCREEN+((45%MAXROW)*MAXCOL)	; line #45
	.WORD	SCREEN+((46%MAXROW)*MAXCOL)	; line #46
	.WORD	SCREEN+((47%MAXROW)*MAXCOL)	; line #47
	.WORD	SCREEN+((48%MAXROW)*MAXCOL)	; line #48
	.WORD	SCREEN+((49%MAXROW)*MAXCOL)	; line #49
	.WORD	SCREEN+((50%MAXROW)*MAXCOL)	; line #50
	.WORD	SCREEN+((51%MAXROW)*MAXCOL)	; line #51
	.MSFIRST				; back to msb first

	.SBTTL	Bell (^G) Function

;++
;   Just like a real terminal, we have a bell that can be sounded by the ^G
; character.  This is implemented using the speaker and fixed frequency tone
; generator on the VT1802 - all we have to do is turn it on (easy) and then
; turn it off again in a little bit (harder!).  To arrange for the speaker
; to be turned off, we set the location TTIMER to a non-zero value.  When ever
; TTIMER is non-zero the end of video frame ISR will decrement the counter
; and, when TTIMER makes the 1->0 transition, turns off the speaker.

BELL:	OUTI(TONE,BELLNOTE)	; program the CDP1863 for 440Hz
	SOUND_ON		; and turn on the speaker
	RLDI(T1,TTIMER)		; point to TTIMER
;  The value we store into TTIMER determines the length of the tone, in frames.
; About half a second sounds like a good value...
	LDI BELLTIME		; ...
	STR	T1		; set TTIMER
	SEX SP\ LBR SHRET	; that's all we have to do!

	.SBTTL	Display Startup Splash Screen

;++
;   This routine will display a "splash" screen at startup.  This screen
; the copyright notice, build date, checksum, and the character sets that
; are available.  The screen persiists, and this routine spins here, until
; we receive any input from the PS/2 keyboard or the serial port.  After
; that, the screen is cleared and we return.
;--

SPLASH:	RLDI(T1,SCREEN)		; fill the screen with "pin cushion" symbols
SPL12:	LDI $7F\ STR T1\ INC T1
	GHI T1\ LBNZ SPL12

;   The only goal of all this code is to clear out a rectangle in the middle
; of the screen.  It takes more code then I'd like, but there's no other way!
	RLDI(P1,CURSY)		; point to the Y location
	LDI 2\ STR P1		; and start on line 2
SPL10:	RLDI(P1,CURSX)		; reset X to our right margin
	LDI 2\ STR P1		; ...

; Store 76 spaces in screen memory starting at the current cursor location..
	CALL(WHERE)		; get the screen buffer address in P1
	LDI 76\ PLO T1		; count the characters stored
SPL11:	LDI ' '\ STR P1\ INC P1	; store spaces
	DEC T1\ GLO T1		; count the characters stored
	LBNZ	SPL11		;  ... until we get to 72

; Advance to the next line ...
	RLDI(P1,CURSY)\ LDN P1	; get the current Y location
	ADI 1\ STR P1		; increment the line number
	SMI	MAXROW-2	; have we done 22 lines?
	LBL	SPL10		; nope - go do more

;   Now we have a "frame" of pin cushion symbols with a blank rectangle in the
; middle.  Let's fill all that in with demos of the various video attributes,
; and the character sets...
	CALL(TOUT)		; send all output to the display
	INLMES("\033Y#$")	; first a little self promotion
	OUTSTR(SYSNAM)		; display the name and version number
	INLMES(" CHECKSUM ")
	RLDI(P1,CHKSUM)		; stored here by the romcksum program
	SEX P1\ POPR(P2)	; ...
	CALL(THEX4)		; type that in HEX
	INLMES("\033Y$$")
	OUTSTR(RIGHTS1)		;  ... of this firmware
	.IF (BASIC != 0)
	INLMES("\033Y%$")	; and one more line
	OUTSTR(BRIGHTS)		;  ... to display the BASIC3 notice
	.ENDIF
	INLMES("\033Y&$")	; lastly display the build options
	OUTSTR(SYSOPT)		; ...
	OUTSTR(SPLMS2)		; then display everything else

; Draw a line drawing attributes demo in the upper right corner ...
	OUTSTR(BOX1)\ OUTSTR(BOX2)
	OUTSTR(BOX3)\ OUTSTR(BOX4)
	OUTSTR(BOX5)\ OUTSTR(BOX6)

; Display the four supported fonts ...
	OUTSTR(SPLM50)\ OUTSTR(SPLMS3)
	OUTSTR(SPLM51)\ OUTSTR(SPLMS4)
	OUTSTR(SPLM60)\ OUTSTR(SPLMS3)
	OUTSTR(SPLM61)\ OUTSTR(SPLMS4)
	OUTSTR(SPLM70)\ OUTSTR(SPLMS3)
	OUTSTR(SPLM71)\ OUTSTR(SPLMS4)
	OUTSTR(SPLM80)\ OUTSTR(SPLMS3)
	OUTSTR(SPLM81)\ OUTSTR(SPLMS4)
	INLMES("\033Y\"l")

; Wait for input from either the keyboard or the serial port ...
SPLAS8:	RLDI(T1,RXGETP)\ LDA T1	; get the receiver circular buffer pointer
	SEX T1\ XOR		; does GETP == PUTP ?
	LBNZ	SPLAS9		; buffer not empty if not
	RLDI(T1,KEYGETP)\ LDA T1; same test for the keyboard buffer
	SEX T1\ XOR		; GETP == PUTP?
	LBZ	SPLAS8		; yes - keep waiting

; All done ...
SPLAS9: SEX SP
	INLMES("\033E")		; erase the screen
	CALL(RSTIO)		; reset the console input
	RETURN			; all done

; Messages...
SPLMS2:	.TEXT	"\033Y\(e\033N@"
	.TEXT	"\033Y\(*NORMAL \033N STRIKE THRU\033N@"
	.TEXT	"\033NPREVERSE VIDEO\033N@\033NBBLINKING\033N@"
	.TEXT	"\033NAHIGHLIGHT"
	.TEXT	"\033Y*$FONT 1"
	.TEXT	"\033Y-$FONT 2"
	.TEXT	"\033Y0$FONT 3"
	.TEXT	"\033Y3$FONT 4"
	.BYTE	0
SPLMS3:	.TEXT	"\033F`abcdefghijklmnopqrstuvwxyz{|}~\033G"
	.TEXT	     " !\"#$%&'()*+,-./0123456789:;<=>?"
	.BYTE	0
SPLMS4:	.TEXT	     "@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"
	.TEXT	     "`abcdefghijklmnopqrstuvwxyz{|}~"
	.BYTE	0
SPLM50:	.TEXT	"\033Y*j\033N@\033Y*+\000"
SPLM51:	.TEXT	"\033Y+j\033N@\033Y++\000"
SPLM60:	.TEXT	"\033Y-j\033N@\033Y-*\033NH\000"
SPLM61:	.TEXT	"\033Y.j\033N@\033Y.*\033NH\000"
SPLM70:	.TEXT	"\033Y0j\033N@\033Y0*\033ND\000"
SPLM71:	.TEXT	"\033Y1j\033N@\033Y1*\033ND\000"
SPLM80:	.TEXT	"\033Y3j\033N@\033Y3*\033NL\000"
SPLM81:	.TEXT	"\033Y4j\033N@\033Y4*\033NL\000"
BOX1:	.TEXT	"\033Y\"]\033l@\033l`\033l`\033l`\033l`\033l`\033lP"
	.TEXT	"\033l`\033l`\033l`\033l`\033l`\033lD\000"
BOX2:	.TEXT	"\033Y#]\033ld     \033ld     \033ld\000"
BOX3:	.TEXT	"\033Y$]\033lX\033l`\033l`\033l`\033l`\033l`\033lh"
	.TEXT	"\033l`\033l`\033l`\033l`\033l`\033lT\000"
BOX4:	.TEXT	"\033Y%]\033ld     \033ld     \033ld\000"
BOX5:	.TEXT	"\033Y&]\033lH\033l`\033l`\033l`\033l`\033l`\033l\134"
	.TEXT	"\033l`\033l`\033l`\033l`\033l`\033lL\000"
BOX6:	.TEXT	"\033Y#`I\033Y#eCAN\033Y%^DRAW\033Y%dLINES\000"

	.SBTTL	Initialize i8275 Display

;++
;   This routine will initialize the 8275 CRT controller.  It sends a RESET
; command to the 8275 followed by four parameter bytes which set the format,
; timing, cursor type, etc for the display.  After this, the 8275 will be in
; a known state and it will be stopped (i.e. no DMA and no interrupt requests)
; until we issue a START DISPLAY command.
;
;   BTW, the 8275 chip has a really nasty issue because it lacks any kind of
; RESET or CLEAR input.  When we power up the 8275 can be in any state and
; doing anything.  Worse, after a RESET the 8275 will just blindly continue
; doing whatever it was before.  This is a real problem for the CDP1802, since
; it has no way to inhibit DMA requests AND it uses PC0/DMAPTR after reset!
;
;   To fix this, the VT1802 hardware implements a simple "DISPLAY ON" flip
; flop that's cleared by a RESET/power up.  This inhibits 8275 DMA, interrupts
; and the horizontal and vertical sync outputs to the monitor.  The DISPLAY
; ON flip flop is set, and video is enabled, the first time we read the 8275
; status register.
;--

;++
;   These four bytes are the 8275 parameters after a RESET command ...
;--
; Parameter 1 - select normal spacing, and characters per row ...
CRTCP1	.EQU	$00 + (MAXCOL-1)
; Parameter 2 - rows per VRTC, rows per screen 
CRTCP2	.EQU	(VRTCCNT-1)<<6 + (MAXROW-1)
; Parameter 3 - scan line for underline, scan lines per font
CRTCP3  .EQU	(UNDERLINE-1)<<4 + (SCANLINES-1)
; Parameter 4 - offset line counter, non-transparent field codes,
;		  blinking block cursor, and characters per HRTC
CRTCP4	.EQU	$C0 + (CURSORTYPE<<4) + (HRTCCNT>>1)-1

;++
; Initialize the i8275, but DON'T turn on the display yet!
;--
VTINI:	OUTI(CRTCMD, CC.REST)	;  ... reset the 8275
	OUT CRTPRM\ .BYTE CRTCP1; then write parameter #1
	OUT CRTPRM\ .BYTE CRTCP2; ... #2
	OUT CRTPRM\ .BYTE CRTCP3; ... #3
	OUT CRTPRM\ .BYTE CRTCP4; ... #4
	RLDI(DMAPTR,SCREEN)	; preload the DMA pointer
	RETURN			; and we're done for now

;++
;   Start i8275 display and turn on the video.  Once this is called, DMA and
; interrupts will start occuring immediately.  
;--
DSPON:	OUTI(CRTCMD, CC.EI)	; enable CRTC interrupts
	OUTI(CRTCMD, CC.CPRE)	; preload the counters
; Turn on the video and program the 8275 DMA burst timing.
	OUTI(CRTCMD, CC.STRT+3)	; 8 bytes/DMA burst, no delay detween
; Read the 8275 status register to set the VT1802 VIDEO ON flip flop ...
	SEX SP\ INP CRTSTS	; read status and enable video
	NOP\ INP CRTSTS		; then read it again
	RETURN			; and we're done

;++
; Turn off i8275 video.  After this, all DMA and interrupt requests stop.
;--
DSPOFF:	OUTI(CRTCMD, CC.STOP)	; stop DMA and interrupts ...
	RETURN			; ...

	.SBTTL	Music Notation

;++
;   The music player takes an ordinary ASCII string and interprets it as
; a musical notation of sorts.  The letters A..G (or a..g, since case is
; ignored) refer to the notes A thru G.  Each letter may be followed by a
; "+" or "#" to indicate a sharp, or a "-" to indicate a flat. "DABF#GDGA"
; would get you the famous 8 note cello part from Pachelbel's Canon.
;
;   Other characters have special meanings as well.  The digits 1, 2, 4 or
; 8 specify the note duration - whole note, half note, quarter note or eighth
; note (notice that larger numbers are shorter intervals!).  Sixteenth notes
; are unfortunately not possible - sorry!  The note duration must preceed the
; note ("4D" for a quarter note D, NOT "D4"!) and remain in effect until
; changed by another digit.  So the string "4DABF" would be ALL quarter notes.
;
;   The "," indicates a rest of the same duration as the current note (e.g.
; "1," is a whole rest.  A ">" shifts all notes up one octave and "<" shifts
; all notes down one octave.  The player has an overal range of four octaves,
; from one octave below middle C to two octaves above, and attempts to shift
; above or below this range will be ignored.  There is no way to absolutely
; set the current octave, however something like "<<<<>" would select the
; octave of middle C.
;
;   Spaces in the string are ignored, and playing terminates when any illegal
; character, including EOS ('\0'), is encountered.  
;
;   Summary -
;	A, B, C, D, E, F, G - a note to play
;	# or +, -	    - sharp or flat (place AFTER note!)
;	1, 2, 4, 8	    - note length (whole, half, quarter, eighth)
;	>, <		    - shift up or down one octave
;	,		    - rest (silence)
;	<space>		    - ignored
;
;   Note that by tradition a quarter note lasts one beat, so a whole note is
; 4 beats, a half note is 2 beats, and an eighth note is 1/2 beat.   Yeah,
; it would have been better to start at the eighth note, but I don't make the
; rules!  If the tempo is, say 60 beats per minute, then a quarter note is
; 1 second and a whole note 4 seconds.  Given that we count note times in
; 60Hz VRTC interrupts, at 60 BPM a whole note would be 240 ticks which is
; about the longest count we can fit into one byte.  That makes the slowest
; possible tempo about 60 BPM, which turns out to be pretty reasonable for
; most music.
;
;   Various examples -
;	gg>ddeed,cc<bbaag	- Twinkle, Twinkle Little Star
;	dec<cg			- Close Encounters
;	see below!		- Ode to Joy
;	see below!		- Popcorn
;--

; Beethoven's Ninth, 4th movement (aka Ode to Joy) ...
ODE:	.TEXT	"EEFGGFEDCCDEE8D2D4,EEFGGFEDCCDED8C2C4,"
	.TEXT	"DDECD8EF4ECD8EF4EDCD<G>,EEFGGFEDCCDED8C2C\000"

; Popcorn, Gershon Kingsley, 1969 ...
POPCORN:.TEXT	"8BABF#DF#<B,>BABF#DF#<B,,B>C#DC#D<B>C#<B>C#<ABABGB,,"
	.TEXT	">BABF#DF#<B\000"

	.SBTTL	Play Music

;++
;   The PLay command plays a musical string according to the rules on the
; previous page.  
;--
PLAY:	CALL(LTRIM)\ CALL(ISEOL); skip leading spaces
	LBDF	CMDERR		; error if no argument
	CALL(PLAY1)		; play the actual string
	CALL(CHKEOL)		; and we'd better end with the EOL
	RETURN			; return to the command scanner

; Play a musical demo ...
PDEMO:	CALL(CHKEOL)		; no arguments here
	RLDI(P1,ODE)		; point to the sample tune
				; and fall into PLAY1

; This routine actually plays the string pointed to by P1 ...
PLAY1:	RLDI(T1,OCTAVE)		; initialize OCTAVE, TEMPO and NOTIME
	LDI 0\ STR T1\ INC T1	; octave of middle C
	LDI	HERTZ/3		; a quarter note lasts one half second
	STR T1\ INC T1\ STR T1	; for a 120 BPM tempo

; Play the string pointed to by P1 ...
PLAY2:	CALL(LTRIM)		; ignore any spaces
	CALL(PNOTE)		; try to play a note
	LBNF	PWAIT		; and wait for the note to finish
	CALL(PSPCL)		; is it a "special" character"
	LBNF	PLAY2		; yes - on to the next one
PLAY9:	RETURN			; return when we find anything illegal

;   Wait for the current note to finish playing.  We do this simply by waiting
; for the VRTC ISR to count down the tone timer to zero.  We don't really need
; to turn off interrupts here, because we don't cause any race conditons by
; just watching the count ...
PWAIT:	RLDI(T1,TTIMER)		; wait for the timer to go to zero
PLAY20:	LDN T1\ LBNZ PLAY20	; just spin until it does

;   Now insert a brief break before the next note.  We use the same VRTC ISR
; to count this one too, but we leave the tone generator turned off.
	LDI HERTZ/15\ STR T1
PLAY21:	LDN T1\ LBNZ PLAY21
	LBR	PLAY2		; then play the next note

	.SBTTL	Play One Note

;++
;   This routine will examine the character pointed to by P1 and if it's one
; of the letters A..G then it will start playing that note and return with
; DF=0.  If the character is a ',', then we play a "rest" - this is just like
; a note, except that the tone generator is turned off.  If it's NOT a letter
; A..G or comma then we'll leave P1 unchanged and return with DF=1.
;
;   If it is a letter, A..G, then we advance P1 and look ahead at the next
; character to see if that's a "+" or "#" for a sharp, or "-" for a flat.
; If either of those are found then we move up or down one step in the note
; table and advance P1 past the +/#/- too.  Needless to say, sharps and flats
; don't apply to rests (commas).
;
;   IMPORTANT - our note table covers only one octave, from C to B.  A C-
; (C flat) requires us to shift down one octave and then play a B.  Likewise,
; a B# requires us to shift up an octave and then play C.  We can actually
; do that, but the octave shift will not be undone when the note finishes!
;--
PNOTE:	RLDI(T1,NOTES)		; prepare to search the NOTES table
	LDN P1\ CALL(FOLD)	; get the note letter and fold to upper case
	PHI AUX\ SEX T1		; and save that temporarily
	SMI ','\ LBZ PREST	; handle rests first
PNOTE1:	LDX\ LBZ PNOTE9		; end of note table?
	GHI AUX\ XOR		; does this note match?	
	LBZ	PNOTE2		; yes - play it!
	IRX\ IRX\ LBR PNOTE1	; no match - increment T1 and try again

; Here when we find a match in the NOTES table ...
PNOTE2:	INC P1\ LDN P1		; look ahead to the next character
	SMI '#'\     LBZ PNOTE4	; branch if sharp
	SMI '+'-'#'\ LBZ PNOTE4	; another way to indicate sharps
	SMI '-'-'+'\ LBZ PNOTE5	; and lastly test for a flat

; Play the note pointed to by T1 ...
PNOTE3:	INC T1\ LDN T1\ STR SP	; get the frequency divider
	RLDI(T1,OCTAVE)\ LDN T1	; get the octave shift
	LBZ	PNOTE31		; branch if no shift
	XRI $FF\ LBZ PNOTE32	; branch if shift down
	LDN SP\ SHR\ LSKP	; shift up an octave
PNOTE32:LDN SP\ SHL\ STR SP	; shift down an octave
PNOTE31:SEX SP\ OUT TONE\ DEC SP; program the CDP1863
	SOUND_ON		; and turn on the sound

; Set the note duration and we're done ...
PNOTE30:RLDI(T1,TTIMER)		; set the note duration
	RLDI(T2,NOTIME)		;  ... to the current note duration
	LDN T2\ STR T1		; ...
	CDF\ RETURN		; return DF=0 and we're done

; Here if the note is a sharp ...
PNOTE4:	INC	P1		; skip over the '#' or '+'
	GLO T1\ SMI LOW(NOTEND)	; is this the last note in the table?
	LBNZ	PNOTE41		; no - everything is OK
	CALL(OCTUP)		; yes - bump up an octave
	RLDI(T1,NOTES-2)	; and play the first note in the table
PNOTE41:INC T1\ INC T1		; bump up one half step
	LBR	PNOTE3		; and play that one

; Here if the note is a flat ...
PNOTE5:	INC	P1		; skip over the '-'
	GLO T1\ SMI LOW(NOTES)	; is this the first note in the table?
	LBNZ	PNOTE51		; no - we're fine
	CALL(OCTDN)		; yes - drop down an octave
	RLDI(T1,NOTEND+2)	; and play the last note in the table
PNOTE51:DEC T1\ DEC T1		; drop down one half step
	LBR	PNOTE3		; and play that

;   Here to play a rest ...  Rests are "played" just like notes, however the
; tone generator is turned off.
PREST:	INC	P1		; skip over the ','
	SOUND_OFF		; tone off
	LBR	PNOTE30		; and then "play" that

; Here if we don't find a matching note ...
PNOTE9:	SDF\ RETURN		; return DF=1 and leave P1 unchanged

	.SBTTL	Note Divisors for The CDP1863

;++
;   The table at NOTES gives the name (as an ASCII character) and the
; corresponding divider for the CDP1863.  The sharps and flats have 80H added
; to the ASCII character - this ensures that they will NEVER match when the
; table is searched.  The code handles sharps and flats by finding the letter
; first and then adding or subtracting one table entry.
;
;   Note that in the VT1802 the CDP1863 is clocked by TPB from the 1802, and
; that means that the divisors depend on the CPU clock frequency.  It would
; have been nice to used a fixed frequency here, such as the baud rate clock,
; but that would have required another couple of flip flops to divide it down
; to the range to give audio frequencies.
;
;   The following tables of note divisors are calculated from the CPU clock
; in Hertz, taking into account the pre-scaling of 8 from TPB, and 16 internal
; to the CDP1863. This gives a ratio of 1/128 which is expressed in the
; formula as 1/64 x 1/2 to make it easy to round the result.
;
; Note frequencies for octave = 3...
;--
#define NOTE(f)	(CPUCLOCK/f/64+1)/2
NOTES:	.DB	'C',     NOTE(262)	; 0 middle C
	.DB	'C'+80H, NOTE(277)	; 1 C#/D-
	.DB	'D',     NOTE(294)	; 2 D
	.DB	'D'+80H, NOTE(311)	; 3 D#/E-
	.DB	'E',     NOTE(330)	; 4 E
	.DB	'F',	 NOTE(349)	; 5 F
	.DB	'F'+80H, NOTE(370)	; 6 F#/G-
	.DB	'G',	 NOTE(392)	; 7 G
	.DB	'A'+80H, NOTE(415)	; 8 G#/A-
	.DB	'A',     NOTE(440)	; 9 A
	.DB	'B'+80H, NOTE(466)	;10 A#/B-
NOTEND:	.DB	'B',	 NOTE(494)	;11 B
	.DB	0

;   This constant is used to program the CDP1863 for the Control-G bell tone.
; It can be pretty much anything you want, but right now we use 440Hz (A above
; middle C) ...
BELLNOTE  .EQU	NOTE(440)

	.SBTTL	Shift Octaves and Change Note Duration

;++
;   This routine will examine the character pointed to by P1 and if it's one
; of '<', '>', '1', '2, '4', or '8' then it will either shift the octave or
; set the note duration accordingly.  In this case P1 is incremented and DF=0
; on return.  If the character is none of those, then P1 is unchanged and
; DF=1 on return.
;--
PSPCL:	RLDI(T1,OCTAVE)		; point T1 to OCTAVE for later
	LDA	P1		; get the character (and assume it matches!)
	SMI '<'\     LBZ OCTDN	; '<' -> shift down one octave
	SMI '>'-'<'\ LBZ OCTUP	; '>' -> shift up one octave
	INC	T1		; point T1 at TEMPO for later
	SMI '1'-'>'\ LBZ NOTED1	; '1' -> set duration whole note
	SMI '2'-'1'\ LBZ NOTED2	; '2' -> set duration half note
	SMI '4'-'2'\ LBZ NOTED4	; '4' -> set duration quarter note
	SMI '8'-'4'\ LBZ NOTED8	; '8' -> set duration eighth note
	DEC P1\ SDF\ RETURN	; none of those - restore P1 and return DF=1


;  Shift the current notes up one octave, unless we're already at octave +1,
; in which case do nothing ...
OCTUP:	LDN T1\ SMI 1		; get the current octave
	LBZ	OCTUP1		; do nothing if it's already +1
	LDN T1\ ADI 1\ STR T1	; otherwise bump it up one octave
OCTUP1:	CDF\ RETURN		; return DF=0 and we're done


;  Shift the current notes down one octave, unless we're already at octave -1,
; in which case do nothing ...
OCTDN:	LDN T1\ SHL		; get the current octave
	LBDF	OCTDN1		; do nothing if it's already -1
	LDN T1\ SMI 1\ STR T1	; otherwise bump it down one octave
OCTDN1:	CDF\ RETURN		; and return DF=0


;   Here to set the current note duration to a whole, half, quarter or eighth
; note.  The current tempo gives the duration of a QUARTER note in VRTC ticks,
; so for the whole or half notes we have to multiply by 4 or 2, and for the
; eighth note we have to divide by 2.

; Here to select whole notes ...
NOTED1:	LDA T1\ SHL\ SHL	; get current tempo *4
	STR T1\ CDF\ RETURN	; set NOTIME and return

; Here to select half notes ...
NOTED2:	LDA T1\ SHL		; get current tempo *2
	STR T1\ CDF\ RETURN	; set NOTIME and return

; Here to select quarter notes ...
NOTED4:	LDA T1\ STR T1		; quarter note == current tempo
	CDF\ RETURN		; set NOTIME and return

; Here to select eighth notes ...
NOTED8:	LDA T1\ SHR		; get current tempo /2
	STR T1\ CDF\ RETURN	; set NOTIME and return

	.SBTTL	Parse Hex Numbers

;++
; Scan two hexadecimal parameters and return them in registers P4 and P3...
;--
HEXNW2:	CALL(HEXNW)		; scan the first parameter
	RCOPY(P3,P2)		; return first parameter in P3
	CALL(ISEOL)		; there had better be more there
	LBDF	CMDERR		; error if not
	CALL(HEXNW)		; scan the second parameter
	RCOPY(P4,P2)		; return second parameter in P4
	RETURN			; and we're done

;++
;   Scan a single hexadecimal parameter and return its value in register P2.
; Leading spaces are ignored, and on return P1 will point to the first non-
; hexadecimal character found.  If NO hexadecimal digits are found, then we
; branch to CMDERR and abort this command.
;--
HEXNW:	CALL(LTRIM)\ RCLR(P2)	; ignore leading spaces and clear result
	CALL(ISHEX)\ LBDF CMDERR; quit if first char isn't a hex digit
HEXNW1:	PUSHD			; save the current digit
	RSHL(P2)\ RSHL(P2)	; shift the current value left 4 bits
	RSHL(P2)\ RSHL(P2)	; ...
	IRX			; point to the original digit
	GLO P2\ OR\ PLO P2	; and add that digit to P2
	INC P1\ CALL(ISHEX)	; is the next character another hex digit?
	LBNF	 HEXNW1		; loop if it is
	RETURN			; otherwise return success!


;++
; This routine will return DF=1 if (P3 .LE. P4) and DF=0 if it is not...
;--
P3LEP4: GHI P3\ STR SP\ GHI P4	; first compare the high bytes
	SM			; see if P4-P3 < 0 (which implies that P3 > P4)
	LBL	P3GTP4		; because it is an error if so
	LBNZ	P3LE0		; return if the high bytes are not the same
	GLO P3\ STR SP\ GLO P4	; the high bytes are the same, so we must
	SM			; ....
	LBL	P3GTP4		; ....
P3LE0:	SDF\ RETURN		; return DF=1
P3GTP4:	CDF\ RETURN		; return DF=0

;++
; This routine will compute P4-P3+1 and return the result in P3 ...
;--
P4SBP3:	GLO P3\ STR  SP		; subtract the low bytes first
	GLO P4\ SM\  PLO P3	; ...
	GHI P3\ STR  SP		; and then the high bytes
	GHI P4\ SMB\ PHI P3	; ...
	INC P3\ RETURN		; +1 and we're done

	.SBTTL	Command Parsing Functions

;++
;   Examine the character pointed to by P1 and if it's a space, tab, or end
; of line (NULL) then return with DF=1...
;--
ISSPAC:	LDN P1\ LBZ ISSPA1	; return TRUE for EOL
	SMI CH.TAB\ LBZ ISSPA1	; return TRUE for tab too
	SMI	 ' '-CH.TAB	; lastly, check for a space?
	LBZ	ISSPA1		; that works as well
	CDF\ RETURN		; it's not a space, return DF=0
ISSPA1:	SDF\ RETURN		; it IS a space!


;++
; If the character pointed to by P1 is EOL, then return with DF=1...
;--
ISEOL:	CALL(LTRIM)		; ignore any trailing spaces
	LDN P1\ LBZ ISSPA1	; return DF=1 if it's EOL
	CDF\ RETURN		; otherwise return DF=0


;++
; Just like ISEOL, but if the next character is NOT an EOL, then error ..
;++
CHKEOL:	CALL(ISEOL)		; look for the end of line next
	LBNF	CMDERR		; abort this command if it's not
	RETURN			; otherwise do nothing


;++
;  Trim leading white space from string pointed to by P1.  Returns with P1
; pointing to the first non-whitespace character in the string (which might
; be the EOS!).
;--
LTRIM:	LDN P1\ LBZ TRMRET	; get the next char and return if EOS
	XRI CH.CRT\ LBZ TRMRET	; stop on <CR>
	LDN P1\ XRI CH.LFD	;  ... or <LF>
	LBZ	TRMRET		;  ...
	LDN P1\ XRI CH.ESC	;  ... or <ESC>
	LBZ	TRMRET		;  ...
	LDN P1\ SMI ' '+1	; otherwise compare to space
	LBGE	TRMRET		; ignore space or any other control characters
	INC P1\ LBR LTRIM	; keep looking
TRMRET:	RETURN			; all done


;++
;   This routine will examine the ASCII character in D and, if it is a lower
; case letter 'a'..'z', it will fold it to upper case.  All other ASCII
; characters are left unchanged...
;--
FOLD:	ANI $7F\ PHI AUX	; only use seven bits
	SMI 'a'\ LBL FOLD1	; branch if .LT. 'a'
	SMI 'z'-'a'+1		; check it against both ends of the range
	LBGE	FOLD1		; nope -- it's not a letter
	GHI AUX\ SMI $20	; it is lower case - convert it to upper case
	RETURN			; and return that
FOLD1:	GHI AUX\ RETURN		; not lower case - return the original


;++
;   This routine will examine the ASCII character at P1 and, if it is a hex
; character '0'..'9' or 'A'..'Z', it will convert it to the equivalent binary
; value and return it in D.  If the character is not a hex digit, then it
; will be returned in D unmolested and the DF will be set.
;--
ISHEX:	LDN P1\ ANI $7F		; get the character
	SMI '0'\ LBL ISHEX3	; branch if .LT. '0'
	SMI  10\ LBL ISHEX2	; branch if it's a decimal digit
	LDN P1\ CALL(FOLD)	; convert lower case 'a'..'z' to upper
	SMI 'A'\ LBL ISHEX3	; branch if .LT. 'A'
	SMI  6\ LBGE ISHEX3	; branch if .GE. 'G'
; Here for a letters 'A' .. 'F'...
	ADI	6		; convert 'A' back to the value 10
; Here for a digit '0' .. '9'...
ISHEX2:	ADI	10		; convert '0' back to the value 0
	CDF\ RETURN		; return DF=0
; Here if the character isn't a hex digit at all...
ISHEX3:	LDN	P1		; get the original character back
	SDF\ RETURN		; and return with DF=1

;++
;   Return DF=0 if the character at P1 is a decimal digit 0..9 AND return the
; corresponding binary value in D.  If the character isn't a digit, then return
; DF=1 and the original character, unmolested, in D.
;--
ISDIGIT:LDN P1\ ANI $7F		; get the character
	SMI '0'\ LBL NOTDIGT	; branch if .LT. '0'
	SMI 10 \ LBGE NOTDIGT	; branch if .GT. '9'
	ADI	10		; convert the digit to binary
	CDF\ RETURN		; and return DF=0
NOTDIGT:LDN	P1		; return the original character
	SDF\ RETURN		; and return DF=1

	.SBTTL	Console Line Input w/Editing

;++
;   The READLN routine reads an entire line from the console and stores the
; result in a buffer provided by the caller.  Text is echoed as it is read and
; several intraline editing characters are recognized -
;
;   BACKSPACE ($08) - erase the last character input
;   DELETE    ($7F) - same as BACKSPACE
;   CONTROL-U ($15) - erase the entire line and start over
;   RETURN    ($0D) - echos <CRLF>, terminates input and returns
;   LINE FEED ($0A) - same as RETURN
;   ESCAPE    ($1B) - echos "$" and <CRLF>, then terminates input and returns
;   CONTROL-C ($03) - aborts all input and returns with DF=1
;
;   The BACKSPACE, DELETE and CONTROL-U functions all work by echoing the
; <backspace> <space> <backspace> sequence and assume that you're using a CRT
; terminal (does anybody even use hardcopy these days?).
;
;   The line terminators, RETURN, LINE FEED, ESCAPE and CONTROL-C all insert a
; NULL byte in the buffer to end the string, however the terminator itself is
; not added to the buffer. CONTROL-C returns with DF=1 to signal that input was
; aborted, but the other terminators all return with DF=0.
;
;   Other control characters echo as "^x" where "x" is the printing equivalent,
; however the original ASCII control character will be added to the buffer.
; If the buffer overflows during input then a BELL ($07) will be echoed for
; everything instead of the original character.
;
; CALL:
;	P1 -> buffer address
;	P3 -> buffer size
;	CALL(READLN)
;	DF=1 (CONTROL-C typed) or DF=0 otherwise
;--
READLN:	PUSHR(T1)		; save a work register
	LDI 0\ PLO T1		; and keep a byte count there

; Read the next character and figure out what it is ...
READL1:	CALL(INCHNE)		; read WITHOUT echo
	ANI	$7F		; always trim this input to 7 bits
	LBZ	READL1		; ignore nulls
	PHI	AUX		; and save the character temporarily
	SMI	CH.CTC		; CONTROL-C?
	LBZ	REACTC		; ...
	SMI	CH.BSP-CH.CTC	; BACKSPACE?
	LBZ	REABSP		; ...
	SMI	CH.LFD-CH.BSP	; LINE FEED?
	LBZ	REAEOL		; ...
	SMI	CH.CRT-CH.LFD	; CARRIAGE RETURN?
	LBZ	REAEOL		; ...
	SMI	CH.CTU-CH.CRT	; CONTROL-U?
	LBZ	REACTU		; ...
	SMI	CH.ESC-CH.CTU	; ESCAPE?
	LBZ	REAESC		; ...
	SMI	CH.DEL-CH.ESC	; DELETE?
	LBZ	REABSP		; ...

;   Here for any normal, average, boring, printing ASCII character.  If the
; buffer isn't full, then store this one and echo it.  If the buffer IS full,
; then echo a bell instead and don't store anything.  Remember that we always
; need at least one empty byte left over to store the terminating null!
READL2:	GHI P3\ LBNZ REAU2A	; if the buffer size .GE. 256 then no worries
	GLO P3\ SMI 2		; otherwise be sure there at least 2 bytes free
	LBL	REABEL		; nope - the buffer is full
REAU2A:	GHI AUX\ STR P1		; store the original character in the buffer
	CALL(TFECHO)		; and echo it
	DEC	P3		; decrement the buffer size
	INC	T1		; increment the character count
	INC	P1		; and and increment the buffer pointer
	LBR	READL1		; then go do it all over again

; Here if the buffer is full - echo a bell and don't store anything ...
REABEL:	CALL(TBELL)\ LBR READL1	; and wait for a line terminator

; Here for a BACKSPACE or a DELETE - try to erase the last character ...
REABSP:	CALL(DELCHR)		; do all the real work
	LBDF	REABEL		; ring the bell if there's nothing there
	LBR	READL1		; and then keep going

; Here for CONTROL-U - erase ALL the characters back to the prompt ...
REACTU:	CALL(DELCHR)		; try to delete the last character
	LBNF	REACTU		; and keep going until the buffer is empty
	LBR	READL1		; then start over again

; Here for a CONTROL-C - echo ^C and then terminate input ...
REACTC:	GHI AUX\ CALL(TFECHO)	; echo ^C
	CALL(TCRLF)		; and newline
	LBR	MAIN		; and then restart everything!

; Here for ESCAPE - echo "$" and terminate the input ...
REAESC:	OUTCHR('$')		; echo "$" 
				; and fall into the rest of the EOL code

; Here for RETURN or LINE FEED ...
REAEOL:	CDF			; return DF=0
READL3:	CALL(TCRLF)		; echo <CRLF> regardless 
	LDI 0\ STR P1		; then terminate the input string
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're finally done!

;   This little subroutine erases the last character from the buffer, and from
; the screen as well.  If the buffer is currently empty, then it does nothing
; and returns with DF=1...
DELCHR:	SDF			; assume DF=1
	GLO	T1		; get the character count
	LBZ	DELCH2		; if it's zero then quit now
	CALL(TBACKSP)		; erase the character from the screen
	INC	P3		; increment the buffer size
	DEC	T1		; decrement the character count
	DEC	P1		; and back up the buffer pointer
	LDN	P1		; get the character we just erased
	ANI	~$1F		; is it a control character??
	LBNZ	DELCH1		; no - quit now
	CALL(TBACKSP)		; yes - erase the "^" too
DELCH1:	CDF			; and return with DF=0
DELCH2:	RETURN			; ...

	.SBTTL	Console Output Routines

;   This routine will convert a four bit value in D (0..15) to a single hex
; digit and then type it on the console...
THEX1:	ANI $0F\ ADI '0'	; trim to 4 bits and convert to ASCII
	SMI '9'+1\ LBL THEX11	; branch if this digit is 0..9
	ADI	'A'-'9'-1	; convert 10..15 to letters
THEX11:	ADI	'9'+1		; and restore the original character
	LBR	TCHAR		; type it and return


; This routine will type a two digit (1 byte) hex value from D...
THEX2:	PUSHD			; save the whole byte for a minute
	SHR\ SHR\ SHR\ SHR	; and type type MSD first
	CALL(THEX1)		; ...
	POPD			; pop the original byte
	LBR	THEX1		; and type the least significant digit


; This routine will type a four digit (16 bit) hex value from P2...
THEX4:	GHI	P2		; get the high byte
	CALL(THEX2)		; and type that first
	GLO	P2		; then type the low byte next
	LBR	THEX2		; and we're done


;++
;   Send an entire ASCIZ (null terminated) string to the serial port.  A
; pointer to the string is passed in P1, and we return with P1 pointing to
; the byte AFTER the NULL at the end of the string.  That's essential for
; INLMES, below.   Note that this works by calling TCHAR, so if the buffer
; fills up, we'll just wait.  Uses T1 (and P1).
;--
TSTR:	LDA	P1		; get the next character
	LBZ	TSTR1		; stop when we find the EOS
	CALL(TCHAR)		; send it
	LBR	TSTR		; and keep going
TSTR1:	RETURN			; ...


;++
;   Send an inline string to the serial port and then return to the next
; byte after the end of the string.  For example -
;
; 	CALL(TMSG)
;	.TEXT	"HELLO WORLD!\000"
;	<return here>
;
; Uses P1 and T1.
;--
TMSG:	RCOPY(P1, A)		; put the string address in P1
	CALL(TSTR)		; type it
	RCOPY(A, P1)		; and then update the return address
	RETURN


; This routine will type a carriage return/line feed pair on the console...
TCRLF:	LDI CH.CRT\ CALL(TCHAR)	; type carriage return
	LDI CH.LFD\ LBR TCHAR	; and then line feed


; Type a single space on the console...
TSPACE:	LDI ' '\ LBR TCHAR	; this is what we want


; Type a (horizontal) tab...
TTABC:	LDI CH.TAB\ LBR TCHAR	; ...


; Type a question mark...
TQUEST:	LDI '?'\ LBR TCHAR	; ...


; Ring the bell (type a ^G) ...
TBELL:	LDI CH.BEL\ LBR TCHAR	; ...


; Type the sequence <BACKSPACE> <SPACE> <BACKSPACE> to erase the last character.
TBACKSP:OUTCHR(CH.BSP)		; type <backspace>
	OUTCHR(' ')		; <space>
	LDI CH.BSP\ LBR TCHAR	; <backspace>

	.SBTTL	Low Level Console I/O

;++
;   Read one character from the console, but with NO echo.  If nothing is
; buffered now, then wait until something is typed ...
;--
INCHNE:	CALL(CONGET)		; try to get a character
	LBDF	INCHNE		; and wait until one appears
	RETURN			; ...


;++
;   Read one character from the console, with echo.  If nothing is buffered
; now, then wait until something is typed.  Note that we CAN'T call TCHAR
; here for the echo - we don't know that the console output is going to the
; same device as input comes from.  We have to call TECHO instead.
;--
INCHRW:	CALL(INCHNE)		; wait for a character
	ANI $7F\ LBZ INCHRW	; trim to 7 bits and ignore NULs
	PUSHD\ CALL(TFECHO)	; echo it
	POPD\ RETURN		; restore the character and return


;++
;   Echo user input by calling CONECHO rather than CONPUT.  All printing
; characters are echoed normally, but "funny" characters are handled specially.
; ASCII control characters are printed as "^x", where "x" is the printing
; equivalent, with the the exception of 
;
;	<ESC> ($1B) which echos as "$"
;	<CR>  ($0D) which echos as itself
;	<BS>  ($08) which echos as itself
;--
TFECHO:	PHI	AUX		; save the character for a moment
	SMI ' '\ LBGE TFECH2	; if it's not a control character, echo it
	GHI AUX\ SMI CH.ESC	; is it an escape?
	LBZ	TFECH0		; yes - echo "$"
	GHI AUX\ SMI CH.CRT	; is it a carriage return?
	LBZ	TFECH2		; yes - echo literally
	GHI AUX\ SMI CH.BSP	; is it a backspace ?
	LBZ	TFECH2		; echo that literally
; Here to echo a control character as ^X ...
TFECH1:	GHI AUX\ PUSHD		; save the character more permanently
	LDI '^'\ CALL(TECHO)	; echo a "^" first
	POPD\ ADI '@'\ LBR TECHO; and print the printing equivalent
; Here to echo <ESC> as $ ...
TFECH0:	LDI '$'\ LBR TECHO	; yes - echo escape as "$"
; Here to echo a <CR> and <LF> ...
;TFECH3:	GHI AUX\ CALL(TECHO)	; echo the original <CR>
;	LDI CH.LFD\ LBR TECHO	; and then add a line feed
; Here to echo a normal printing character ...
TFECH2:	GHI AUX\ LBR TECHO	; restore and echo it


;++
;   Type a character on the console.  If the buffer is currently full, then
; wait until space is available ...
;--
TCHAR:	CALL(CONPUT)		; try to buffer the character
	LBDF	TCHAR		; and keep waiting if we can't
	RETURN			; success!

;++
;   Echo a character to the device associated with the keyboard, rather than
; the console.
;--
TECHO:	CALL(CONECHO)		; otherwise this is the same as TCHAR!
	LBDF	TECHO		; ...
	RETURN			; ...

	.SBTTL	Console Redirection

;++
;   The CONGET and CONPUT RAM locations contain an LBR to the console input
; and console output routines.  This can be either SERGET and SERPUT, or
; GETKEY and VTPUTC, depending on whether the console is directed to the
; serial port or the keyboard/video display.
;
;   CONECHO contains an LBR to the routine used to echo user input.  You
; might think this would always be CONPUT, but if the input and output devices
; are different - for example, input from the PS/2 keyboard but output to the
; serial port - then you want echo to go to the device associated with the
; input.  In this example, output might go to the serial port but echo still
; goes to the video display.
;
;   Lastly, the CONBRK routine is called to test for a break, either ISKBRK
; which tests for the PAUSE/BREAK key on the PS/2 keyboard, or ISSBRK which
; tests for a receiver framing error on the UART.
;--

;++
;   This routine will set the console input, echo and break test routines
; according to the parameters passed inline.
;
;CALL:
;	CALL(SETINP)
;	.WORD	<input routine>
;	.WORD	<echo routine>
;	.WORD	<break test routine>
;--
SETINP:	PUSHR(T1)		; preserve T1 for BASIC
	RLDI(T1,CONGET)		; point to the console vectors
	LDI $C0\ STR T1\ INC T1	; store LBR opcode
	LDA A\ STR T1\ INC T1	; store the address for the input routine
	LDA A\ STR T1\ INC T1	; ...
	LDI $C0\ STR T1\ INC T1	; store LBR opcode
	LDA A\ STR T1\ INC T1	; store the address for the echo routine
	LDA A\ STR T1\ INC T1	; ...
	LDI $C0\ STR T1\ INC T1	; store LBR opcode
	LDA A\ STR T1\ INC T1	; store the address for the break routine
	LDA A\ STR T1\ INC T1	; ...
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're done


;++
;   This routine will set the console output ONLY according to the parameter
; passed inline.
;
;CALL:
;	CALL(SETOUT)
;	.WORD	<output routine>
;--
SETOUT:	PUSHR(T1)		; preserve T1 for BASIC
	RLDI(T1,CONPUT)		; point to the console output vector
	LDI $C0\ STR T1\ INC T1	; store LBR opcode
	LDA A\ STR T1\ INC T1	; store the address for the output routine
	LDA A\ STR T1\ INC T1	; ...
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're done


; Direct console INPUT to the serial port ...
SIN:	CALL(SETINP)		; setup the CONxxx locations ...
	 .WORD	 SERGET		;  ... serial input routine
	 .WORD	 SERPUT		;  ... serial output for echo
	 .WORD	 ISSBRK		;  ... serial break test
	RETURN			; ...

; Direct console OUTPUT to the serial port ...
;   Note that this routine always returns DF=0.  That's used by BRSTIO
; via RSTIO!
SOUT:	CALL(SETOUT)		; setup the CONPUT location
	 .WORD	 SERPUT		;  ... output to the serial port
	CDF\ RETURN		; ...


; Direct console INPUT to the PS/2 keyboard ...
TIN:	CALL(SETINP)		; setup the CONxxx locations ...
	 .WORD	 GETKEY		;  ... PS/2 keyboard input routine
	 .WORD	 VTPUTC		;  ... echo to the video display
	 .WORD	 ISKBRK		;  ... keyboard break test
	RETURN			; ...

; Direct console OUTPUT to the video display ...
;   Note that this routine always returns DF=1.  That's used by BRSTIO
; via RSTIO!
TOUT:	CALL(SETOUT)		; setup the CONPUT location
	 .WORD	 VTPUTC		;  ... output to the serial port
	SDF\ RETURN		; ...


;++
;   And this routine will select the console depending on the setting of
; switch SW6.  SW6=1 selects "local mode", PS/2 keyboard and VIS display
; for the console.  SW6=0 selects "online mode", and the serial port is
; used for console I/O.
;--
RSTIO:	INP DIPSW\ ANI $20	; check the setting of SW6
	LBZ	RSTIO1		; SW6=0 
	CALL(TIN)		; SW6=1 -> select PS/2 keyboard
	LBR	TOUT		;  ... and VIS display
RSTIO1:	CALL(SIN)		; SW6=0 -> select serial port for input
	LBR	SOUT		;  ... and serial port for output

	.SBTTL	Interrupt Service Routine

;++
;   This is the CDP1802 interrupt service routine, and in the VT1802 it gets
; called for any one of four conditions - END OF ROW, END OF FRAME, SERIAL
; PORT, or KEYBOARD.  The serial port and keyboard interrupts are pretty self
; explanatory.  The END OF FRAME interrupt is generated by the 8275 at the
; start of the vertical retrace interval; for NTSC this occurs at 60Hz, or
; once every 16.66ms.
;
;   The END OF ROW interrupts are generated by the VT1802 hardware each time
; the 8275 finishes the DMA transfer for one row of characters.  We need this
; because at every row end we have to check the DMA pointer to see if it's
; reached the end of the screen buffer and, if it has, reset it back to the
; top.  This screen buffer wrap around is necessary for scrolling.
;--

	PAGE	; start new page before ISRs to ensure short branch reach

;++
;   We are able to process multiple interrupt sources per interrupt, which
; avoids overhead of saving and restoring registers when multiple interrupts
; occur simultaneously, or more likely, when a second interruptable event
; happens while we are already in an interrupt handler.
;
;   When an interrupt service routine is finished, it branches back to here
; where we test for additional interrupts. If one is present, we dispatch
; immediately to a "quick" entry point which does not re-save the T1 register
; since we have also not restored it yet. Only when there are no more sources
; pending do we restore T1 and other other registers and return.
;
;   While it's not possible to test for an end-of-row interrupt on an initial
; interrupt assertion, if one happens while we are already in the interrupt
; service routine, then we can test with EF4, because an S3 cycle will not
; have happened to acknowledge it yet. We can also quickly acknowledge the
; interrupt and clear the hardware flip-flop by executing a RET instruction,
; which will return from interupt and then immediately re-enter, triggering
; an S3 cycle. No foreground instructions will execute in-between so we do
; not need to save anything and in fact it's irrelevant what X,P we restore.

ISRDON:	BN_ROWIRQ NOTEOR	; skip if no pending end-of-row interrupt
	DEC SP\ RET		; else acknowledge end-of-row interrupt

	GHI DMAPTR\ BNZ NOTEOR	; skip if DMA pointer has not overflowed
	RLDI(DMAPTR,SCREEN)	; reset the DMA pointer back to the start

NOTEOR:	B_CRTIRQ EOFISQ		; handle end of frame interrupts
	B_SLUIRQ SLUISQ		; handle a serial port interrupts
	B_KEYIRQ KEYISQ		; handle a keyboard interrupt

	IRX\ POPRL(T1)		; restore T1

ISRRET:	IRX\ LDXA\ SHLC		; restore DF
	LDXA\ RET		; restore D then restore X,P to return

;++
;   Here's the interrupt service routine.  When we get here we can assume that
; P=1 and X=2 (the SP).  We need to save T (which contains the old X,P), and
; then D, DF and finally T1.  After that, figure out what caused the interrupt
; and dispatch to some code to handle it.  Note that it's a common 1802 coding
; technique to use M(SP) as a temporary, so we must decrement SP before saving
; anything on the stack to protect any temporary data that the background may
; have there.  
;
;   Note that END OF ROW interrupts occur MAXROW times per frame, about once
; every 640 microseconds!  That's pretty often, especially for a slow witted 
; 1802, so the following ISR code is optimized for that case.  All the other
; interrupts are much less frequent and we can afford to be a bit more lazy
; with them.
;--
ISR:	DEC SP\ SAV		; push T (the saved X,P)
	DEC SP\ STXD		; save D next
	SHRC\ STXD		; and lastly save DF

;++
;   You might think that we could test for an END OF ROW interrupt by checking
; EF4 with the B4, B_ROWIRQ, instruction, but no - that doesn't work.  That's
; because the hardware automatically clears the ROW END flag with the CDP1802
; INTACK cycle occurs, so by the time we get here the flag has gone away.
;
;   Another problem is that an END OF ROW interrupt might occur simultaneously
; with a different interrupt, say serial port or keyboard.  If we test for those
; interrupt sources first and exit w/o servicing the END OF ROW, then this will
; be lost and the screen will glitch.
;
;   The only safe bet is to check the DMA pointer to see if it's reached the
; end of the screen buffer after EVERY interrupt.  If the DMA pointer has hit
; the end of the screen, wrap it around to the start of the screen buffer.
; The scrolling depends on this, and it's the reason why we need interrupts at
; the end of each row...
;--
	GHI DMAPTR\ BNZ ISR1	; skip if DMA pointer has not overflowed
	RLDI(DMAPTR,SCREEN)	; reset the DMA pointer back to the start

;   Now continue with interrupt processing by attempting to indentify the
; interrupt source.  If no other source can be found, then it must have
; been an END OF ROW interrupt and we can just dismiss it now.

ISR1:	B_CRTIRQ EOFISR		; handle end of frame interrupts
	B_SLUIRQ SLUISR		; handle a serial port interrupts
	BN_KEYIRQ ISRRET	; if not keyboard interrupt, then quit

	.SBTTL	Keyboard Interrupt Service

;++
;   This routine is called (via an LBR from the main ISR) when a PS/2 keyboard
; interrupt is detected.  We read the key code from the keyboard, check for
; a few "special" keys, and if it's not one of those then we just add this key
; to the KEYBUF circular buffer.
;
;   Why do we even need this at all?  After all, the PS/2 APU has its own 
; buffer for keys already, and nothing would get lost.  This is here because
; we need to look ahead and check for "special" keys like MENU or BREAK, and
; tell the background code immediately when we find one.
;--
KEYISR:	PUSHR(T1)		; save a register to work with

;   Read the key from the keyboard buffer (which will clear the interrupt
; request at the same time) and check for one of the "special" keys or codes,
; BREAK, MENU or VERSION.  If it's one of those then set the appropriate flag
; but otherwise drop the key code. 
KEYISQ:	RLDI(T1,KEYVER)		; just in case we get lucky :)
	SEX SP\ INP KEYDATA	; read the keyboard port, key on the stack
	ANI KEYVERS\ XRI KEYVERS; is this the firmware version?
	BZ KEYIS4		; yes - go save that
	LDI KEYBREAK\ SD	; is it the BREAK key?
	BZ KEYIS3		; yes 
	LDI KEYMENU\ SD		; and check for the MENU key
	BZ KEYIS2		; ...

; It's a normal key - just add it to the buffer (assuming there's room) ...
	DEC SP			; protect the keycode on the stack
	RLDI(T1,KEYPUTP)\ LDN T1; load the KEYBUF PUT pointer
	ADI 1\ ANI KEYBUFSZ-1	; try incrementing it (w/wrap around!)
	STR SP			; save that temporarily
	DEC T1\ LDA T1\ XOR	; would it equal the GET pointer?
	BZ KEYIS1		; yes - buffer full; discard keystroke
	LDA SP\ STR T1		; no - update the PUT pointer
	ADI LOW(KEYBUF)\ PLO T1	; and index into the buffer
	LDI HIGH(KEYBUF)\ PHI T1; ...
	LDN SP\ STR T1\ SKP	; store the original key code and return
KEYIS1:	INC SP\ BR KEYIS5	; fix the stack and return

;   Here if we receive a version number from the APU firmware, or if either
; the BREAK or MENU key is pressed ...
KEYIS2:	INC T1			; point to KEYMNU
KEYIS3:	INC T1			; point to KEYBRK
KEYIS4:	LDN SP\ STR T1		; update the flag in RAM
KEYIS5:	SEX SP\ BR ISRDON	; and we're done here

	.SBTTL	End of Frame Interrupts

;++
;   Here for the end of frame interrupt.  In this case we need to reset the
; DMA pointer back to the top of the "virtual" screen, based on TOPLIN.  And
; since this ISR is called regularly at a known interval, we use it to time
; several time dependent events.  First we increment the frame counter, which
; is used by the background code to time various events.  Second, we decrement
; the bell timer and, if it's zero, turn off the beeper.  The latter is used
; by the ^G bell function.
;--
EOFISR:	PUSHR(T1)		; save a temporary register
EOFISQ:	INP CRTSTS		; read the status register to clear the IRQ

	RLDI(T1,TOPLIN)		; point to TOPLIN
	LDN T1\ SHL\ PLO T1	; load the value of TOPLIN times two
	LDI HIGH(LINTAB)\ PHI T1; set the high byte
	LDA T1\ PLO DMAPTR	; reset the DMA pointer
	LDN T1\ PHI DMAPTR	;  ... to the top of the screen

;   If the bell timer is non-zero, then the beeper is turned on and we should
; decrement TTIMER.  When TTIMER reaches zero, we turn off the speaker.  This
; is used to implement the ^G bell function of the VT52...
	RLDI(T1,TTIMER)\ PLO T1 ; point to current bell timer
	LDN T1\ BZ EOFIS1	; get and just return now if it's zero
	SMI 1\ STR T1		; otherwise decrement it
	BNZ EOFIS1		; just keep going until it reaches zero
	SOUND_OFF		; turn the speaker off at zero

;   The UPTIME location keeps a 32 bit counter of the VRTC interrupts since
; the system was turned on.  This is used by BASIC to keep track of the time
; of day.  FWIW, a 32 bit counter incremented at 60Hz will take over 800 days
; to overflow!
EOFIS1:	LDI LOW(UPTIME)\ PLO T1	; point to the system uptime counter
	LDN T1\ ADI 1\ STR T1	; and increment the LSB
	BNF EOFIS2\ INC T1	; quit if there's no carry 
	LDN T1\ ADI 1\ STR T1	; ... carry to the next byte
	BNF EOFIS2\ INC T1	; ... and quit if there's no carry 
	LDN T1\ ADI 1\ STR T1	; do the same thing for byte 3
	BNF EOFIS2\ INC T1	; ...
	LDN T1\ ADI 1\ STR T1	; and byte four
				; ... don't care about any carry now!

; Here to return from the frame interrupt...
EOFIS2:	BR ISRDON		; and return

	.SBTTL	Serial Port Interrupt Service

;++
;   This routine is called (via an LBR, not an actual subroutine CALL!) by the
; main interrupt service routine when it detects that the CDP1854 UART is
; requesting an interrupt.  We poll the SLU, figure out what it needs, and then
; branch back to ISRRET to dismiss this interrupt.
;
;   REMEMBER!  This is an ISR, so a) we want to be reasonably fast, and b)
; we have to be careful to save and restore anything we change.  When we get
; here the main ISR has already saved D, DF (and X and P, of course), but
; anything else we use we have to preserve.
;--
SLUISR:	PUSHR(T1)		 ; save a register to work with

;   First, read the UART status register and see if the data available (DA)
; bit is set. If it is, then a new received character has been loaded into
; the holding register. But before reading the character, see if the framing
; error (FE) bit is set.  If it is, then set the SERBRK flag and ignore the
; data in the receiver buffer (it's garbage anyway).  Note that we currently
; ignore the parity error and overrun error bits - it's not clear what useful
; thing we could do with these anyway.

SLUISQ:	INP SLUSTS\ SHR		; is the DA bit set? (SHR because SL.DA=1)
	LBNF SLUIS5		; no - go check the transmitter

	ANI (SL.FE>>1)		; framing error? (>>1 because of SHR above)
	BZ SLUIRX		; no - check for received data

	RLDI(T1,SERBRK)		; point to the serial break flag
	LDI $FF\ STR T1		; and set it to indicate a break received
	LBR SLUIR6		; read and discard the received data

;   See if the UART receiver needs service.  If there's a character waiting,
; then add it to the RXBUF.  If the RXBUF is full, then we just discard the
; character; there's not much else that we can do.  If the buffer is getting
; full then assert flow control as appropriate, if enabled.

SLUIRX:	RLDI(T1,RXGETP)		; load the RXBUF PUT pointer
	SEX T1\ LDXA\ SD	; get number of characters in buffer
	LSDF\ ADI RXBUFSZ	; if negative, add buffer size to adjust

	SMI RXBUFSZ-1		; is the buffer is already full
	BL SLUIR1		; no - check if flow control needed
	SEX SP\ LBR SLUIR6	; yes - read the character but discard it

SLUIR1:	ADI RXBUFSZ-RXSTOP	; is the buffer less than 2/3 full
	LBL SLUIR5		; yes - just get input character

	INC T1\ LDN T1		; get flow control option
	LBZ SLUIR4		; if zero - no flow control needed
	XRI $FF\ BZ SLUIR2	; if ff - do XON/XOFF flow control

; Here for CTS flow control ...
	SEX INTPC\ OUT FLAGS	; clear CTS
	.BYTE FL.CCTS		;  ...
	SEX T1\ LBR SLUIR4	; and now check the transmitter next

; Here for XON/XOFF flow control ...
SLUIR2:	INC T1\ LDN T1		; read the TXONOF flag
	LBNZ SLUIR3		; if already set non-zero do nothing
	LDI $FF\ STR T1		; set to $ff to trigger xoff transmit

; Copy the character into the buffer
SLUIR3: DEC T1			; backup to FLOCTL
SLUIR4: DEC T1			; backup to RXPUTP
SLUIR5:	LDN T1\ ADI 1		; get PUT pointer and increment
	ANI RXBUFSZ-1\ STR T1	; modulo buffer size and update
	ADI LOW(RXBUF)\ PLO T1	; and index into the buffer
	LDI HIGH(RXBUF)\ PHI T1	; ...
SLUIR6:	INP SLUBUF\ SEX SP	; read the character into buffer

;   Before checking the transmitter, check if an end-of-row event has occured
; since this interrupt service started. If so, check the DMA pointer for
; overflow and reset if needed. We also acknowledge the end-of-row event
; so that we don't find it again unnecessarily at ISRDON, see the comments
; there around the details of this.

	BN_ROWIRQ SLUIS5	; skip if no pending end-of-row interrupt
	DEC SP\ RET		; else acknowledge end-of-row interrupt

	GHI DMAPTR\ BNZ SLUIS5	; skip if DMA pointer has not overflowed
	RLDI(DMAPTR,SCREEN)	; reset the DMA pointer back to the start

;   And now see if the UART transmitter needs service.  If the holding register
; is empty and there are more characters in the TXBUF, then transmit the next
; one.  If the buffer is empty, then there's no need to do anything - just
; reading the status will clear the CDP1854 interrupt request, and we can let
; the transmitter go idle.

SLUIS5:	INP SLUSTS\ ANI SL.THRE	; is the THRE bit set?
	BZ	SLUIS3		; no - go check something else
	RLDI(T1,FLOCTL)\ LDN T1	; see if flow control is enabled
	XRI $FF\ BNZ SLUI10	; no - go check the transmit buffer
	INC T1\ LDN T1		; read TXONOF - do we need to send XON or XOFF?
	XRI $FF\ BZ SLUIS6	; branch if we need to send XOFF
	LDN T1\ XRI $01		; do we need to send XON ?
	BNZ	SLUI10		; no - go transmit something from TXBUF

; Here if we need to transmit XON ...
	SEX INTPC\ OUT SLUBUF	; transmit XON
	 .BYTE	 CH.XON		;  ...
	LDI 0\ STR T1		; clear TXONOF
	BR	SLUIS3		; and we're done for now

; Here if we need to transmit XOFF ...
SLUIS6:	SEX INTPC\ OUT SLUBUF	; here to transmit XOFF
	 .BYTE	 CH.XOF		;  ...
	LDI $FE\ STR T1		; set TXONOF to $FE to remember XOFF sent
	BR	SLUIS3		; and we're done for now

; Transmit the next character from the TXBUF ...
SLUI10:	RLDI(T1,TXGETP)\ LDA T1	; load the GET pointer
	SEX T1\ XOR		; does GET == PUT?
	BZ	SLUIS2		; yes - buffer empty!
	DEC T1\ LDN T1		; no - reload the GET pointer
	ADI 1\ ANI TXBUFSZ-1	; increment it w/wrap around
	STR	T1		; update the GET pointer
	ADI LOW(TXBUF)\ PLO T1	; index into the TX buffer
	LDI HIGH(TXBUF)\ PHI T1	; ...
	OUT	SLUBUF		; transmit the character at M(T1)
	BR	SLUIS3		; and on to the next thing

;   Here if the TXBUF is empty AND the THRE bit is set, and at this point we
; need to clear the TR bit.  That alone doesn't do much, however the next
; time we have something to transmit then SERPUT will set the TR bit and
; that will cause another THRE interrupt to start the process again.
SLUIS2:	RLDI(T1,SLUFMT)\ LDN T1	; get the current SLU format bits
	STR SP\ SEX SP		; store it on the stack
	OUT SLUCTL\ DEC SP	; and clear TR
				; and fall into SLUIS3

;   Here after we've checked both the receiver and transmitter.  The CDP1854
; has other interrupt conditions (e.g. PSI or CTS), but we don't care about
; any of those AND they're all cleared by reading the status register.
; There's nothing more to do!
SLUIS3:	SEX SP\ LBR ISRDON	; dismiss the interrupt and we're done


;++
;   This routine will extract and return the next character from the serial
; port receive buffer and return it in D.  If the buffer is empty then it
; returns DF=1.  Uses T1 ...
;
;   Note that we have to disable interrupts while we mess with the buffer
; pointers; otherwise we risk a race condition if a serial port interrupt
; occurs while we're here.
;--
SERGEQ:	STXD			; save the return address

	RLDI(T1,RXGETP)		; load the RXBUF GET pointer
	SEX PC\ DIS		; disable interrupts and SEX T1
	.BYTE (T1<<4)|PC	; ...
	LDXA\ SD\ LBZ SERGE1	; skip if nothing in buffer -- DF is set

	LSDF\ ADI RXBUFSZ	; if negative, add buffer size to adjust
	SMI RXSTART		; is the buffer almost empty?
	LBGE SERGE0		; no - just keep going

	SEX PC\ OUT FLAGS	; yes - enable CTS always
	.BYTE FL.SCTS		; ...

	INC T1\ INC T1\ LDN T1	; read TXONOFF to see if XON needed
	XRI $FE\ LBNZ SERGE2	; if we have not sent XOFF do nothing
	LDI 1\ STR T1		; else send an XON ASAP
	OUT SLUCTL\ .BYTE SL.TR	; and always set the TR bit

SERGE2:	DEC T1\ DEC T1		; point back to PUT pointer
SERGE0:	DEC T1			; point back to GET pointer
	LDN T1\ ADI 1		; increment GET pointer
	ANI RXBUFSZ-1\ STR T1	; modulo the buffer size and update
	ADI LOW(RXBUF)\ PLO T1	; build a pointer into the buffer
	LDI HIGH(RXBUF)\ PHI T1	; add can never overflow -- DF is clear
	LDN T1\ PHI AUX		; load the character and save it

SERGE1:	SEX PC\ RET		; allow interrupts and SEX SP
	.BYTE (SP<<4)|PC	; ...
	LBR SHRET



;++
;   This routine will add a character to the serial port tranmitter buffer.
; If the buffer is currently full, it will return with DF=1 and the original
; character still in D.  Uses T1.
;
;   This is slightly more complicated than it might seem because if the buffer
; is empty and the transmitter is idle, then simply adding this character to
; the buffer won't do anything.  We'll just sit here waiting for a THRE
; interrupt which will never happen.  Fortunately the CDP1854 provides a simple
; way around this - setting the TR bit in the control register will cause an
; interrupt if THRE is also set.  If THRE isn't set and the transmitter is
; already busy, then setting TR does nothing so it's safe to simply always set
; TR, regardless.
;--
SERPUQ:	STXD			; save return address
	IOFF			; interrupts OFF while we mess with the buffer
	RLDI(T1,TXPUTP)\ LDN T1	; load the current PUT pointer first
	ADI 1\ ANI TXBUFSZ-1	; increment it w/wrap around
	STR SP\ DEC T1		; now get the current GET pointer
	LDA T1\ XOR		; would GET == PUT after increment?
	LBZ	SERPU1		; yes - the buffer is full now!
	LDN SP\ STR T1		; no - update the PUT pointer
	ADI LOW(TXBUF)\ PLO T1	; and index into the buffer
	LDI HIGH(TXBUF)\ PHI T1	; ...
	GHI AUX\ STR T1\ DEC SP	; store the original character in the buffer
	OUTI(SLUCTL, SL.TR)	; and always set the TR bit
	SEX SP\ POPD		; restore the original character
	CDF\ LBR SERPU2		; and return DF=0
; Here if the TX buffer is full!
SERPU1:	SDF			; return the original character and DF=1
SERPU2:	ION			; interrupts on again
	LBR SHRET

	.SBTTL	Serial Port Break Routines

;++
;   Test the serial port break flag and return DF=1 (and also clear the flag)
; if it's set. 
;--
ISSBRK:	PUSHR(T1)		; save a temporary
	RLDI(T1,SERBRK)\ LDN T1	; get the flag setting
	LBZ	ISSBR1		; branch if it's not set
	LDI 0\ STR T1		; clear the flag
	SDF\ LSKP		; and return DF=1
ISSBR1:	CDF			; return DF=0
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're done

;++
;   Transmit a break on the serial port by setting the FORCE BREAK bit in the
; CDP1854 control register.  This will force the UART's TXD output low to
; transmit a space condition for as long as the force break bit is set.
; To be detected by the other end we have to remain in this condition for at
; least as long as one character time.  A shorter time may not work, but longer
; does no harm (except to slow things down).
;
;   The way you time this with most UARTs is to set the force break bit and
; then transmit some arbitrary data byte.  The byte never actually gets sent
; (because TXD is held low) but the shift register timing still works and we
; can simply wait for that to finish.  Unfortunately, this DOESN'T WORK with
; the CDP1854!  The 1854 freezes the transmitter entirely while the force
; break bit is set, and nothing will happen with the transmitter status as
; long as it is.
;
;   So we're stuck with timing the interval manually, and we have to be sure
; that it's longer than the time it would take to transmit one byte at the
; slowest baud rate we support.  Worse, once we clear the force break bit,
; the CDP1854 needs us to transmit a byte, which will be turned into garbage
; by the other end since there will be no start bit, to finally and completely
; clear the break condition.  Seems like RCA could have done better!
;--
TXSBRK:	PUSHR(T1)		; save a temporary register
; Set the force break bit in the CDP1854 ...
	RLDI(T1,SLUFMT)\ LDN T1	; get the current SLU character format
	ANI ~SL.IE\ ORI SL.BRK	; clear IE and set break
	STR	SP		; save for out
	OUT SLUCTL\ DEC SP	; write the UART control register
; Now delay for 100ms ...
	LDI 50\ PLO T1		; 50 iterations ...
TXSBR2:	DLY2MS			; ... of a 2ms delay
	DEC T1\ GLO T1		; ...
	LBNZ	TXSBR2		; ...
; Reset the CDP1854 control register and clear the force break bit ...
	LDN	SP		; it's still on the stack!
	ANI ~SL.BRK\ ORI SL.IE	; ...
	STR	SP		; ...
	OUT SLUCTL\ DEC SP	; ...
;   The CDP1854 needs us to transmit a byte, which will be turned into garbage
; by the other end since there will be no start bit, to finally and completely
; clear the break condition.  Note that we don't bother to check THRE here -
; we've just delayed for 100ms; I'm pretty sure it's done now!
	LDI 0\ STR SP		; transmit a null byte
	OUT SLUBUF\ DEC SP	;  ...
; Finish by flushing the serial buffers ...
TXSBR4:	CALL(SERCLR)		; flush the TX and RX buffers
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're done

	.SBTTL	Initialize Serial Port

;++
;   This routine will clear the serial port buffers, both transmit and receive.
; Any characters currently in the buffers are lost!  If flow control is enabled,
; then we will re-enable the other end (either by asserting CTS or sending XON)
; immediately after we're done.
;--
SERCLR:	PUSHR(T1)		; save a temporary
	RLDI(T1,RXPUTP)		; point to the buffer pointers
	IOFF			; no interrupts while we mess with the pointers
	LDI 0\ SEX T1		; ...
	STXD\ STXD		; clear RXPUTP and RXGETP
	STXD\ STXD		; clear TXPUTP and TXGETP
	RLDI(T1,TXONOF)		; clear the XON/XOFF flow control state
	LDI 0\ STXD		; ...
	DEC T1\ STXD		; and clear RXBUFC too
	ION			; interrupts are safe again
	RLDI(T1,FLOCTL)\ LDN T1	; see if flow control is enabled
	LBZ	SERCL9		; not enabled
	XRI $FF\ LBZ SERCL1	; branch if XON/XOFF flow control
; Here for CTS flow control ...
	OUTI(FLAGS, FL.SCTS)	; yes - enable CTS again
	LBR	SERCL9		; and we're done
;   Here for XON/XOFF flow control ...  Note that this ALWAYS sends an XON, 
; even if no XOFF has recently been sent.  This should be harmless!
SERCL1:	INC T1\ LDI 1\ STR T1	; send an XON ASAP
	OUTI(SLUCTL, SL.TR)	; and always set the TR bit
SERCL9:	SEX SP\ IRX\ POPRL(T1)	; restore T1
	RETURN			; and we're done here


;++
;   This routine will initialize the CDP1854 serial port and CDP1963 baud rate
; generator according to the DIP switch settings.  Remember that SW1..3 control
; the baud rate, SW4 ON selects 7E1 format and SW4 OFF selects 8N1  (sorry,
; those are the only options!).  The number of stop bits is set automatically
; based on the baud rate - 1200 and up gets one stop bit, and less than 1200
; gets two stop bits.  And lastly, SW5 ON selectss XON/XOFF flow control and
; SW5 OFF selects CTS flow control.  There is no option to disable flow
; control entirely, but you can always select CTS control and then just leave
; the CTS signal disconnected.
;--

; First initialize the CDP1863 baud rate generator ...
SERINI:	INP DIPSW\ ANI $07	; get the baud rate selection
	ADI LOW(BAUDS)\ PLO T1	; index into the baud rate table
	LDI 0\ ADCI HIGH(BAUDS)	; ...
	PHI T1\ LDN T1\ STR SP	; get the baud rate divisor
	OUT SLUBAUD\ DEC SP	; program the CDP1863

; Select the number of stop bits based on the baud rate ...
	LDI 0\ PLO T1		; build the UART control word here
	INP DIPSW\ ANI $04	; is the baud rate 1200 or up?
	LBNZ	SERIN1		; one stop bit if it is
	LDI SL.SBS\ PLO T1	; nope - select two stop bits

; Now figure out the parity and word length for the CDP1854 ...
SERIN1:	INP DIPSW\ ANI $08	; SW4 selects 7E1 or 8N1 format
	LBZ	SERIN2		; SW4=0 -> 8N1
	LDI SL.7E1\ LSKP	; select even parity and 7 data bits
SERIN2:	LDI SL.8N1\ STR SP	; select no parity and 8 data bits
	GLO T1\ OR		; and OR those with the stop bit select
	ORI SL.IE\ STR SP	; always set interrupt enable
	OUT SLUCTL\ DEC SP	; write the UART control register
	RLDI(T1,SLUFMT)		; and save the UART settings here
	LDN SP\ STR T1		;  ... for later

; Select XON/XOFF or CTS flow control according to SW5 ...
	RLDI(T1,FLOCTL)		; point at the flow control flag
	INP DIPSW\ ANI $10	; and read SW5
	LBNZ	SERIN3		; branch if XON/XOFF is selected
	LDI $01\ LSKP		; select CTS flow control
SERIN3:	LDI $FF\ STR T1		; select XON/XOFF and update FLOCTL
	OUTI(FLAGS, FL.SCTS)	; be sure CTS is asserted regardless
	RETURN			; and we're done here


; Table of baud rate divisors for CDP1863 ...
					;SW3 SW2 SW1	BAUD
BAUDS:	.BYTE	BAUD_DIVISOR( 110)	; 0   0   0	 110
	.BYTE	BAUD_DIVISOR( 150)	; 0   0   1	 150
	.BYTE	BAUD_DIVISOR( 300)	; 0   1   0	 300
	.BYTE	BAUD_DIVISOR( 600)	; 0   1   1	 600
	.BYTE	BAUD_DIVISOR(1200)	; 1   0   0	1200
	.BYTE	BAUD_DIVISOR(2400)	; 1   0   1	2400
	.BYTE	BAUD_DIVISOR(4800)	; 1   1   0	4800
	.BYTE	BAUD_DIVISOR(9600)	; 1   1   1	9600

	.SBTTL	Keyboard Buffer Routines

;++
;   This routine will get the next key code from the keyboard buffer, AND then
; it will handle expanding the special function keys into their corresponding
; VT52 escape codes.  The escape codes are generated by first returning an
; <ESC> and then returning the one or two byte sequence in the KEYESC table
; corresponding to the extended key code.  In order to remember where we are
; in this sequence, we keep a one or two byte "push back" buffer in KEYPBK
; to store the bytes that we'll return next.
;
;   And of course if the next key code is a normal ASCII character, then we
; just return it immediately, with no funny business.
;--

GETKEQ:	STXD			; push return address

	RLDI(T1,KEYPBK)		; anything is waiting in the push back buffer?
	LDN T1\ LBNZ GETKE1	; yes - go send that!

; Try to read the next keycode from the interrupt buffer ...
	IOFF			; no interrupts for now
	RLDI(T1,KEYGETP)\ LDA T1; load the GET pointer
	SEX  T1\ XOR		; does GET == PUT?
	LBZ	KEYGE1		; yes - the buffer is empty!
	DEC T1\ LDN T1		; no - reload the GET pointer
	ADI 1\ ANI KEYBUFSZ-1	; and increment it w/wrap around
	STR	T1		; update the GET pointer
	ADI LOW(KEYBUF)\ PLO T1	; build a pointer into the buffer
	LDI HIGH(KEYBUF)\ PHI T1; ...
	LDN	T1		; load the character
	CDF\ LSKP		; and return with DF=0
KEYGE1:	SDF			; buffer empty - return DF=1
	ION			; allow interrupts again
	PHI AUX
	RLDI(T1,KEYPBK)		; anything is waiting in the push back buffer?

	LBDF	GETKE3		; nothing there - just return now
	GHI AUX\ ANI $80	; is this an extended key code?
	LBZ	GETKE2		; no - regular ASCII character
	DEC T1\ LDA T1		; get the keypad application mode flag
	LBNZ	GETKE0		; branch if application mode
	GHI AUX\ ANI $F0	; was the key code a keypad key
	XRI $A0\ LBZ GETKE4	; yes - handle numeric keypad codes

; Here if we need to send an escape sequence ...
GETKE0:	GHI AUX\ ANI $7F	; get the key code back
	SMI KEYELEN\ LBGE GETKE3; just ignore it if out of range
	GHI AUX\ ANI $7F\ SHL	; each table entry is 2 bytes
	ADI LOW(KEYESC)\ PLO T2	; index into the KEYESC table
	LDI 0\ ADCI HIGH(KEYESC); ...
	PHI T2\ LDA T2\ STR T1	; copy two bytes to KEYPBK
	LBZ	GETKE3		; if the table entry is zero, ignore it
	INC T1\ LDA T2\ STR T1	; ...
	LDI CH.ESC\ PHI AUX	; and return <ESC> for the first byte
	LBR	GETKE2		; ... all done for now

; Here for a keypad key in numeric keypad mode ...
GETKE4:	GHI AUX\ ANI $0F	; get the keycode
	ADI LOW(KEYNUM)\ PLO T2	; index into the numeric keypad table
	LDI 0\ ADCI HIGH(KEYNUM); ...
	PHI T2\ LDN T2\ PHI AUX	; get the ASCII code from the KEYNUM table
	LBR	GETKE2		; and return that

; Here to return the next byte from the push back buffer ...
GETKE1:	PHI	AUX		; save the byte we want to send
	INC T1\ LDN T1		; and pop a byte off the push back buffer
	DEC T1\ STR T1		; ...
	INC T1\ LDI 0\ STR T1	; ...

; Success - we have an ASCII code of some kind ...
GETKE2:	CDF\ LSKP		; return DF=0

; Here if no keys are available ...
GETKE3:	SDF			; return DF=1
	LBR SHRET

;++
;   This routine will extract and return the next character from the keyboard
; buffer and return it in D.  If the buffer is empty then it returns DF=1.
; Uses T1 ...
;
;   Note that we have to disable interrupts while we mess with the buffer
; pointers; otherwise we risk a race condition if a keyboard port interrupt
; occurs while we're here.
;--
;++
;   Test the keyboard break flag and return DF=1 (and also clear the flag)
; if it's set. 
;--
ISKBRK:	PUSHR(T1)		; save a temporary
	RLDI(T1,KEYBRK)\ LDN T1	; get the flag setting
ISKBR0:	LBZ	ISKBR1		; branch if it's not set
	LDI 0\ STR T1		; clear the flag
	SDF\ LSKP		; and return DF=1
ISKBR1:	CDF			; return DF=0
	IRX\ POPRL(T1)		; restore T1
	RETURN			; and we're done

;++
;   Test the keyboard menu flag and return DF=1 (and also clear the flag) if
; it's set.
;--
ISKMNU:	PUSHR(T1)		; save a temporary
	RLDI(T1,KEYMNU)\ LDN T1	; get the flag setting
	LBR	ISKBR0		; and the rest is the same as ISKBRK

	.SBTTL	Keyboard Escape Code Table

;++
;   This table is indexed by the "extended" key code, 0x80..0xFF, which are
; sent by the PS/2 keyboard APU for function keys, keypad keys, arrow keys,
; editing keys, etc.  Each entry contains two bytes which are the escape code
; corresponding to that key (the <ESC> itself being sent first automatically).
; For keys which have only a single character escape sequence (e.g. the arrow
; keys) then the second byte should be zero.
;
;   Note that for the keypad keys these are the APPLICATION keys.  The numeric
; keys are in a separate table.
;--
KEYESC:	.BYTE	  0, 0		; 0x80 BREAK (handled by ISR!)
	.BYTE	"/", "a"	; 0x81 F1  KEY
	.BYTE	"/", "b"	; 0x82 F2  KEY
	.BYTE	"/", "c"	; 0x83 F3  KEY
	.BYTE	"/", "d"	; 0x84 F4  KEY
	.BYTE	"/", "e"	; 0x85 F5  KEY
	.BYTE	"/", "f"	; 0x86 F6  KEY
	.BYTE	"/", "g"	; 0x87 F7  KEY
	.BYTE	"/", "h"	; 0x88 F8  KEY
	.BYTE	"/", "i"	; 0x89 F9  KEY
	.BYTE	"/", "j"	; 0x8A F10 KEY
	.BYTE	"/", "k"	; 0x8B F11 KEY
	.BYTE	"/", "l"	; 0x8C F12 KEY
	.BYTE	  0, 0		; 0x8D SCROLL LOCK (unused)
	.BYTE	  0, 0		; 0x8E NUM LOCK (unused)
	.BYTE	  0, 0		; 0x8F (unused)
	.BYTE	"A", 0		; 0x90 UP ARROW
	.BYTE	"B", 0		; 0x91 DOWN ARROW
	.BYTE	"C", 0		; 0x92 RIGHT ARROW
	.BYTE	"D", 0		; 0x93 LEFT ARROW
	.BYTE	  0, 0		; 0x94 (unused)
	.BYTE	  0, 0		; 0x95 MENU (handled by ISR)
	.BYTE	"/", "n"	; 0x96 END
	.BYTE	"/", "o"	; 0x97 HOME
	.BYTE	"/", "p"	; 0x98 INSERT
	.BYTE	"/", "q"	; 0x99 PAGE DOWN
	.BYTE	"/", "r"	; 0x9A PAGE UP
	.BYTE	"/", "s"	; 0x9B DELETE
	.BYTE	  0, 0		; 0x9C (unused)
	.BYTE	  0, 0		; 0x9D (unused)
	.BYTE	  0, 0		; 0x9E (unused)
	.BYTE	  0, 0		; 0x9F (unused)
	.BYTE	"?", "p"	; 0xA0 KEYPAD 0
	.BYTE	"?", "q"	; 0xA1 KEYPAD 1
	.BYTE	"?", "r"	; 0xA2 KEYPAD 2
	.BYTE	"?", "s"	; 0xA3 KEYPAD 3
	.BYTE	"?", "t"	; 0xA4 KEYPAD 4
	.BYTE	"?", "u"	; 0xA5 KEYPAD 5
	.BYTE	"?", "v"	; 0xA6 KEYPAD 6
	.BYTE	"?", "w"	; 0xA7 KEYPAD 7
	.BYTE	"?", "x"	; 0xA8 KEYPAD 8
	.BYTE	"?", "y"	; 0xA9 KEYPAD 9
	.BYTE	"?", "z"	; 0xAA KEYPAD .
	.BYTE	  0, 0		; 0xAB KEYPAD + (unused)
	.BYTE	"P", 0		; 0xAC KEYPAD / (VT52 F1 BLUE KEY)
	.BYTE	"Q", 0		; 0xAD KEYPAD * (VT52 F2 RED KEY)
	.BYTE	"R", 0		; 0xAE KEYPAD - (VT52 F3 GRAY KEY)
	.BYTE	"?", "M"	; 0xAF KEYPAD ENTER
KEYELEN	.EQU	($-KEYESC)/2

;++
;   This table gives the translation for extended key codes in the range
; 0xA0..0xAF (i.e. the numeric keypad) when keypad application mode is NOT
; enabled!   Note that each one of these entries is only ONE byte!
;--
KEYNUM:	.BYTE	"0"		; 0xA0 KEYPAD 0
	.BYTE	"1"		; 0xA1 KEYPAD 1
	.BYTE	"2"		; 0xA2 KEYPAD 2
	.BYTE	"3"		; 0xA3 KEYPAD 3
	.BYTE	"4"		; 0xA4 KEYPAD 4
	.BYTE	"5"		; 0xA5 KEYPAD 5
	.BYTE	"6"		; 0xA6 KEYPAD 6
	.BYTE	"7"		; 0xA7 KEYPAD 7
	.BYTE	"8"		; 0xA8 KEYPAD 8
	.BYTE	"9"		; 0xA9 KEYPAD 9
	.BYTE	"."		; 0xAA KEYPAD .
	.BYTE	"+"		; 0xAB KEYPAD + 
	.BYTE	"/"		; 0xAC KEYPAD / 
	.BYTE	"*"		; 0xAD KEYPAD *
	.BYTE	"-"		; 0xAE KEYPAD -
	.BYTE	CH.CRT		; 0xAF KEYPAD ENTER

	.SBTTL	XMODEM Protocol

;++
;   These routines will transmit an arbitrary block of RAM, using the XMODEM
; protocol up to the host over the serial port.  And they'll also download an
; arbitrary block of RAM from the host using XMODEM in a similar way.  The
; basic plan for uploading RAM is -
;
;   1) Call XOPENW, which will wait for the host to send us a NAK, indicating
;   that it is ready to receive data.
;
;   2) Call XWRITE to transmit a block of RAM.  Note that XMODEM data blocks
;   are always 128 bytes, however you can call XWRITE with any arbitrary sized
;   chunk of RAM and XWRITE will handle reblocking it.  Also note that you may
;   call XWRITE more than once, for contiguous or discontiguous blocks of RAM,
;   however remember that the addresses and byte counts are NOT transmitted.
;   Only the raw data is saved, so if you want to later download the same file
;   you are responsible for getting everything back in the right spot.
;
;   3) When you're done, call XCLOSEW.  This will transmit any partial XMODEM
;   block remaining and then send an EOT to the host, telling it that we're
;   done.  Note that XMODEM blocks are always 128 bytes, and by tradition any
;   partial block at the end is padded with SUB ($1A, Control-Z) characters.
;
; Downloading a file to RAM goes basically the same way -
;
;   1) Call XOPENR. This will send a NAK to the host, after a short delay,
;   and it should start sending us data.
;
;   2) Call XREAD one or more times to read data from the host.  Once again
;   you can read any arbitrary number of bytes with XREAD, and it will handle
;   reblocking into 180 byte chunks but remember that you're responsible for
;   getting everything back in the right RAM locations.
;
;   3) Call XCLOSER to wait for the host to send EOT, indicating the end of
;   file.  Note that any additional data the host may send while XCLOSER is
;   waiting for EOT will be ignored.
;
;   The XMODEM code uses 132 bytes of RAM for a temporary buffer.  THIS PART 
; OF RAM CANNOT BE UPLOADED OR DOWNLOADED!
;
; ATTRIBUTION
;   Most of this code has been adapted from the original XMODEM written for the
; Elf2K and PicoElf EPROMs by Mike Riley.  That code was copyright 2020 by
; Michael H Riley.  You have permission to use, modify, copy, and distribute
; this software so long as this copyright notice is retained.  This software
; may not be used in commercial applications without express written permission
; from the author.
;--

	.SBTTL	Upload Data to the Host Using XMODEM

;++
;   This routine will open the XMODEM channel for sending data up to the host
; machine.  After initializing a few variables, it waits for the host to send
; us a NAK indicating that it's ready to receive.   Any characters other than
; NAK are ignored.  
;
;   There is a timeout of approximately 10 seconds on waiting for the host to
; send that NAK.  If we time out without receiving it, we return with DF=1.
;
;   Echo on the console is automatically disabled while XMODEM is active.
;--
XOPENW:	PUSHR(P1)		; save working register
	RLDI(P1,XBLOCK)		; current block number
	LDI 1\ STR P1		; set starting block to 1
	INC P1\ LDI 0\ STR P1	; set byte count to zero
	RLDI(P1,5000)		; 5000 times 2ms delay -> 10 second timeout
XOPNW1:	CALL(SERGET)		; read a byte from the serial port w/o waiting
	LBDF	XOPNW2		; branch if nothing was read
	SMI	CH.NAK		; did we get a NAK?
	LBZ	XOPNW3		;  ... yes - success!
XOPNW2:	DLY2MS			; delay for 2ms, more or less
	DBNZ(P1,XOPNW1)		; and count down the 10s timeout
	SDF\ LSKP		; return DF=1 for timeout
XOPNW3:	CDF			; return DF=0 for success
	IRX\ POPRL(P1)		; restore P1
	RETURN			; and we're done


;++
;   This routine will transmit a block of RAM to the host via XMODEM.  P3
; should contain a pointer to the start of the data, and P2 should contain
; a count of the bytes to send.  XMODEM naturally sends data in 128 byte
; byte blocks and this routine will automatically handle reblocking the
; original data, regardless of its actual length.  
;
;   If the data length is not a multiple of 128, meaning that the last XMODEM
; record is partially filled, then data data remains in the XBUFFER.  If this
; routine is called a second time then that additional data is simply appended
; to what's already in the XBUFFER.  If not, then you must call XCLOSEW to
; pad out and transmit the final record.
;
;   Note that at the moment there isn't any error detection or correction
; here.  About the only thing that could go wrong is that we time out waiting
; for the host to respond, or that we get in an infinite retransmit loop.
;
;CALL:
;	P2 -> count of bytes to send
;	P3 -> address of the first byte
;	CALL(XWRITE)
;--
XWRITE:	PUSHR(T2)\ PUSHR(T3)	; save working registers
	RLDI(T3,XCOUNT)\ LDN T3	; get byte count
	STR SP\ PLO T2		; store for add
	LDI LOW(XBUFFER)\ ADD	; index into XBUFFER
	PLO	T3		;  ...
	LDI HIGH(XBUFFER)\ ADCI	0; ...
	PHI	T3		;  ...
XWRIT1:	LDA P3\ STR T3\ INC T3	; copy byte from caller to XBUFFER
	INC T2\ GLO T2		; count bytes in XBUFFER
	ANI $80\ LBZ XWRIT2	; keep going if it's not 128 yet
	CALL(XSEND)		; send current buffer
	LDI 0\ PLO T2		; zero buffer byte count
	RLDI(T3,XBUFFER)	; and start at the beginning of XBUFFER
XWRIT2:	DBNZ(P2,XWRIT1)		; decrement caller's count until it's zero
	RLDI(T3,XCOUNT)		; update XCOUNT with the
	GLO T2\ STR T3		;  ... remaining partial buffer count
	IRX\ POPR(T3)		; restore registers
	POPRL(T2)\ RETURN	; and we're done here


;++
;   This routine is used by XWRITE to send one data block to the host.  It
; fills in the block number and checksum, transmits all 132 bytes, and then
; wait for the ACK or NAK to come back.  If the host NAKs us, then we'll
; send the same record over again.
;--
XSEND:	PUSHR(P1)\ PUSHR(P2)	; save some temporary registers
XSEND0:	LDI CH.SOH\ PHI P2	; send SOH and init checksum in P2.1
	CALL(SERPUW)		; ...
	RLDI(P1,XBLOCK)		; get current block number
	LDN P1\ STR SP		;  ... on the stack
	GHI P2\ ADD\ PHI P2	; add block number to checksum
	LDN SP\ CALL(SERPUW)	; transmit block number
	LDN P1\ SDI 255\ STR SP	; next we send 255 - block nujmber
	GHI P2\ ADD\ PHI P2	; add that to the checksum
	LDN SP\ CALL(SERPUW)	; and transmit it
	LDI 128\ PLO P2		; P2.0 counts number of bytes to send
	RLDI(P1,XBUFFER)	; and P1 points at the data block
XSEND1:	LDA P1\ STR SP		; get next byte to send
	GHI P2\ ADD\ PHI P2	; add it to the checksum
	LDN SP\ CALL(SERPUW)	; then transmit it
	DEC P2\ GLO P2		; decrement byte count
	LBNZ	XSEND1		; keep going until we've sent all 128
	GHI P2\ CALL(SERPUW)	; transmit the checksum byte next
XSEND2:	CALL(SERGEW)\ STR SP	; read the response from the host
	SMI CH.NAK\ LBZ XSEND0	; resend the block if it was a NAK
	RLDI(P1,XBLOCK)\ LDN P1	; otherwise increment the block number
	ADI 1\ STR P1		; ...
	INC P1\ LDI 0\ STR P1	; and zero the buffer byte count
	IRX\ POPR(P2)\ POPRL(P1); restore P1 and P2
	RETURN			; all done


;++
;   This routine will "close" the XMODEM channel.  If there's any partial data
; remaining in the XBUFFER then we'll pad that out with SUB characters to fill
; the full 128 bytes, and transmit it.  After the last block has been sent we
; transmit an EOT, telling the host that we're done, and then wait for an ACK
; to come back.  After that, console echo is re-enabled and we return.
;
;   Note that there's no timeout on waiting for the final ACK from the host.
; There probably should be!
;--
XCLOSEW:PUSHR(P1)\ PUSHR(P2)	; save working registers
	RLDI(P1,XCOUNT)\ LDN P1	; get count remaining in last block
	LBZ	XCLSW2		; if it's zero then we're done
	PLO P2\ STR SP		; ...
	LDI LOW(XBUFFER)\ ADD	; index into XBUFFER again
	PLO P1			; ...
	LDI HIGH(XBUFFER)	; ...
	ADCI 0\ PHI P1		; ...
XCLSW1:	LDI CH.SUB\  STR P1	; fill the rest of the buffer with ^Z
	INC P1\ INC P2		; increment pointer and count
	GLO P2\ ANI $80		; have we done 128 bytes?
	LBZ	XCLSW1		; loop until we have
	CALL(XSEND)		; and then transmit the final block
XCLSW2:	LDI CH.EOT\ CALL(SERPUW); transmit EOT next
	CALL(SERGEW)		; and read the host's response
	SMI	CH.ACK		; did he send an ACK?
	LBNZ	XCLSW2		; keep resending EOT until we get one
	IRX\ POPR(P2)\ POPRL(P1); restore P1 and P2
	RETURN			; and return

	.SBTTL	Download Data from the Host Using XMODEM

;++
;   This routine will open the XMODEM channel for receiving data from the host
; machine.  After initializing all XMODEM related variables, it will delay for
; approximately 10 seconds.  This delay is to give the operator a chance to
; start up the XMODEM transmitter on his end.  When sending, the host will
; wait for us to make the first move by sending a NAK upstream, and after that
; the host will respond by sending the first data block.
;--
XOPENR:	PUSHR(P1)		; save consumed registers
	RLDI(P1,XINIT)		; ...
	LDI CH.NAK\ STR P1	; initially we send a NAK
	INC P1\ LDI   1\ STR P1	; set initial block number to 1
	INC P1\ LDI 128\ STR P1	; set initial count as 128 empty bytes
	INC P1\ LDI   0\ STR P1	; set XDONE = 0
	RLDI(P1,5000)		; 5000 * 2ms -> 10 second delay
XOPNR1:	DLY2MS			; delay for 2 milliseconds
	DBNZ(P1,XOPNR1)		; do that 5000 times
	IRX\ POPRL(P1)		; restore P1
	RETURN			; and return


;++
;   This routine will receive a block of RAM transmitted from the host using
; XMODEM.  P3 should contain a pointer to the start of the RAM block, and P2
; contains a count of the bytes to be written.  XMODEM sends data in 128 byte
; blocks, and this routine will pack up multiple blocks to fill the caller's
; buffer as necessary.  If the size passed in P2 is not a multiple of 128 then
; the last partial block will be left in the XBUFFER.  It can be discarded,
; or it will be used if this routine is called a second time.
;
;   If the host has less data than we want to read - i.e. if it sends an EOT
; before our count is exhausted, then we return with DF=1 and the remainder
; of the buffer will be left unchanged.
;
;CALL:
;	P2 -> count of bytes to receive
;	P3 -> address of the first byte
;	CALL(XREAD)
;--
XREAD:	PUSHR(T2)\ PUSHR(T3)	; save temporary registers
	RLDI(T2,XCOUNT)\ LDN T2	; get current buffer byte count
	PLO T3\ STR SP		; ...
	LDI LOW(XBUFFER)\ ADD	; index into the buffer
	PLO	T2		; ...
	LDI	HIGH(XBUFFER)	; ...
	ADCI 0\ PHI T2		; ...
XREAD0:	GLO T3\ ANI $80		; have we read 128 bytes?
	LBZ	XREAD1		; jump if yes
	CALL(XRECV)		; otherwise receive another block
	LBDF	XREAD2		; quit if EOT received
	LDI 0\ PLO T3		; and reset the buffer to empty
	RLDI(T2,XBUFFER)	; ...
XREAD1:	LDA T2\ STR P3		; copy byte from XBUFFER to caller
	INC P3\ INC T3		; increment pointer and count
	DBNZ(P2,XREAD0)		; keep going until caller's count is zero
	RLDI(T2,XCOUNT)		; update count of bytes remaining in buffer
	GLO T3\ STR T2		; ...
	CDF			; return DF=0 for success
XREAD2:	IRX\ POPR(T3)		; restore registers
	POPRL(T2)\ RETURN	; and we're done here


;++
;   THis routine is used by XREAD to receive one block, verify the block
; number and checksum, and handle the handshake with the host.  If either the
; block or checksum is wrong, the we'll send a NAK back to the host and wait
; for this block to be retransmitted.
;
;   If we receive an EOT, signifying the end of transmission, from the host
; instead of another data block, then we return DF=1.
;--
XRECV:	PUSHR(P1)\ PUSHR(P2)	; save some working room
XRECV0:	CALL(XRDBLK)		; read 128 bytes (more or less)
	LBDF	XRECV3		; jump if EOT received
	RLDI(P1,XHDR2)		; get block number received
	LDN P1\ STR SP		;  ... and store for comparison
	RLDI(P1,XBLOCK)\ LDN P1	; get the block number we expect
	SM\ LBNZ XRECV2		; jump if they aren't the same
	RLDI(P1,XBUFFER)	; point to first data byte
	LDI   0\ PHI P2		; accumulate checksum in P2.1
	LDI 128\ PLO P2		; and count bytes in P2.0
XRECV1:	LDA P1\ STR SP		; add byte from buffer to checksum
	GHI P2\ ADD\ PHI P2	; ...
	DEC P2\ GLO P2		; have we done 128 bytes?
	LBNZ	XRECV1		;  ... keep going until we have
	LDN P1\ STR SP		; get checksum we received
	GHI P2\ SM		; does it match what we computed?
	LBNZ	XRECV2		; request a retransmit if not
	RLDI(P1,XINIT)		; send an ACK for this block
	LDI CH.ACK\ STR P1	; ...
	INC P1\ LDN P1		; increment the block number
	ADI 1\ STR P1		; ...
	INC P1\ LDI 0\ STR P1	; and zero the byte count
	CDF			; return DF=0 for success
XRECV9:	IRX\ POPR(P2)\ POPRL(P1); restore P1 and P2
	RETURN			; and return

; Here if there was some error and we need a re-transmit of the last block ...
XRECV2:	RLDI(P1,XINIT)		; send a NAK
	LDI CH.NAK\ STR P1	; ...
	LBR	XRECV0		; and go try again

; Here if the host sends an EOT (end of transmission!) ...
XRECV3:	RLDI(P1,XDONE)		; set the XDONE flag
	LDI $FF\ STR P1		; ...
	LBR	XRECV9		; and return DF=1 for EOT


;++
;   This routine will "close" the XMODEM download channel.  If we haven't
; already received an EOT from the host, then we'll contine reading (and just
; discarding) data blocks until the host does send us an EOT.  After that
; we turn the console echo back on and we're done.
;--
XCLOSER:PUSHR(P1)		; save a temporary register
	RLDI(P1,XDONE)\ LDN P1	; have we already received an EOT?
	LBNZ	XCLSR2		; yes - don't look for another!
XCLSR1:	CALL(XRDBLK)		; look for EOT but the host may send more data
	LBNF	XCLSR1		; just ignore any extra data until EOT
XCLSR2:	IRX\ POPRL(P1)		; restore P1
	RETURN			; and we're done


;++
;   This routine will read 132 bytes from the host and store them in the XMODEM
; buffer.  This includes the SOH, the block number (two bytes), 128 bytes of
; data, and the checksum.  It doesn't verify any of this; it simply stuffs it
; into the buffer for later review.
;
;   Note that this is the only code that needs to be fast in order to keep up
; with the host and not drop bytes.  Everything else has built in delays while
; waiting for an ACK, NAK or something else, but here the host is sending those
; 132 bytes as fast as it can.  
;
;   One last thing - it's possible that we'll receive an EOT instead of an SOH.
; This indicates that the host is done sending data.  If that happens we'll
; automatically ACK the EOT immediately and then return with DF=1.
;--
XRDBLK:	PUSHR(P1)		; save several working registers
	PUSHR(T1)\ PUSHR(T3)	; ...
	LDI 132\ PLO T1		; expect to receive 132 bytes
	LDI 1\ PHI T1		; and remember this is the first byte
	RLDI(P1,XINIT)\ LDN P1	; get our response (either ACK or NAK)
	PHI T3			;  ... save it temporarily
	RLDI(P1,XHDR1)		; point to input buffer
	GHI T3\ CALL(SERPUW)	; and transmit our ACK/NAK
XRDBK1:	CALL(SERGEW)		; read next byte from host
	STR P1\ INC P1		; store it in the buffer
	GHI T1\ SHR\ PHI T1	; get the first time thru flag
	LBNF	XRDBK2		; jump if not first character
	GHI	AUX		; first character - get it back
	SMI	CH.EOT		; was it an EOT?
	LBNZ	XRDBK2		; jump if not
	LDI CH.ACK\ CALL(SERPUW); send an ACK for the EOT
	SDF\ LBR XRDBK3		; return DF=1 and we're done
XRDBK2:	DEC T1\ GLO T1		; decrement received byte count
	LBNZ	XRDBK1		; and keep going until we've done 132
	CDF			; return DF=0 and we're done
XRDBK3:	IRX\ POPR(T3)		; restore all those registers
	POPR(T1)\ POPRL(P1)	; ...
	RETURN			; and we're done

	.SBTTL	Standard Call and Return Technique

;++
;   These two routines implement the "standard call and return tecnhique", more
; or less right out of the RCA manual.  All assume the following register usage
;
;	R2 (SP)     - stack pointer (1802 stacks grow DOWNWARD!)
;	R3 (PC)     - program counter
;	R4 (CALLPC) - always points to the SCALL routine
;	R5 (RETPC)  - always points to the SRETURN routine
;	R6 (A)	    - subroutine argument list pointer
;
;   A subroutine call goes like this -
;
;	SEP	CALLPC
;	.WORD	<address of subroutine>
;	<any arguments, if desired>
;
; The SCALL routine first pushes the current argument pointer, register R6/A,
; onto the stack.  It then copies the R3/PC, which is the caller's PC to the
; A register.  Next it uses A to fetch the two bytes following the SEP CALLPC,
; which are the address of the subroutine, and load them into the PC register.
; Finally it switches the P register back to R3/PC and the called subroutine
; is running.  The subroutine may use the A register to fetch additional inline
; arguments if desired, being sure to increment A as it does.  
;
;  When the subroutine wants to return it executes a
;
;	SEP	RETPC
;
; This starts the SRETURN routine running, which copies the current A register
; back to the PC, and then pops the previous A value from the stack.  Lastly
; it switches the P register back to R3 and we're back at the caller's location.
;--

; Standard subroutine call ... 18 bytes ...
	.ORG	(($-1)|$FF)+1
	SEP	PC		; start the subroutine running
SCALL:	PHI	AUX		; save the D register
	SEX	SP		; make sure the stack is selected
;   Note that the standard PUSHR macro pushes the low byte first, followed by
; the high byte.  This is consistent with the way the 1804/5/6 RSXD instruction
; works, and also the 1804/5/6 SCAL.  HOWEVER, it's NOT the way the BASIC 
; STCALL routine works, which pushes low byte first!
	GHI A\ STXD		; and save the A register
	GLO A\ STXD		;  ...
	RCOPY(A,PC)		; then copy the caller's PC to A
	RLDA(PC,A)		; fetch the subroutine address
	GHI	AUX		; restore D
	BR	SCALL-1		; restore CALLPC and start the subroutine

; Standard subroutine return ... 16 bytes ...
	SEP	PC		; return to the original caller
SRETURN:PHI	AUX		; save D temporarily
	SEX	SP		; just in case
	RCOPY(PC,A)		; A contains the return address
	INC	SP		; point to the saved A
; See the comments above about this code vs POPRL() !!
	LDA SP\ PLO A		; restore A
	LDN SP\ PHI A		;  ...
	GHI	AUX		; restore D
	BR	SRETURN-1	; restore RETPC and return to the caller

	.SBTTL	The End

	.ORG	CHKSUM-2
	.BLOCK	4

	.END

