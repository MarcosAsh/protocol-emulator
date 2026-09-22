; a counted loop for the debugger test: the breakpoint goes on the second set
    set x, 3
loop:
    set pins, 1
    set pins, 0
    jmp x--, loop
    halt
