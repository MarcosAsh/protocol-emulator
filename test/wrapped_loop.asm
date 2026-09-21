    set p, 2
    mov t, now
    add t, p
.wrap_target
    wait t+
    mov pins, !pins
.wrap
