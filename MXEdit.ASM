;==============================================================================================
; MXEdit.ASM
; Main file for the tool MXEdit 
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9                                                          
;==============================================================================================
        .DOSSEG
        .MODEL  SMALL, C, os_dos
        .STACK                                  
                                
        INCLUDE TEXT.INC                                ; Text routines
        INCLUDE MEMORY.INC                              ; Memory routines
        INCLUDE FILE.INC                                ; file routines
        INCLUDE ERROR.INC                               ; error output routines
        
        .DATA
;=============================================================================
; Key scan codes
;=============================================================================
Up          =  48h
Down        =  50h
Left        =  4bh
Right       =  4dh
Return      =  0dh
Tab         =  09h
BackSpace   =  08h
Escape      =  1bh      
Delete      =  53h                                             
HomeKey     =  47h
EndKey      =  4fh                                                               
PageUp      =  49h
PageDn      =  51h
F10         =  44h
TextAttr    =  17h
TitleAttr   =  74h                                              
MainMenuAttr=  70h
MenuItemAttr=  70h
HilightAttr =  24h
StatusAttr  =  70h
TabStop     =  8

FileNamePtr DD  ?         
FileNameMsg DB  'FileName:'
FileName    DB  200 DUP(?)
NoNameMsg   DB  '<no name>', 0
LastLine    DW  ?
FirstLine   DW  ?    
CurrentLine DW  ?     
LineLength  DW  ?
xPos        DB  0
yPos        DB  1                                       ; cursor position
Row         DW  0                                       ; Row number of the (left, top) corner
Column      DW  0                                       ; column number of the (left, top) corner
Quit        DB  0                    
TmpRow      DB  0
TmpColumn   DB  0
Head        DW  ?
Last        DW  ?           
NewLine     DW  ?    
Key         DB  ?   
NewSize     DW  ?
OldSize     DW  ?                                                                
VerMsg      DB  '  MXEdit v1.0 by yizhang82, 2002.', 0
PosMsg      DB  '[Row:00000, Col:00000]', 0
MenuOn      DB  0
MenuItem    DB  0 
MenuMsg     DB  '  Menu(Esc)', 0
MenuTop     DB  218, 10 dup(196), 191, 0
Menu1       DB  179,'Load      ', 179, 0
Menu2       DB  179,'Save      ', 179, 0
Menu3       DB  179,'Save as   ', 179, 0
Menu4       DB  179,'Quit      ', 179, 0
MenuBottom  DB  192, 10 dup(196), 217, 0
SaveFileMsg DB  'Saving file...', 0
LoadFileMsg DB  'Loading file..', 0
SaveOKMsg   DB  'Saving end.', 0
LoadOkMsg   DB  'Loading end.', 0
FilePrompt  DB  'Enter file name:', 0
               
        .CODE

;====================================================================
; Find the last lines, make sure total cx lines
; Output : Last
;====================================================================                    
FindLastLine PROC
        mov     bx, FirstLine   
        mov     Last, bx
        .WHILE (cx > 0) && (bx != NULL)  
            mov     es, bx
            mov     Last, bx
            mov     bx, (TextLine PTR es:[0]).NextLineSeg             
            dec     cx 
        .ENDW
        
        .IF     cx > 0
            ;========================================================
            ; no current line found
            ; so first, create from the last line to the current line
            ; es - last line 
            ;========================================================
            mov     Last, es
            .REPEAT         
                push    cx
                ; allocate memory for the structure
                INVOKE  MemAlloc, SIZEOF TextLine
                .IF     ax == 0
                    jmp ErrorAllocate
                .ENDIF  
                mov     NewLine, ax
                mov     es, ax
                
                ; Initialize the structure in es          
                ; link
                mov     ax, Last
                mov     (TextLine PTR es:[0]).PrevLineSeg, ax
                mov     (TextLine PTR es:[0]).NextLineSeg, NULL
                .IF     Last != NULL
                    mov     es, Last                           
                    mov     ax, NewLine
                    mov     (TextLine PTR es:[0]).NextLineSeg,  ax
                    mov     es, NewLine
                .ELSE
                    ; this indicates FirstLine is NULL
                    mov     FirstLine, es    
                .ENDIF
                mov     Last, es
                
                ; allocate NULL strings with a start length of 64 bytes
                INVOKE  MemAlloc, 64
                .IF     ax == 0
                    jmp ErrorAllocate  
                .ENDIF
                mov     (TextLine PTR es:[0]).TextPtrSeg, ax
                mov     (TextLine PTR es:[0]).CharsAllocated, 64
                mov     (TextLine PTR es:[0]).LineLength, 0
                mov     es, (TextLine PTR es:[0]).TextPtrSeg
                mov     BYTE PTR es:[0], 0  
                pop     cx
            .UNTILCXZ
        .ENDIF
        ret        
