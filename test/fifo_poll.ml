open! Core

let programs =
  [ {|
poll:
    jmp tx, take
    mov pins, !pins
    jmp poll
take:
    pull
    jmp !rx, poll
    mov isr, osr
    push
    jmp poll
|}
  ; {|
poll:
    jmp !tx, poll
    pull
    jmp rx, room
    jmp poll
room:
    mov isr, osr
    push
    jmp poll
|}
  ]
;;
