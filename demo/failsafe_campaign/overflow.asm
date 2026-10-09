; Wire 20 and OUT0 rise, then nine pushes into the eight-deep rx fifo: an overflow.
.side_set 1
    set pins, 0 side 0
    wait tx side 0
    pull side 0
    set pins, 1 side 1
    nop side 1 [15]
    nop side 1 [15]
    push side 1
    push side 1
    push side 1
    push side 1
    push side 1
    push side 1
    push side 1
    push side 1
    push side 1
    set pins, 0 side 0
    halt side 0