ErrorAllocate:
        INVOKE  OutError, MemoryNotEnough, Abort
        ret            
FindLastLine ENDP

;===============================================
; Expand the string memory if necessary
; Param: NewSize - new size of the string
;        es      - Pointer to the line
;===============================================                          
ExpandString PROC
        mov     dx, (TextLine PTR es:[0]).CharsAllocated
        .IF     NewSize >= dx
            ; resize the memory to fit the string
            ; allocated memory = stringsize - stringsize % 16 + 64
            mov     ax, NewSize
            xor     dx, dx
            mov     cx, 16
            div     cx
            mov     ax, NewSize
            sub     ax, dx
            add     ax, 64                      ; ax - new amount of memory
            mov     dx, (TextLine PTR es:[0]).CharsAllocated
            mov     (TextLine PTR es:[0]).CharsAllocated, ax                        
            push    di                                    
            push    es
            INVOKE  MemResize,                      \
                (TextLine PTR es:[0]).TextPtrSeg,   \
                ax,                                 \
                dx    
            pop     es
            pop     di
            mov     (TextLine PTR es:[0]).TextPtrSeg, ax                             
        .ENDIF
        ret                                                                  
ExpandString ENDP
DrawScreen PROC 
        
        .IF     MenuOn == 1
            jmp DrawMenu
        .ENDIF
        
        ;=====================================================
        ; Find the top line accord to Row
        ;=====================================================
        mov     cx, Row
        mov     bx, FirstLine
        mov     es, bx
        .WHILE (cx > 0) && (bx != NULL)  
            mov     bx, (TextLine PTR es:[0]).NextLineSeg             
            mov     es, bx
            dec     cx 
        .ENDW
        
        mov     CurrentLine, bx
        xor     bp, bp                                     
        mov     bp, 1
        mov     ax, CurrentLine
        mov     es, ax
        mov     bx, es                                  ; bx - current line to display
                                                        ; (TYPE textline)
        mov     LineLength, 0
        .IF     bx != NULL                              ; avoid null pointer read
            mov     ax, (TextLine PTR es:[0]).LineLength
            mov     LineLength, ax
            mov     es, (TextLine PTR es:[0]).TextPtrSeg
        .ENDIF
        ; draw to row 23 
        mov     TmpRow, 0
        .WHILE (bp < 24) && (bx != NULL)
            xor     di, di
            mov     di, column
            mov     ax, bp
            mov     TmpRow, al 
            mov     TmpColumn, 0 
            push    bx
            .WHILE ( di < LineLength ) && (BYTE PTR es:[di] != 0) && ( TmpColumn < 80 )
                INVOKE  PutChar, TmpRow, TmpColumn, BYTE PTR es:[di], 17h
                inc     TmpColumn
                inc     di
            .ENDW  
            .WHILE TmpColumn < 80
                INVOKE  PutChar, TmpRow, TmpColumn, 20h, TextAttr
                inc     TmpColumn                       
            .ENDW                                      
            pop     bx
            ; goto next line             
            mov     es, bx 
            mov     bx, (TextLine PTR es:[0]).NextLineSeg
            mov     es, bx                               
            mov     LineLength, 0
            .IF     bx != NULL                                      
                mov     ax, (TextLine PTR es:[0]).LineLength    
                mov     LineLength, ax
                mov     es, (TextLine PTR es:[0]).TextPtrSeg
            .ENDIF
            inc     bp
        .ENDW  
        .WHILE (bp < 24)
            ;=============================================
            ; draw spaces          
            ;=============================================
            mov     ax, bp
            mov     TmpRow, al
            ;mov     ax, Column
            mov     TmpColumn, 0
            mov     cx, 80
            .REPEAT     
                push    cx
                INVOKE  PutChar, TmpRow, TmpColumn, 20h, TextAttr    
                inc     TmpColumn
                pop     cx
            .UNTILCXZ                               ; this statement also dec cx 
            
            inc     bp
        .ENDW    
        
        ;===========================================
        ; draw title bar
        ;===========================================
        mov     TmpColumn, 0
        mov     TmpRow, 0
        xor     di, di
        .WHILE  MenuMsg[di] != 0
            INVOKE  PutChar, TmpRow, TmpColumn, MenuMsg[di], MainMenuAttr
            inc     di
            inc     TmpColumn
        .ENDW          
        
        xor     di, di
        .WHILE  VerMsg[di] != 0
            INVOKE  PutChar, TmpRow, TmpColumn, VerMsg[di], TitleAttr
            inc     di
            inc     TmpColumn
        .ENDW
        .WHILE  TmpColumn < 80
            INVOKE  PutChar, TmpRow, TmpColumn, 20h, TitleAttr
            inc     TmpColumn
        .ENDW
          
        ;===========================================
        ; draw the status bar      
        ;===========================================
        ; fill in PosMsg
        
        mov     ax, Row
        mov     bl, yPos
        xor     bh, bh
        add     ax, bx
        mov     si, OFFSET PosMsg
        add     si, 5
        call    ConvertAX        
        
        mov     ax, Column
        mov     bl, xPos
        xor     bh, bh
        add     ax, bx
        inc     ax
        mov     si, OFFSET PosMsg
        add     si, 16
        call    ConvertAX
        
        mov     TmpColumn, 0
        mov     TmpRow, 24
                                
        xor     di, di
        .WHILE  (TmpColumn < 80) && (FileNameMsg[di] != 0)
            INVOKE  PutChar, TmpRow, TmpColumn, FileNameMsg[di], StatusAttr
            inc     TmpColumn
            inc     di            
        .ENDW       
        
        .IF FileName == 0
            ; display a no name
            xor     di, di
            .WHILE  (TmpColumn < 80) && (NoNameMsg[di] != 0)
                INVOKE  PutChar, TmpRow, TmpColumn, NoNameMsg[di], StatusAttr
                inc     TmpColumn
                inc     di            
            .ENDW       
        .ENDIF
        
        .WHILE  TmpColumn < 58
            INVOKE  PutChar, TmpRow, TmpColumn, 20h, StatusAttr
            inc     TmpColumn
        .ENDW                
                
        xor     di, di
        .WHILE  (PosMsg[di] != 0) && (TmpColumn < 80)
            INVOKE  PutChar, TmpRow, TmpColumn, PosMsg[di], StatusAttr
            inc     TmpColumn
            inc     di
        .ENDW         
        .WHILE  TmpColumn < 80
            INVOKE  PutChar, TmpRow, TmpColumn, 20h, StatusAttr
            inc     TmpColumn
        .ENDW      
        
