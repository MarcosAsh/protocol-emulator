; control: the fault replaced by a pin write at the same cycle
; Wire 20 and OUT0 rise, then a pull from the empty tx fifo: an underflow.
.side_set 1
    set pins, 0 side 0
    wait tx side 0
    pull side 0
    set pins, 1 side 1
    nop side 1 [15]
    nop side 1 [15]
    set pins, 0 side 0
    set pins, 0 side 0
    halt side 0
