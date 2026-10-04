; what a start leaves of the last program: osr's count back to empty and isr to zero, as
; after a reset, for a program that assumes them. Run under a config without autopull.
    mov osr, null
    out x, 16
    mov isr, null
    halt
