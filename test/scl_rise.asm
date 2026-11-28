; For each release of SCL by engine 0, which raises wire 20 in the same issue: the cycles from
; the release to the rising edge the capture unit saw on the SCL pad, low 16 bits. Engine 0
; drives SCL when capture is armed, so the line reads low until the release. If the pad does not
; rise before SCL is driven low again the word covers every pulse up to the next rise, and those
; get no word. Releases that find the rx fifo full go unmeasured.
loop:
    wait 0 pin 20            ; engine 0 drives SCL
    jmp !rx, skip
    capture_arm
    wait 1 pin 20            ; the release
    mov x, now
    wait 1 pin 18            ; the SCL pad reads high
    mov y, capture
    sub y, x
    in y, 16
    jmp loop
skip:
    wait 1 pin 20
    jmp loop
