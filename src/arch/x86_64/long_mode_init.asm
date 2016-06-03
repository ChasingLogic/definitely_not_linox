global long_mode_start

section .text
bits 64
long_mode_start:
  ; Call our rust code
  extern rust_main
  call rust_main

  ; Set up a 64 bit version of eax
  mov rax, 0x2f592f412f4b2f4f
  mov qword [0xb8000], rax      ; Print OKAY to the screen

  hlt
