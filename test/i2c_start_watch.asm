; pin 0 falls while pin 1 is high: pin 5 pulses 10 cycles on
    set p, 6            ; the budget
    set pins, 0
watch:
    wait fall pin 0     ; the event
    jmp !pin, watch     ; pin 1 low: no match
    mov t, now          ; the anchor
    add t, p
    wait t              ; pads every match to the latency
    set pins, 1         ; the verdict
    set pins, 0
    jmp watch
