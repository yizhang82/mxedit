;==============================================================================================
; FILE : Error.ASM
; Error output routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9
;==============================================================================================
            
            .DOSSEG
            .MODEL  SMALL, C
            
            INCLUDE Error.INC
            INCLUDE Text.INC
            
            .DATA   
Errors      DW   Error0, Error1, Error2, Error3, error4, Error5
Error0      DB   'No error', 0
Error1      DB   'Memory not enough', 0
Error2      DB   'Error freeing memory', 0
Error3      DB   'Cannot open file', 0
Error4      DB   'Cannot access file', 0
Error5      DB   'Cannot create file', 0

            .CODE
OutError    PROC FAR C, Error:BYTE, Quit:BYTE
            push    ds       
            mov     ax, @DATA
            mov     ds, ax
            xor     bx, bx 
            mov     bl, Error 
            shl     bl, 1 
            mov     di, Errors[bx]
            INVOKE  ShowWndText, 10, 5, 50, 9, di, ErrorAttr      
            pop     ds                                      
            WaitKey 
            .IF     Quit == 1
                .EXIT
            .ENDIF
            ret
OutError    ENDP 
            END