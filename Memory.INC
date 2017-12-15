;==============================================================================================
; FILE : Memory.INC
; Memory routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9
;==============================================================================================

NULL        EQU     0
                   
; allocate and free memory
InitMem     PROTO FAR C
MemResize   PROTO FAR C, Mem:WORD, Bytes:WORD, OldSize:WORD
MemAlloc    PROTO FAR C, Bytes:WORD
MemFree     PROTO FAR C, MemSeg:WORD
