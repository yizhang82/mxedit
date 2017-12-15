;==============================================================================================
; TEXT.INC   
; Text routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9
;==============================================================================================

PutChar		PROTO FAR C, Row:BYTE, Column:BYTE, Character:BYTE, Attribute:BYTE
ShowWindow  PROTO FAR C, Left:BYTE, Top:BYTE, Right:BYTE, Bottom:BYTE, Attr:BYTE
ShowLine    PROTO FAR C, Row:BYTE, Column:BYTE, Msg:WORD, Attr:BYTE
ShowWndText PROTO FAR C, Left:BYTE, Top:BYTE, Right:BYTE, Bottom:BYTE, Msg:WORD, Attr:BYTE
EnterString PROTO FAR C, Row:BYTE, Column:BYTE, Prompt:WORD, Attr:BYTE, ColMin:BYTE, ColMax:BYTE, OutStr:WORD

EXTRN SetVideoMode:FAR
EXTRN SetCursor:FAR
EXTRN GetCursor:FAR
EXTRN MoveCursor:FAR

WaitKey     MACRO
            mov     ah, 08h
            int     21h
            ENDM

; Constants
                
; Color Constants
Black       = 0
Blue        = 1
Green       = 2
Cyan        = 3
Red         = 4
Orange      = 5
Brown       = 6
White       = 7
Gray        = 8
LightBlue   = 9
LightGreen  = 10
LightCyan   = 11
LightRed    = 12
LightOrange = 13
Yellow      = 14
BrightWhite = 15 

; Mode constants

Mode80x25x16 = 03h
