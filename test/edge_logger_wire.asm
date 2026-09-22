; the time of every edge on wire 20; the twin of Firmware.edge_logger ~pin:20
    jmp pin, high
low:
    wait 1 pin 20
    mov x, now
    in x, 16
high:
    wait 0 pin 20
    mov x, now
    in x, 16
    jmp low
