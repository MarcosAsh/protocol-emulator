; The neighbour: a square wave on the set pin, an edge every p cycles on its deadline.
    wait tx
    pull
    mov p, osr
    mov t, now
    add t, p
loop:
    wait t+
    set pins, 1
    wait t+
    set pins, 0
    jmp loop