DrawMenu:           
        .IF MenuOn == 1
            ; draw menu
            mov     TmpRow, 1   
            mov     di, OFFSET MenuTop
            call    DrawMenuLine
            mov     di, OFFSET Menu1
            call    DrawMenuLine
            mov     di, OFFSET Menu2
            call    DrawMenuLine
            mov     di, OFFSET Menu3
            call    DrawMenuLine
            mov     di, OFFSET Menu4
            call    DrawMenuLine
            mov     di, OFFSET MenuBottom
            call    DrawMenuLine    
        .ENDIF
        ret
DrawScreen ENDP                                   

DrawMenuLine PROC
        mov     TmpColumn, 1
        .WHILE  BYTE PTR ds:[di] != 0 
            mov     al, MenuItem
            add     al, 2
            .IF (al == TmpRow) && (TmpColumn > 1) && (TmpColumn < 12)
                INVOKE  PutChar, TmpRow, TmpColumn, BYTE PTR ds:[di], HilightAttr                 
            .ELSE
                INVOKE  PutChar, TmpRow, TmpColumn, BYTE PTR ds:[di], MenuItemAttr
            .ENDIF
            inc     di
            inc     TmpColumn
        .ENDW                
        ;.WHILE  TmpColumn < 10  
        ;    mov     al, MenuItem
        ;    add     al, 2
        ;    .IF al == TmpRow
        ;        INVOKE  PutChar, TmpRow, TmpColumn, BYTE PTR ds:[di], HilightAttr                 
        ;    .ELSE
        ;        INVOKE  PutChar, TmpRow, TmpColumn, 20h, MenuItemAttr
        ;    .ENDIF
        ;    inc     TmpColumn
        ;.ENDW                
        inc TmpRow
        ret
DrawMenuLine ENDP

; convert the number in ax to a 5-digit string begin from ds:si
ConvertAX  PROC 
        mov     cx, 5
        add     si, 4
        .REPEAT 
            xor     dx, dx
            mov     bx, 10
            div     bx
            add     dl, '0'
            mov     [si], dl          ; first
            dec     si
        .UNTILCXZ     
        ret
ConvertAX  ENDP                           

;==============================================================================
; Free the contents of the file to free memory
;==============================================================================
FreeContents PROC         
        mov     es, FirstLine
        mov     ax, es
        .WHILE  ax != NULL 
            push    ax
            mov     es, (TextLine PTR es:[0]).TextPtrSeg
            INVOKE  MemFree, es
            .IF     ax == NULL
                INVOKE  OutError, ErrorFreeingMem, Abort
                
            .ENDIF    
            pop     ax         
            mov     es, ax
            mov     ax, (TextLine PTR es:[0]).NextLineSeg
            push    ax
            INVOKE  MemFree, es 
            .IF     ax == NULL
                INVOKE  OutError, ErrorFreeingMem, Abort       
            .ENDIF
            pop     ax
            mov     es, ax    
        .ENDW
        ret
FreeContents ENDP                      

