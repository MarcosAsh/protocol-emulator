; uart rx on wire 20 at 16 cycles per bit; the twin of Firmware.uart_rx_on ~pin:20 ~period:16
    set p, 16
    set y, 7
    wait 1 pin 20             ; line idle
    capture_arm
idle:
    wait 0 pin 20             ; start bit, its edge cycle is in capture
    mov t, capture
    add t, y
    add t, p                 ; middle of bit 0
    set x, 7
bit:
    wait t+
    in pins, 1
    jmp x--, bit
    capture_arm              ; watch for the next start edge from here on
    in null, 8
    push
    wait t                   ; middle of the stop bit
    jmp pin, idle
    irq                      ; framing error
    wait 1 pin 20
    capture_arm
    jmp idle
