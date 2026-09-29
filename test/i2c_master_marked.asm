; Firmware.i2c_master ~quarter:30 (400 kHz at 48 MHz) with SDA on IO7 and SCL on IO6.
; set_count 2 puts wire 20 beside SDA: each nop that moves SCL is a set that copies the
; release onto the wire in the same issue, so engine 1 sees the proved release cycle.
; host word: start[15] read[14] data[13:6] stop[5]
    .side_set 1
    set p, 30 side 0
    set pins, 2 side 0           ; SCL released, and the wire says so
idle:
    wait tx side 0
    pull side 0
    mov t, now side 0
    add t, p side 0
    add t, p side 0
    out x, 1 side 0
    jmp x--, start
    jmp send_or_read
byte:
    wait tx side 1
    pull side 1
    mov t, now side 1
    add t, p side 1
    add t, p side 1
    out x, 1 side 1
    jmp x--, restart
    jmp send_or_read
start:
    wait t+ side 0
    set pindirs, 1 side 0        ; SDA low while SCL high
    wait t+ side 0
    set pins, 0 side 1
    add t, p side 1
    jmp send_or_read
restart:
    set pindirs, 0 side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: restart
    wait t+ side 0
    set pindirs, 1 side 0
    wait t+ side 0
    set pins, 0 side 1
    add t, p side 1
send_or_read:
    out y, 1 side 1
    set x, 7 side 1
    jmp y--, read
send:
    wait t+ side 1
    out y, 1 side 1
    mov pindirs, !y side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: write bit
    wait t+ side 0
    wait t+ side 0
    set pins, 0 side 1
    jmp x--, send
    wait t+ side 1
    set pindirs, 0 side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: ack
    wait t+ side 0
    in pins, 1 side 0
    wait t+ side 0
    set pins, 0 side 1
    out x, 1 side 1
    jmp finish
read:
    set pindirs, 0 side 1
rbit:
    wait t+ side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: read bit
    wait t+ side 0
    in pins, 1 side 0
    wait t+ side 0
    set pins, 0 side 1
    jmp x--, rbit
    out null, 8 side 1
    out x, 1 side 1
    wait t+ side 1
    mov pindirs, !x side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: ack or nack we send
    wait t+ side 0
    wait t+ side 0
    set pins, 0 side 1
    set pindirs, 0 side 1
finish:
    push side 1
    jmp x--, stop
    jmp byte
stop:
    wait t+ side 1
    set pindirs, 1 side 1
    wait t+ side 1
    set pins, 2 side 0           ; release: stop
    wait t+ side 0
    set pindirs, 0 side 0
    wait t+ side 0
    jmp idle
