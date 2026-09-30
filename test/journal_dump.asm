; the journal's ring to the host a word at a time, from its base on for ever
    out null, 16             ; whatever the last program left in the osr
    set x, 16
    add x, x
    add x, x
    add x, x
    add x, x                 ; 256, the ring's base
    seek [1]                 ; the shared memory needs a cycle to fetch the word
loop:
    wait rx
    out isr, 16              ; autopull takes the next word
    push
    jmp loop
