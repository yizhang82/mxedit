;==============================================================================================
; FILE : Memory.ASM
; Memory routines for the tool MXEdit
; Author : yizhang82
; Start Date : 2002-9-2
; End   Date : 2002-9-9                                                                                         
;==============================================================================================
                       
            .MODEL  SMALL, C
                 
            INCLUDE MEMORY.INC
            .CODE
                            

InitMem     PROC    FAR C
            ; assume DOS 3.0 or higher
            mov     ah, 62h                 ; Query DOS for PSP
            int     21h                     ;   bx - PSP segment address
        
            mov     es, bx                  ; Point ES to block
            mov     bx, 500h                ; New block size
            mov     ah, 4ah                 ; Function number
            int     21h                     ; Resize Memory Block
        
            ret
InitMem     ENDP                        

MemResize   PROC    FAR C, Mem:WORD, Bytes:WORD, OldSize:WORD
            mov     es, Mem
            mov     bx, Bytes
            mov     ah, 4ah
            int     21h
            .IF     carry?
                ; FAIL, now we allocate another block of memory instead
                INVOKE  MemAlloc, Bytes
                .IF     ax == NULL
                    ; memory not enough
                    ret
                .ENDIF
                push    ds
                mov     dx, es
                mov     ds, dx
                mov     es, ax
                xor     di, di
                xor     si, si
                cld 
                mov     cx, OldSize
                REP     movsb  
                pop     ds
                push    ax
                INVOKE  MemFree, Mem
                .IF     ax == NULL
                    ; error freeing memory
                    pop     ax
                    INVOKE  MemFree, ax
                    ret               
                .ENDIF
                pop     ax             
            .ELSE
                mov     ax, es
            .ENDIF
            
            ret
MemResize   ENDP

MemAlloc    PROC    FAR C, Bytes:WORD
            mov     ax, Bytes
            mov     bx, Bytes
            mov     cx, 16
            xor     dx, dx
            div     cx            
            .IF     DX != 0                 ; Bytes is a multiple of 16, counted in para
                mov     bx, Bytes
                add     bx, 16
                sub     bx, dx              ; bx is a bit longer than Bytes
            .ENDIF            
            
            ; whatever, bx is always bytes which to be allocated
            xor     dx, dx
            mov     ax, bx
            mov     cx, 16
            div     cx                      ; perform a 16-bit division
                                            ; ax - paras to allocate
            mov     bx, ax
            ;xor     cx, cx                                       
            xor     al, al
            mov     ah, 48h                 ; dos function 48h, allocate memory
            int     21h
            jc      ErrorInAllocate         ; CF = 1 Error
                                            ; CF = 0 Success, ax - segment of the memory
            ret
                
ErrorInAllocate :
            mov     ax, NULL
            ret            
MemAlloc    ENDP

MemFree     PROC    FAR C, MemSeg:WORD
            mov     ax, MemSeg
            mov     es, ax
            mov     ah, 49h
            xor     cx, cx
            int     21h
            jc      ErrorInFree
            mov     ax, 1
            ret          
ErrorInFree:
            mov     ax, 0
            ret
            
MemFree     ENDP 
            
            ;================================================================
            ; TEST CODE
            ;================================================================
            
            ;.STARTUP       
            ;INVOKE  InitMem
            ;INVOKE  MemAlloc, 25            ; allocate 25 bytes
            ;INVOKE  MemFree,  ax
            ;.EXIT   0
            END