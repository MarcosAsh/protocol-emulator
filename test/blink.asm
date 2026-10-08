; Drives the set pin and toggles it for ever.
    set pindirs, 1
loop:
    set pins, 1 [3]
    set pins, 0 [2]
    jmp loop
