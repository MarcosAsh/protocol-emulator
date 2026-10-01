; checks each uart frame on wire 20 against rows at 256; the twin of
; Self_check.checker ~pin:20 ~base:256
    set x, 16
    in x, 5
    set x, 0
    in x, 4
    mov x, isr
    mov p, x                 ; the rows' base, where the least keeps it
    capture_arm
    wait 1 pin 20            ; the line idles high
    wait 0 pin 20            ; the first frame's first edge
    capture_arm
    mov isr, capture [5]     ; its stamp, or a fall's in the first cycle read
    jmp anchor
high:                        ; x is the last fall's stamp
    wait t [2]
    capture_arm              ; the cycle after the edge
    mov y, capture
    jmp x!=y, fell
    out y, 1
    out p, 15
    add t, p
    jmp y--, high
    jmp least
fell:
    mov x, now
    sub x, 5                 ; the edge's own cycle
    jmp x!=y, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, low
    jmp fault                ; the frame ends low
low:
    mov isr, null
    wait t
    in pins, 1               ; the cycle before the edge
    jmp pin, rose            ; the edge
    mov y, isr
    jmp y--, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, low
    jmp fault                ; the frame ends low
rose:
    mov y, isr
    jmp y--, fault
    out y, 1
    out p, 15
    add t, p
    jmp y--, high
least:
    out p, 16                ; the base, in the word after the rows
    wait t
    mov y, capture
    jmp x!=y, fault          ; nothing fell since the last fall
    mov y, capture           ; two cycles before the least
    wait 0 pin 20            ; the least: the next frame's first edge
    capture_arm
    mov isr, capture
    jmp x!=y, fault
    mov x, isr
    mov y, now
    add x, 6
    jmp x!=y, fault          ; the capture is the fall the wait released on
anchor:
    mov t, now
    set x, 0
    add x, p
    seek                     ; the rows from the top
    mov x, isr
    out p, 16
    add t, p
    jmp low
fault:
    irq
    halt
