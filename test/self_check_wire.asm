; checks each uart frame on wire 20 against rows at 256; the twin of
; Self_check.checker ~pin:20 ~base:256
    set x, 16
    in x, 5
    set x, 0
    in x, 4
    mov x, isr               ; the rows' base
    wait 1 pin 20            ; the line idles high
    capture_arm
frame:
    seek                     ; the rows from the top
    wait 0 pin 20            ; a first edge, stamped by the capture
    mov t, capture
    capture_arm
    mov isr, capture
    in null, 2               ; low since the first edge
    mov x, isr
    out p, 16
    add t, p
edge:
    wait t
    mov isr, capture         ; two cycles before the edge
    in pins, 1               ; one before
    in pins, 1               ; the edge
    capture_arm
    xor x, isr               ; since the last edge only its own level may move
    mov y, isr
    jmp x--, moved
    jmp next
moved:
    jmp x--, fault
next:
    mov isr, capture
    in y, 1                  ; the capture and this edge's level, for the next
    in null, 1
    mov x, isr
    out y, 1
    out p, 15
    add t, p
    jmp y--, edge
    set x, 0                 ; the last row holds the base
    add x, p
    jmp frame
fault:
    irq
    halt
