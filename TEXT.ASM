;==============================================================================================
; TEXT.ASM
; Text output routines
;==============================================================================================
            .DOSSEG
            .MODEL SMALL, C
   
            .CODE 

; NAME   : PutChar
; FUNC   : Write a char in the specified position using direct memory access
; INPUT  : Row : byte, Column : byte, Character : byte, Attribute : byte
; OUTPUT : none
; CALL   : C-Calling version
PutChar     PROC    FAR C, Row : BYTE, Column : BYTE, Character : BYTE, Attribute : BYTE
            push    es              ; save es
            mov     ax, 0B800H
            mov     es, ax          ; direct memory access address 0b800:0000
            
            ; assume 80x25 16 color (C80) display mode
            mov     ax, 80*2
            xor     dx, dx
            xor     bx, bx
            mov     bl, Row
            mul     bx
            
            xor     cx, cx
            mov     cl, Column
            shl     cx, 1
            add     ax, cx
            
            mov     bx, ax
            mov     cl, Character   ; first byte character 
            mov     ch, Attribute   ; second byte attribute
            mov     es:[bx], cx
            
            pop     es              ; restore es     
            ret
PutChar     ENDP

; NAME   : SetVideoMode 
; FUNC   : set the display mode
; INPUT  : al - mode 
; OUTPUT : none
; CALL   : EASY-TYPE
SetVideoMode     PROC  FAR C 
            mov     ah, 00h
            int     10h
            ret
SetVideoMode     ENDP

; NAME   : SetCursor
; FUNC   : Set cursor type
; INPUT  : ch - start, cl - end
; OUTPUT : None
; CALL   : EASY-TYPE
SetCursor   PROC    FAR C
            mov     ah, 01h
            int     10h
            ret
SetCursor   ENDP

; NAME   : MoveCursor
; FUNC   : Set the cursor's position
; INPUT  : dh - row(start with 0) 
;          dl - column(start with 0)
; OUTPUT : None
; CALL   : EASY-TYPE
MoveCursor  PROC    FAR C
            mov     ah, 02h
            mov     bh, 0
            int     10h
            ret
MoveCursor  ENDP
          
; NAME   : GetCursor 
; FUNC   : get position shape and position
; INPUT  : none
; OUTPUT : ch - start, cl - end, dh - current row, dl - current column
; CALL   : EASY-TYPE
GetCursor   PROC    FAR C
            mov     ah, 03h
            mov     bh, 00h
            int     10h
            ret
GetCursor   ENDP         

ShowWindow  PROC FAR C, Left:BYTE, Top:BYTE, Right:BYTE, Bottom:BYTE, Attr:BYTE
            mov     al, Top
            .WHILE  al <= Bottom
                mov     ah, Left
                .WHILE  ah <= Right
                    .IF (al == Top)
                        .IF     (ah == Left)
                            mov     bl, 218
                        .ELSEIF (ah == Right)
                            mov     bl, 191
                        .ELSE              
                            mov     bl, 196
                        .ENDIF
                    .ELSEIF (al == Bottom)
                        .IF     (ah == Left)
                            mov     bl, 192
                        .ELSEIF (ah == Right)
                            mov     bl, 217
                        .ELSE              
                            mov     bl, 196    
                        .ENDIF
                    .ELSE    
                        .IF     (ah == Left) || (ah == Right)
                            mov     bl, 179
                        .ELSE              
                            mov     bl, 20h
                        .ENDIF
                    .ENDIF  
                    mov     dh, ah
                    mov     dl, al     
                    push    ax
                    INVOKE  PutChar, dl, dh, bl, Attr
                    pop     ax
                    inc     ah
                .ENDW         
                inc     al
            .ENDW 
            ret
ShowWindow  ENDP 

ShowLine    PROC FAR C, Row:BYTE, Column:BYTE, Msg:WORD, Attr:BYTE
            mov     bl, Column
            ; assume no out of border
            mov     di, Msg
            .WHILE  BYTE PTR [di] != 0 
                push    bx
                INVOKE  PutChar, Row, bl, BYTE PTR [di], Attr
                pop     bx
                inc     di
                inc     bl
            .ENDW            
            ret
ShowLine    ENDP    

ShowWndText PROC FAR C, Left:BYTE, Top:BYTE, Right:BYTE, Bottom:BYTE, Msg:WORD, Attr:BYTE

            INVOKE  ShowWindow, Left, Top, Right, Bottom, Attr
            ; draw the text in the center
            xor     ax, ax
            xor     bx, bx
            mov     al, Top
            mov     bl, Bottom
            add     ax, bx
            mov     bl, 2
            div     bl                      ; al - Row
            push    ax
            
            ; calculate the length of the string
            mov     di, Msg
            xor     cx, cx
            .WHILE  BYTE PTR [di] != 0
                inc     cx
                inc     di
            .ENDW         
            
            xor     ax, ax
            xor     bx, bx
            mov     al, Left
            mov     bl, Right
            sub     bl, al
            sub     bl, cl
            mov     cl, 2
            mov     ax, bx
            div     cl
            mov     bl, Left
            add     bl, al                  ; bl - column
            pop     dx
            
            INVOKE  ShowLine, dl, bl, Msg, Attr
            ret    
ShowWndText ENDP

EnterString PROC FAR C, Row:BYTE, Column:BYTE, Prompt:WORD, Attr:BYTE, ColMin:BYTE, ColMax:BYTE, OutStr:WORD
            xor     bx, bx
            mov     bl, Column
            INVOKE  ShowLine, Row, Column, Prompt, Attr
            
            call    GetCursor
            push    dx
            mov     dh, Row
            mov     dl, ColMin
            call    MoveCursor
            mov     dx, 0               ; end flag                           
            mov     di, OutStr
            mov     bl, ColMin          
            
            .WHILE  dx == 0
                mov     ah, 08h
                int     21h                 
                mov     BYTE PTR [di], 0
                
                .IF     al == 08h
                    ; backspace
                    .IF     di > OutStr        
                        dec     di
                    .ENDIF
                    mov     BYTE PTR [di], 20h
                .ELSEIF al == 0dh
                    ; enter
                    mov     BYTE PTR [di], 0
                    mov     dx, 1
                .ELSE
                    mov     BYTE PTR [di], al
                    mov     BYTE PTR [di+1], 0
                    inc     di
                .ENDIF                        
                                 
                push    dx
                push    di
                
                mov     dh, Row
                mov     dl, ColMin
                mov     ax, di
                sub     ax, OutStr
                add     dl, al
                .IF     dl > ColMax
                    mov     dl, ColMax
                    pop     di
                    dec     di
                    push    di
                    mov     BYTE PTR [di], 0
                .ENDIF
                call    MoveCursor
                
                INVOKE  ShowLine, Row, ColMin, OutStr, Attr
                pop     di
                pop     dx
                
            .ENDW     
            pop     dx
            call    MoveCursor
            ret
EnterString ENDP
            END
