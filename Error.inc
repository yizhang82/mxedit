;==============================================================================================
; FILE : Error.INC
; Error output routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9
;==============================================================================================

NoError          = 0 
MemoryNotEnough  = 1
ErrorFreeingMem  = 2
CannotOpenFile   = 3
CannotAccessFile = 4
CannotCreateFile = 5
Abort            = 1
Cont             = 0

ErrorAttr        = 47h

OutError    PROTO FAR C, Error:BYTE, Quit:BYTE

        