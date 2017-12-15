;==============================================================================================
; FILE.INC
; Include file for file routines load/save 
;==============================================================================================
                                           
                                           
; the textline structure

TextLine    STRUC
    TextPtrSeg      DW  ?           ; segment of the dword pointer to a line of text
                                    ; relative address is always 0
    PrevLineSeg     DW  ?           ; segment, previous line
    NextLineSeg     DW  ?           ; segment of the dword pointer to the next line
    CharsAllocated  DW  ?           ; total chars allocated by the memory allocater
    LineLength      DW  ?           ; length of the line, not include the '\0'
TextLine    ENDS
                                          
LoadFile    PROTO FAR C, FileName:DWORD
SaveFile    PROTO FAR C, FileName:DWORD, FirstLine:WORD