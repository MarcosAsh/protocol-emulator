; edge_logger_wire, echoing wire 20 on the set pin once each edge is stamped. It starts
; at the wire's level, which a stopped engine keeps.
    jmp pin, idle
    set pins, 0
low:
    wait 1 pin 20
    mov x, now
    set pins, 1
    in x, 16
high:
    wait 0 pin 20
    mov x, now
    set pins, 0
    in x, 16
    jmp low
idle:
    set pins, 1
    jmp high
