; uart tx at four cycles a bit: the loop from one bit to the next takes five
    set p, 4
    set pins, 1
idle:
    wait tx
    pull
    set x, 7
    mov t, now
    set pins, 0
    add t, p
bit:
    wait t+
    out pins, 1 [1]
    jmp x--, bit
    wait t+
    set pins, 1
    wait t
    jmp idle
