;==============================================================================================
; FILE.ASM
; File routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9                                                                         
;==============================================================================================
                                                 
            .DOSSEG
            .MODEL  SMALL, C, os_dos
            
            INCLUDE File.INC        
            INCLUDE Memory.INC                      ; Memory routines
            INCLUDE Error.INC
            
            .DATA
Handle          dw      ?              
FileBuffer      dw      ?               
StringBuffer    dw      ?
EndLoad         db      ?                   
SizeOfBuffer    dw      8192
BytesRead       dw      ?
StringEnd       dw      ?   
;StringUncompleted db    ?         
FileBufferPos   dw      ?
LastLinePtr     dw      0
NewLineSeg      dw      0
Line            dw      ?
            .CODE
            
; LoadFile
; FileName : near pointer of the filename string, Zero terminated
; Return   : dx-ax, far pointer of the first line
LoadFile    PROC    FAR C, FileName : DWORD                       
            push    ds
            ;========================================================            
            ; Open file
            ;========================================================            
            mov     ax, WORD PTR FileName
            mov     ds, ax 
            mov     ax, 3d02h
            mov     dx, WORD PTR [FileName+2]
            int     21h       
            .IF     carry?
                INVOKE  OutError, CannotOpenFile, Abort
                jmp     LoadError
            .ENDIF
            mov     bx, ax                          ; BX - file handle
            mov     ax, @DATA
            mov     ds, ax                          ; Load data segment
            mov     Handle, bx
            mov     LastLinePtr, 0
            ;========================================================            
            ; Allocate a file buffer                                 
            ;========================================================
            
            INVOKE  MemAlloc, SizeOfBuffer          ; 8192 bytes
            .IF     ax == NULL                      ; Memory not enough
                INVOKE  OutError, MemoryNotEnough, Abort
                jmp LoadError                       ; ret with ax = NULL
            .ENDIF
            mov     es, ax                          ; es - segment of the memory
            mov     FileBuffer, ax
            
            ;========================================================            
            ; Allocate a string buffer
            ;========================================================            
            INVOKE  MemAlloc, SizeOfBuffer
            .IF     ax == NULL                   
                INVOKE  OutError, MemoryNotEnough, Abort
                jmp LoadError
            .ENDIF
            mov     StringBuffer, ax
            
                                                    
            mov     EndLoad, 0
            ;mov     StringUncompleted, 0
            xor     di, di                          ; position in string buffer
            cld
            ;======================================================================
            ; Here begins the most complex part
            ; 
            ; The most annoying thing is that we donot have a 'gets' like the C run
            ; time library, so we must write one by ourselves.
            ; The main problem is to deal with 'uncompleted strings', which is what
            ; I used to call it. Most of the times a string doesnot end EXACTLY at 
            ; the end of the buffer. To solve this problem, I decided to use a 
            ; file-buffer and a string buffer together.
            ;======================================================================
                                                
            ;======================================================================
            ; process the whole buffer
            ;======================================================================
            
            .WHILE  EndLoad == 0 
                ; First, read the file into buffer
                
                mov     cx, SizeOfBuffer
                mov     bx, Handle
                mov     ax, FileBuffer
                mov     ds, ax
                xor     dx, dx
                mov     ah, 3fh
                int     21h           
                .IF     Carry?
                    INVOKE  OutError, CannotAccessFile, Abort
                    jmp     LoadError
                .ENDIF
                                                    ; CF = 0, ax = bytes read
                mov     dx, @DATA
                mov     ds, dx
                
                .IF     ax < SizeOfBuffer 
                    mov     EndLoad, 1
                .ENDIF                    
                .BREAK .IF     ax == 0
                
                mov     BytesRead, ax                  
                
                xor     bx, bx
                
                .WHILE  bx < BytesRead
                    ; process one string at a time
                    mov     StringEnd, 0
                    .WHILE (StringEnd == 0) && (bx < BytesRead)
                        push     es
                        
                        ;========================================================================
                        ; We only support the standard DOS Text format, <CR><LF> is a combination
                        ; which indicates the end of the line
                        ;========================================================================
                        .IF ( BYTE PTR es:[bx] == 0dh ) || ( BYTE PTR es:[bx] == 26 )
                            ;========================================================            
                            ; Is <CR> or EOF
                            ; In this case, skip a <LF>, and add a terminating 0
                            ; to the last of the string
                            ;========================================================            
                            mov     StringEnd, 1
                            .IF     BYTE PTR es:[bx] == 26
                                ; Is EOF
                                inc     bx
                            .ELSE
                                add     bx, 2
                            .ENDIF
                            ; we cannot skip like this because the file may contain
                            ; a sequence of empty lines
                            ;.WHILE (BYTE PTR es:[bx] == 0ah) || ( BYTE PTR es:[bx] == 0dh ) || ( BYTE PTR es:[bx] == 26 )
                            ;    inc     bx
                            ;.ENDW                     
                            
                            ; add a \0 to the string 
                            mov     es, StringBuffer
                            ;=================
                            ;Debug            
                            ;=================
                            
                            mov     BYTE PTR es:[di],   0
                            ;mov     BYTE PTR es:[di+1], 0ah
                            ;mov     BYTE PTR es:[di+2], 0dh
                            ;mov     BYTE PTR es:[di+3], '$'
                            
                            
                        .ELSEIF BYTE PTR es:[bx] == 08h
                            ; Is <8-TAB>   
                            mov     cl, 8
                            mov     ax, di
                            div     cl               
                            mov     al, 8
                            sub     al, ah
                            xor     ah, ah      
                            mov     es, StringBuffer
                            mov     cx, ax
                            mov     al, ' ' 
                            REP     stosb 
                            inc     bx
                        .ELSEIF BYTE PTR es:[bx] == 09h
                            ; Is a <4-TAB> used by some editors
                            mov     cl, 4
                            mov     ax, di
                            div     cl               
                            mov     al, 4
                            sub     al, ah
                            xor     ah, ah      
                            mov     es, StringBuffer
                            mov     cx, ax
                            mov     al, ' ' 
                            REP     stosb 
                            inc     bx
                        .ELSE
                            ; Normal characters
                            mov     al,     es:[bx]
                            mov     es,     StringBuffer
                            mov     BYTE PTR es:[di], al
                            inc     di
                            inc     bx                
                        .ENDIF     
                        pop     es
                    .ENDW         
                    .IF (bx > BytesRead) && (StringEnd == 0)
                        ; Set the 'uncompleted string' flag
                        ;mov     StringUncompleted, 1
                        
                    .ELSE                           
                        ;mov     StringUncompleted, 0 
                        ;===============================================
                        ; allocate memory for the string
                        ;===============================================
                        ; Print the string for debug
                        ;=============
                        ; Debug Code
                        ;============= 
                        ;push    ds  
                        ;mov     ds, StringBuffer
                        ;xor     dx, dx
                        ;mov     ah, 09h
                        ;int     21h
                        ;pop     ds     
                        
                        mov     FileBufferPos, bx
                        ;===============================================
                        ; create a link list
                        ;===============================================
                        
                        ; allocate memory for the structure
                        INVOKE  MemAlloc, SIZEOF TextLine
                        .IF ax == 0               
                            INVOKE  OutError, MemoryNotEnough, Abort
                            jmp LoadError
                        .ENDIF
                        
                        mov     NewLineSeg, ax                  ; allocate a new line
                        mov     es, ax                 
                        
                        mov     (TextLine PTR es:[0]).NextLineSeg, 0
                        ;====================================
                        ; link HeadLinePtr with NewLineSeg   
                        ;====================================
                        mov     dx, LastLinePtr               
                        mov     (TextLine PTR es:[0]).PrevLineSeg, dx
                        .IF WORD PTR LastLinePtr != NULL 
                            mov     es, LastLinePtr           
                            mov     dx, NewLineSeg
                            mov     (TextLine PTR es:[0]).NextLineSeg, dx
                            mov     es, NewLineSeg              ; restore es
                        .ENDIF
                        
                        ; prepare for the next link
                        mov     dx, NewLineSeg
                        mov     LastLinePtr, dx
                        
                        
                        ; allocate memory for the whole line
                        ; first allocated memory = stringsize - stringsize % 16 + 64
                        inc     di      
                        mov     ax, di
                        xor     dx, dx
                        mov     cx, 16
                        div     cx
                        mov     ax, di                           ; stringsize - stringsize%16
                        sub     ax, dx                                                       
                        add     ax, 64
                        mov     (TextLine PTR es:[0]).CharsAllocated, ax
                        
                        ; do the allocation
                        INVOKE  MemAlloc, ax
                        .IF ax == NULL         
                            INVOKE  OutError, MemoryNotEnough, Abort
                            jmp LoadError
                        .ENDIF
                        
                        mov     (TextLine PTR es:[0]).TextPtrSeg, ax
                        dec     di
                        mov     (TextLine PTR es:[0]).LineLength, di
                        ; copy StringBuffer to NewLineSeg->TextPtrSeg
                        push    ds  
                        mov     dx, (TextLine PTR es:[0]).TextPtrSeg
                        mov     es, dx
                        mov     ds, StringBuffer
                        mov     cx, di                          ; di = string length + 1
                                                                ;    = string size
                        xor     di, di
                        xor     si, si
                        cld
                        REP     movsb
                        
                        xor     di, di 
                        
                        pop     ds                              ; restore ds first
                        mov     ax, FileBuffer
                        mov     es, ax                          ; restore es
                        mov     bx, FileBufferPos
                    .ENDIF
                .ENDW
            .ENDW
            
            ;========================================================            
            ; free the buffers
            ;========================================================            
            INVOKE  MemFree, FileBuffer   
            INVOKE  MemFree, StringBuffer
            
            ;========================================================            
            ; Close file
            ;========================================================            
            mov     bx, Handle
            mov     ah, 3eh
            int     21h
            jc      LoadError
            mov     ax, LastLinePtr
            pop     ds                           
            ret
            