; Menu function:Load file
MenuLoadFile PROC      
        mov     MenuOn, 0
        call    DrawScreen
        INVOKE  ShowWindow, 10, 5, 50, 9, TextAttr
        INVOKE  EnterString, 7, 13, OFFSET FilePrompt, TextAttr, 30, 49, OFFSET FileName
        call    DrawScreen
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET LoadFileMsg, TextAttr             
        call    FreeContents
        INVOKE  LoadFile, FileNamePtr       
        mov     LastLine, ax                                                      
        ;========================================================================
        ; find the first line               
        ;========================================================================
        xor     bx, bx
        mov     es, LastLine
        mov     ax, es
        .WHILE ax != NULL                                
            mov     bx, es                              ; bx - previous es
            mov     ax, (TextLine PTR es:[0]).PrevLineSeg
            push    ax
            mov     es, ax
            mov     es, (TextLine PTR es:[0]).TextPtrSeg
            xor     di, di 
            pop     ax
            mov     es, ax
        .ENDW             
        
        mov     FirstLine, bx
        call    DrawScreen
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET LoadOkMsg, TextAttr             
        WaitKey
        call    DrawScreen
        ret
MenuLoadFile ENDP
                        
; Menu function: save file
MenuSaveFile PROC                   
        mov     MenuOn, 0
        call    DrawScreen
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET SaveFileMsg, TextAttr
        INVOKE  SaveFile, FileNamePtr, FirstLine   
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET SaveOkMsg, TextAttr
        WaitKey
        ret
MenuSaveFile ENDP

; Menu function: Save as
MenuSaveAs   PROC
        mov     MenuOn, 0
        call    DrawScreen
        INVOKE  ShowWindow, 10, 5, 50, 9, TextAttr
        INVOKE  EnterString, 7, 13, OFFSET FilePrompt, TextAttr, 30, 49, OFFSET FileName
        call    DrawScreen
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET SaveFileMsg, TextAttr             
        INVOKE  SaveFile, FileNamePtr, FirstLine
        INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET SaveOkMsg, TextAttr             
        WaitKey
        call    DrawScreen
        ret
