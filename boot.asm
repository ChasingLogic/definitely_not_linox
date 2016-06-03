global start

section .text
bits 32
start:
  mov word [0xb8000], 0x0248    ; H
  mov word [0xb8002], 0x0265    ; e
  mov word [0xb8004], 0x026C    ; l
  mov word [0xb8006], 0x026C    ; l
  mov word [0xb8008], 0x026F    ; o
  mov word [0xb8010], 0x0220    ; (space)
  mov word [0xb8012], 0x0257    ; W
  mov word [0xb8014], 0x026F    ; o
  mov word [0xb8016], 0x0272    ; r
  mov word [0xb8018], 0x026C    ; l
  mov word [0xb8020], 0x0264    ; d
  hlt

