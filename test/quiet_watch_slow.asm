; pin 2 stops moving: pin 5 pulses 100 to 104 cycles on
    wait tx
    pull                ; the host sends the budget, 95
    mov p, osr
    set pins, 0
    jmp pin, high
.wrap_target
low:
    mov t, now          ; the anchor
    add t, p
    set x, 22
low_poll:
    jmp pin, high       ; an edge
    jmp x--, low_poll
    wait t              ; pads the verdict to the latency
    jmp pin, high
    set pins, 1         ; the verdict
    set pins, 0
    wait 1 pin 2 [1]
high:
    mov t, now          ; the anchor
    add t, p
    set x, 22
high_poll:
    jmp !pin, low       ; an edge
    jmp x--, high_poll
    wait t              ; pads the verdict to the latency
    jmp !pin, low
    set pins, 1         ; the verdict
    set pins, 0
    wait 0 pin 2 [1]
.wrap