MenuSaveAs   ENDP
        
        
;================================================================================
; MAIN PROGRAM BEGINS FROM HERE
;================================================================================
; MAIN PROGRAM BEGINS FROM HERE
;================================================================================
; MAIN PROGRAM BEGINS FROM HERE
;================================================================================

        .STARTUP
                                                 
        ;========================================================================
        ; Initialize the program to allocate memory
        ;========================================================================
        INVOKE  InitMem
        
        ;========================================================================
        ; First call setvideomode to set video mode to the standard 80x25 display
        ;========================================================================
        mov     al, Mode80x25x16
        call    SetVideoMode
        call    DrawScreen
        ; get psp address
        ; assume DOS 3.0 or higher
        mov     ah, 62h                             ; Query DOS for PSP
        int     21h                                 ; bx - PSP segment address
        
        mov     WORD PTR [FileNamePtr], ds
        mov     WORD PTR [FileNamePtr+2], OFFSET FileName
        
        push    ds             
        mov     ax, ds
        mov     es, ax                              ; es - segment of file name
        mov     ds, bx                              ; ds - segment of psp
        mov     di, OFFSET FileName
        mov     si, 82h
        mov     cl, BYTE PTR ds:[80h]               ; psp:[80h] - the length of command line
        xor     ch, ch   
        .IF     cl == 0
            ; no run time argument specified
            mov    BYTE PTR es:[di], 0
            pop    ds            
            
            mov    LastLine, NULL
        .ELSE
            dec     cx
            cld
            REP     movsb
            mov     BYTE PTR es:[di+1], 0
            pop     ds   
            INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET LoadFileMsg, TextAttr             
            INVOKE  LoadFile, FileNamePtr       
            mov     LastLine, ax
            INVOKE  ShowWndText, 10, 5, 30, 9, OFFSET LoadOkMsg, TextAttr             
            WaitKey
        .ENDIF        
        
        
        ;========================================================================
        ; find the first line               
        ;========================================================================
        xor     bx, bx
        mov     es, LastLine
        mov     ax, es
        .WHILE ax != NULL                                
            mov     bx, es                              ; bx - previous es
            mov     ax, (TextLine PTR es:[0]).PrevLineSeg
            mov     es, ax 
        .ENDW             
        
        mov     FirstLine, bx
        
                                                                                 
        ;========================================================================
        ; Initialize variables
        ;========================================================================
        mov     dh, yPos
        mov     dl, xPos
        call    MoveCursor
        
        ;========================================================================                
        ; THE MAIN LOOP
        ;========================================================================
        mov     Row, 0
        call DrawScreen
        .WHILE Quit == 0
            ;====================================================================
            ; wait to read a key
            ;====================================================================
                          
                      ; 07h - no Ctrl+C
            mov     ah, 08h
            int     21h                                 ; al - key code
            .IF     MenuOn == 1
                ; menu key process
                .IF     al == 0
                    mov     ah, 08h
                    int     21h                                 ; read extended key code
                    .IF     al == UP
                        .IF     MenuItem > 0
                            dec MenuItem
                        .ELSE
                            mov MenuItem, 3
                        .ENDIF
                    .ELSEIF al == DOWN
                        .IF     MenuItem < 3
                            inc MenuItem   
                        .ELSE
                            mov MenuItem, 0
                        .ENDIF
                    
                    .ENDIF
                .ELSEIF al == Escape
                    mov     MenuOn, 0
                .ELSEIF al == Return
                    ; process menu command
                    mov     MenuOn, 1
                    .IF MenuItem == 0
                        ; Loadfile
                        call    MenuLoadFile
                    .ELSEIF MenuItem == 1
                        ; save file     
                        call    MenuSaveFile
                    .ELSEIF MenuItem == 2
                        ; save as  
                        call    MenuSaveAs
                    .ELSEIF MenuItem == 3
                        ; quit
                        mov     Quit, 1
                    .ENDIF
                .ENDIF 
                         
                call    DrawScreen
                .CONTINUE     
            .ENDIF
            .IF     al == 0                             ; is a Extended key code?
                mov     ah, 08h
                int     21h                             ; read another key scan code
                 
                .IF     al == F10
                    mov     MenuOn, 1
                .ELSEIF al == UP   
                    .IF yPos > 1
                        dec yPos
                    .ELSE 
                        .IF Row > 0
                            dec Row
                        .ENDIF
                    .ENDIF         
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == DOWN
                    .IF yPos < 23
                        inc yPos
                    .ELSE
                        inc Row
                    .ENDIF            
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == LEFT
                    .IF xPos > 0
                        dec xPos 
                    .ELSE
                        .IF Column > 0
                            dec Column
                        .ENDIF
                    .ENDIF            
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == RIGHT
                    .IF xPos < 79
                        inc xPos
                    .ELSE
                        inc Column
                    .ENDIF            
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == HomeKey
                    mov     Column, 0
                    mov     xPos, 0
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == EndKey
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                    
                    call    FindLastLine
                    
                    mov     es, Last
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    
                    ; first see if we can avoid moving the screen
                    .IF     (dx >= Column)
                        mov     ax, Column
                        add     ax, 79            
                        .IF     (ax >= dx)
                            ; ok, just change xPos 
                            sub     dx, Column
                            mov     xPos, dl
                        .ELSE 
                            mov     xPos, 79
                            .IF     dx <= 79            ; length <= 79
                                mov     xPos, dl   
                                mov     Column, 0
                            .ELSE                       ; length > 79
                                sub     dx, 79
                                mov     Column, dx
                            .ENDIF
                        .ENDIF
                    .ELSE         
                        mov     xPos, 79
                        .IF     dx <= 79            ; length <= 79
                            mov     xPos, dl   
                            mov     Column, 0
                        .ELSE                       ; length > 79      
                            sub     dx, 79
                            mov     Column, dx
                        .ENDIF
                    .ENDIF 
                       
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSEIF al == Delete
                 
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                    
                    call    FindLastLine
                          
                    mov     es, Last
                    mov     di, Column
                    mov     al, xPos
                    xor     ah, ah
                    add     di, ax          
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    .IF     dx > di
                        dec     (TextLine PTR es:[0]).LineLength
                    
                        ;inc     di
                        mov     es, (TextLine PTR es:[0]).TextPtrSeg
                    
                        .WHILE  di < dx
                            mov     al, es:[di+1]
                            mov     es:[di], al
                            inc     di
                        .ENDW 
                    .ELSE    
                        ; like backspace   
                        ; this time we link the next line to the current line
                        mov     NewSize, dx
                        ;inc     NewSize
                        
                        sub     di, dx
                        add     NewSize, di
                        ;inc     NewSize
                             
                        mov     es, (TextLine PTR es:[0]).NextLineSeg
                        mov     ax, es
                        .IF     ax != NULL
                            
                            
                            mov     bx, (TextLine PTR es:[0]).LineLength
                            add     NewSize, bx
                            
                            ; expand string first
                            mov     es, Last                          
                            mov     ax, NewSize
                            mov     (TextLine PTR es:[0]).LineLength, ax
                            
                            call    ExpandString
                            
                            ; expand the string with spaces
                            mov     si, (TextLine PTR es:[0]).LineLength
                            mov     es, (TextLine PTR es:[0]).TextPtrSeg
                            mov     di, NewSize          
                            ; you'll encounter a infinite loop if
                            ; si == 0
                            
                            .WHILE  (di > si)
                                mov BYTE PTR es:[di], 20h
                                dec di
                            .ENDW           
                            mov     BYTE PTR es:[si], 20h
                            
                            ; characters to copy
                            mov     es, Last          
                            mov     es, (TextLine PTR es:[0]).NextLineSeg
                            mov     cx, (TextLine PTR es:[0]).LineLength
                            inc     cx
                            
                            mov     di, Column
                            mov     al, xPos
                            xor     ah, ah
                            add     di, ax
                            
                            push    ds
                            push    Last
                            xor     si, si
                            mov     ds, (TextLine PTR es:[0]).TextPtrSeg
                            
                            pop     es                                  
                            
                            mov     es, (TextLine PTR es:[0]).TextPtrSeg
                            REP     movsb
                            
                            pop     ds
                            ; change link
                            mov     es, Last                             
                            
                            mov     es, (TextLine PTR es:[0]).NextLineSeg
                            mov     bx, es
                            mov     es, (TextLine PTR es:[0]).NextLineSeg
                            mov     ax, Last
                            mov     (TextLine PTR es:[0]).PrevLineSeg, ax
                            mov     dx, es
                            mov     es, Last
                            mov     (TextLine PTR es:[0]).NextLineSeg, dx
                            
                            ; free memory                                    
                            mov     es, bx
                            INVOKE  MemFree, (TextLine PTR es:[0]).TextPtrSeg
                            .IF     ax == NULL
                                jmp Error
                            .ENDIF
                            INVOKE  MemFree, es
                            .IF     ax == NULL
                                jmp Error
                            .ENDIF
                            
                        .ENDIF    
                    .ENDIF
                .ELSEIF al == PageDn  
                    add     Row, 24
                .ELSEIF al == PageUp
                    .IF     Row < 24
                        mov     Row, 0
                    .ELSE
                        sub     Row, 24
                    .ENDIF
                    
                                    
                .ENDIF
            .ELSE
                .IF     al == Escape
                    mov     MenuOn, 1
                .ELSEIF al == BackSpace
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                    
                    call    FindLastLine
                          
                    mov     es, Last
                    mov     di, Column
                    mov     al, xPos
                    xor     ah, ah
                    add     di, ax          
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    
                    mov     bx, Row
                    mov     cl, yPos
                    xor     ch, ch
                    add     bx, cx
                                                                 
                    ; Two case
                    .IF     (di > 0) && (dx > 0)
                        ;========================================
                        ; Normal case
                        ;========================================
                        dec     (TextLine PTR es:[0]).LineLength
                        mov     es, (TextLine PTR es:[0]).TextPtrSeg
                    
                        .IF     di > 0
                            dec     di
                            .WHILE  di < dx
                                mov     al, es:[di+1]
                                mov     es:[di], al
                                inc     di
                            .ENDW    
                            .IF xPos > 0
                                dec xPos 
                            .ELSE
                                .IF Column > 0
                                    dec Column
                                .ENDIF
                            .ENDIF            
                            mov     dh, yPos
                            mov     dl, xPos
                            call    MoveCursor
                        .ENDIF

                    .ELSEIF (bx > 1)
                        ;========================================
                        ; Cursor is in the leftmost of the screen
                        ; we 1.link the contents of the current 
                        ; line to the previous line, and 2.
                        ; delete the current line, then 3.place
                        ; the cursor at the link point of the 
                        ; previous line
                        ;========================================    
                       
                        .IF dx > 0 
                            ; link a empty line is not necessary
                            ; 1
                            push    ds
                        
                            mov     ax, (TextLine PTR es:[0]).TextPtrSeg
                            push    ax
                            xor     si, si
                            mov     cx, dx
                            inc     cx
                                    
                            ; Row > 0, Prevlineseg is not NULL
                            mov     es, (TextLine PTR es:[0]).PrevLineSeg
                            mov     di, (TextLine PTR es:[0]).LineLength
                            ; calculate the newsize and expand if necessary
                            mov     NewSize, di                                     
                            add     NewSize, cx                       
                            mov     dx, NewSize
                            dec     dx
                            mov     (TextLine PTR es:[0]).LineLength, dx
                            push    di    
                            push    cx
                            call    ExpandString
                            pop     cx
                            mov     es, (TextLine PTR es:[0]).TextPtrSeg             
                            pop     di
                            pop     ds
                            xor     si, si
                            mov     bx, di                          ; bx - new cursor pos
                            ; copy  
                            cld
                            REP     movsb
                            pop     ds 
                        .ELSE
                            mov     es, (TextLine PTR es:[0]).PrevLineSeg
                            mov     bx, (TextLine PTR es:[0]).LineLength
                        .ENDIF
                        
                        ; 2
                        mov     es, Last
                        mov     ax, (TextLine PTR es:[0]).NextLineSeg
                        mov     es, (TextLine PTR es:[0]).PrevLineSeg
                        mov     dx, es
                        mov     (TextLine PTR es:[0]).NextLineSeg, ax
                        mov     es, ax
                        mov     (TextLine PTR es:[0]).PrevLineSeg, dx
                        
                        ; free <last>       
                        mov     es, Last
                        INVOKE  MemFree, (TextLine PTR es:[0]).TextPtrSeg
                        .IF ax == NULL
                            jmp Error
                        .ENDIF
                        INVOKE  MemFree, es
                        .IF ax == NULL
                            jmp Error
                        .ENDIF
                        ; 3 locate cursor in bx
                        .IF     yPos > 1
                            dec yPos
                        .ELSE
                            .IF Row > 1
                                dec     Row
                            .ENDIF
                        .ENDIF            
                        
                        .IF     bx < 80
                            mov     Column, 0
                            mov     xPos, bl
                        .ELSE             
                            sub     bx, 79
                            mov     Column, bx
                            mov     xPos, 79
                        .ENDIF
                        mov     dh, yPos
                        mov     dl, xPos
                        call    MoveCursor
                    .ENDIF
                    
                .ELSEIF al == Tab
                    ;=============================================
                    ; Tab, insert 8 - (Column+xPos)%8
                    ; set xPos to xPos - (Column+xPos)%8 + 8
                    ; (assume tabstop is 8 in the formula above)
                    ;=============================================
                    ; find the current line
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                                        
                    call    FindLastLine
                    
                    mov     ax, Column
                    add     al, xPos
                    adc     ah, 0                       ; ax: (Column+xPos)
                    xor     dx, dx
                    mov     cx, TabStop
                    div     cx                          ; dx: (Column + xPos)%8
                    sub     cx, dx                      
                    
                    ; insert (cx) characters to current position
                    mov     es, Last
                    mov     bx, (TextLine PTR es:[0]).LineLength
                    mov     Oldsize, bx
                    mov     NewSize, bx
                    add     NewSize, cx                 
                    mov     bx, NewSize
                    mov     (TextLine PTR es:[0]).LineLength, bx
                    push    cx                   
                    call    ExpandString
                    pop     cx
                    
                    ;===========================================
                    ; Insert the character into the string
                    ;=========================================== 
                    mov     es, (TextLine PTR es:[0]).TextPtrSeg
                    mov     di, Column
                    mov     al, xPos
                    xor     ah, ah
                    add     di, ax
                    add     di, cx
                    mov     si, NewSize
                    .WHILE  si >= di       
                        mov     bx, si
                        sub     bx, cx
                        mov     dl, es:[bx]
                        mov     es:[si], dl
                        dec     si
                    .ENDW       
                    
                    ; modify xpos
                    add     xPos, cl
                    .IF     xPos > 79
                        mov     al, xPos
                        xor     ah, ah
                        sub     ax, 79
                        add     Column, ax
                        mov     xPos, 79
                    .ENDIF    
                                 
                    ; make spaces
                    .WHILE  cx > 0
                        dec     di
                        mov     BYTE PTR es:[di], 20h
                        dec     cx
                    .ENDW
                                        
                    mov     dl, xPos
                    mov     dh, yPos
                    call    MoveCursor
                    
                .ELSEIF al == Return
                    ;============================================
                    ; Return
                    ; make the current line end at the current
                    ; position, and make the characters beyond 
                    ; the current position a new line 
                    ;============================================    
                    
                    ; find the current line
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                                        
                    call    FindLastLine
                    
                    ;============================================
                    ; create a new line
                    ;============================================
                    ; allocate memory for the structure
                    INVOKE  MemAlloc, SIZEOF TextLine
                    .IF     ax == 0
                        jmp Error
                    .ENDIF  
                    mov    NewLine, ax
                    mov    es, ax
                    
                    ; Initialize the structure in es          
                    ; link
                    mov     ax, Last
                    mov     (TextLine PTR es:[0]).PrevLineSeg, ax  
                    push    es
                    mov     es, ax
                    mov     dx, (TextLine PTR es:[0]).NextLineSeg
                    pop     es
                    mov     (TextLine PTR es:[0]).NextLineSeg, dx
                    .IF     Last != NULL
                        mov     es, Last                           
                        mov     ax, NewLine
                        mov     (TextLine PTR es:[0]).NextLineSeg,  ax
                        mov     es, NewLine
                    .ELSE
                        ; this indicates FirstLine is NULL
                        mov     FirstLine, es                            
                    .ENDIF
                    
                    ; calculate new size                                             
                    push    es
                    mov     es, Last
                    mov     ax, (TextLine PTR es:[0]).LineLength    ; ax - line length
                    
                    mov     dx, Column                 
                    mov     bl, xPos
                    xor     bh, bh
                    add     dx, bx                                  ; dx - current pos
                    .IF     ax > dx
                        ; copying is needed
                        sub     ax, dx    
                    .ELSE
                        xor     ax, ax
                    .ENDIF
                    push    ax
                    inc     ax
                    mov     NewSize, ax                 
                    xor     dx, dx
                    mov     cx, 16
                    div     cx
                    mov     ax, NewSize
                    sub     ax, dx
                    add     ax, 64                      ; ax - new amount of memory
                    pop     bx
                    pop     es
                    mov     (TextLine PTR es:[0]).LineLength, bx
                    
                    ; allocate memory for the new line string
                    INVOKE  MemAlloc, ax
                    .IF     ax == 0
                        jmp Error  
                    .ENDIF            
                    mov     (TextLine PTR es:[0]).TextPtrSeg, ax
                    mov     (TextLine PTR es:[0]).CharsAllocated, ax
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    .IF     dx > 0
                        ;==============================================
                        ; perform copying                              
                        ;==============================================
                        mov     es, (TextLine PTR es:[0]).TextPtrSeg                                               
                        push    ds
                        push    es
                        mov     al, xPos
                        xor     ah, ah
                        mov     si, Column
                        mov     es, Last  
                        
                        mov     ds, (TextLine PTR es:[0]).TextPtrSeg
                        xor     di, di
                        pop     es    
                        add     si, ax
                        
                        mov     cx, dx
                        cld
                        REP     movsb
                        mov     BYTE PTR es:[di], 0  
                        pop     ds
                    .ENDIF
                                        
                    ; now modify the current line
                    mov     es, Last
                    mov     ax, Column
                    mov     bl, xPos
                    xor     bh, bh
                    add     ax, bx
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    
                    .IF     ax <= dx
                        ; make the current line end here 
                        mov     es, (TextLine PTR es:[0]).TextPtrSeg
                        mov     di, ax
                        mov     BYTE PTR es:[di], 0     
                        mov     es, Last                      
                        mov     (TextLine PTR es:[0]).LineLength, ax
                    .ENDIF
                    ; goto the next line
                    mov     xPos, 0
                    mov     Column, 0
                    .IF yPos < 23
                        inc yPos
                    .ELSE
                        inc Row
                    .ENDIF            
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ELSE   
                    mov     Key, al
                    ;===========================================================================
                    ; This is the most complex part of this editor                              
                    ; A key has been pressed, and needed to be insert to the text
                    ;===========================================================================
                    ;============================================
                    ; First, find the current line
                    ;============================================
                    mov     cx, Row
                    mov     al, yPos  
                    xor     ah, ah
                    add     cx, ax                      ; cx - line number
                                        
                    call    FindLastLine
                        
                    ;=========================================
                    ; Last is the current line,
                    ; Now insert our typed key into that line
                    ;=========================================
                        
                    mov     es, Last
                    mov     di, Column
                    mov     al, xPos
                    xor     ah, ah
                    add     di, ax          
                    ;=========================================                    
                    ; calculate the new size 
                    ;=========================================
                    mov     dx, (TextLine PTR es:[0]).LineLength
                    mov     OldSize, dx
                    .IF     di > OldSize
                        mov     NewSize, di
                        inc     NewSize
                    .ELSE                    
                        mov     ax, OldSize
                        mov     NewSize, ax
                        inc     NewSize
                    .ENDIF                   
                                       
                    mov     dx, NewSize
                    mov     (TextLine PTR es:[0]).LineLength, dx
                    
                    call    ExpandString
                    mov     es, (TextLine PTR es:[0]).TextPtrSeg
                    .IF     di < OldSize               
                        ;===========================================
                        ; Insert the character into the string
                        ;===========================================
                        
                        mov     si, OldSize
                        inc     si
                        .WHILE  si > di
                            mov     dl, es:[si-1]
                            mov     es:[si], dl
                            dec     si
                        .ENDW                     
                        mov     al, Key
                        mov     es:[di], al
                        
                    .ELSE
                        ;===========================================
                        ; Just append
                        ;===========================================
                        mov     si, di
                            
                        mov     di, OldSize
                        .WHILE  di < NewSize
                            mov     BYTE PTR es:[di], 20h
                            inc     di
                        .ENDW
                        mov     al, Key
                        mov     BYTE PTR es:[si], al        
                        mov     di, NewSize
                        mov     BYTE PTR es:[di], 0
                    .ENDIF                 
                    
                    ;===============================================
                    ; At last, move the cursor 
                    ;===============================================
                    .IF xPos < 79
                        inc xPos
                    .ELSE
                        inc Column
                    .ENDIF            
                    mov     dh, yPos
                    mov     dl, xPos
                    call    MoveCursor
                .ENDIF
            .ENDIF    
Continue:            
            call DrawScreen
        .ENDW 
        
Error : 
        ; call setvideomode again to clear the screen
        call    FreeContents
        mov     al, Mode80x25x16
        call    SetVideoMode
        
        .EXIT                       
        END
         
        
        