LoadError:  mov     ax, NULL
            pop     ds
            ret
LoadFile    ENDP
            
                            
                
; function:Savefile
; FileName : the name of file to write
; firstline : first line of the text contents
; comment : save file is much more easier to implement
; we only have to travers throw the link list
SaveFile    PROC FAR C, FileName:DWORD, FirstLine:WORD
            
            ; create a new file to write
            push    ds                                          
            mov     al, 01h                                     ; writeonly    
            mov     ds, WORD PTR FileName
            mov     dx, WORD PTR [FileName+2]
            mov     ah, 3dh
            int     21h
            .IF     (carry?) && AX == 0002                      ; file not found
                ; this file is not exist
                ; create the file first
                xor     cx, cx
                mov     ah, 3ch
                int     21h
                
                .IF     carry?
                    ; error creating the file, the name may be invalid
                    mov     AX, NULL
                    pop     ds
                    INVOKE  OutError, CannotOpenFile, Abort
                    ret       
                .ENDIF
            .ENDIF
                
            mov     bx, @DATA
            mov     ds, bx
            mov     Handle, ax    
            
            ; write the contents to the open file
            mov     ax, FirstLine
            mov     es, ax
            mov     Line, es
            
            .WHILE  Line != NULL 
                mov     cx, (TextLine PTR es:[0]).LineLength
                mov     bx, Handle
                push    ds
                mov     ds, (TextLine PTR es:[0]).TextPtrSeg
                xor     dx, dx
                mov     di, cx
                ; change the contents, this may seem somewhat dangerous
                ; but the string size is always 64 bytes more or less 
                ; larger, so no problem
                ; if you still doubt it, please refer to ExpandString
                ; in MXEdit.ASM
                push    cx
                mov     BYTE PTR ds:[di], 0dh
                mov     BYTE PTR ds:[di+1], 0ah
                add     cx, 2
            
                mov     ah, 40h
                int     21h
                .IF     carry?
                    mov     ax, NULL
                    INVOKE  OutError, CannotAccessFile, Abort
                    ret
                .ENDIF
                
                ; restore 
                pop     bx
                mov     BYTE PTR ds:[bx], 0  
                pop     ds
                mov     es, Line
                mov     es, (TextLine PTR es:[0]).NextLineSeg
                mov     Line, es    
            .ENDW               
            
            ; close the file
            
            mov     ah, 3eh
            mov     bx, Handle
            .IF     carry?     
                INVOKE  OutError, CannotAccessFile, Abort
                mov AX, NULL
            .ELSE                
                mov AX, 1
            .ENDIF
            
            pop     ds
            ret
SaveFile    ENDP

            END