; uart rx on wire 20 at 16 cycles per bit; the twin of Uart.rx_on ~pin:20 ~period:16
    set p, 16
    set y, 7
idle:
    wait 1 pin 20             ; line idle
arm:
    capture_arm
    wait 0 pin 20             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    in null, 8
    push
    sub t, 2
    wait t                   ; the check, a slow sender's stop bit has begun
    jmp pin, arm             ; high: arm before a fast sender's next start edge
    irq                      ; framing error
    jmp idle
