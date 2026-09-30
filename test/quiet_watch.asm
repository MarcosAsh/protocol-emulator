; pin 2 stops moving: pin 5 pulses 20 to 24 cycles on
    set p, 15           ; the budget
    set pins, 0
    jmp pin, high
.wrap_target
low:
    mov t, now          ; the anchor
    add t, p
    set x, 2
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
    set x, 2
high_poll:
    jmp !pin, low       ; an edge
    jmp x--, high_poll
    wait t              ; pads the verdict to the latency
    jmp !pin, low
    set pins, 1         ; the verdict
    set pins, 0
    wait 0 pin 2 [1]
.wrap
