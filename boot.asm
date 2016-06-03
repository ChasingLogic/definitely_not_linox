global start

section .text
bits 32
start:
  ; Point the first entry of the level 4 page table to the first entry in the
  ; p3 table, which is all 0's
  ;
  mov eax, p3_table
  ;
  ; Flip the first two bits of the p3_table to 1's using bitwise OR
  ; See: https://en.wikipedia.org/wiki/Bitwise_operation#OR
  ;
  or eax, 0b11
  ;
  ; Why we set those bits:
  ; Each entry in a page table contains an address, but it also contains
  ; metadata about that page. The first two bits are the ‘present bit’ and the
  ; ‘writable bit’. By setting the first bit, we say “this page is currently in
  ; memory,” and by setting the second, we say “this page is allowed to be
  ; written to.” There are a number of other settings we can change this way,
  ; but they’re not important for now.
  ;
  ; This copies from register eax to the memory pointed at by p4_table.
  ; [] are like a dereference operator
  mov dword [p4_table], eax

  ; Point the first entry of the level 3 page table to the first entry in the
  ; p2 table same as above
  mov eax, p2_table
  or eax, 0b11
  mov dword [p3_table], eax

  ; point each page table level two entry to a page
  mov ecx, 0         ; counter variable
  ; begin loop
.map_p2_table:
  ; Since each page is 2MiB in size we will multiply by our counter to make
  ; sure we're in the right place in physical memory while setting up our pages
  mov eax, 0x200000
  ; mul takes just one argument, which in this case is our ecx counter, and
  ; multiplies that by eax, storing the result in eax
  mul ecx
  ; Same as before we are setting option bits the extra 1 is the 'huge page' bit
  ; otherwise we'd have 4KiB pages instead of 2MiB pages.
  or eax, 0b10000011
  ; write the value of eax to the p2_table skipping 8 bits each time to leave
  ; room for the page table itself
  mov [p2_table + ecx * 8], eax
  ; ecx += 1
  inc ecx
  ; We’re comparing ecx with 512: we want to map 512 page entries overall.
  ; This will give us 512 * 2 mebibytes: one gibibyte of memory.
  cmp ecx, 512
  ; jne = Jump if not equal to. i.e. loop again if ecx != 512
  jne .map_p2_table

  ; move page table address to cr3
  ; cr3 is a control register and can only be moved to from another register
  ; hence moving p4_table into eax first
  mov eax, p4_table
  mov cr3, eax

  ; enable PAE
  mov eax, cr4
  or eax, 1 << 5                ; flip the first bit on
  mov cr4, eax
  ; In order to set PAE, we need to take the value in the cr4 register and
  ; modify it. So first, we mov it into eax, then we use or to change the value.
  ; What about 1 << 5? The << is a ‘left shift’. It might be easier to show you
  ; with a table:
  ; value
  ; 1	000001
  ; << 1	000010
  ; << 2	000100
  ; << 3	001000
  ; << 4	010000
  ; << 5	100000

  ; set the long mode bit
  mov ecx, 0xC0000080
  rdmsr
  or eax, 1 << 8
  wrmsr
  ; The rdmsr and wrmsr instructions read and write to a ‘model specific
  ; register’, hence msr. This is just boilerplate.

  ; enable paging
  mov eax, cr0
  or eax, 1 << 31
  or eax, 1 << 16
  mov cr0, eax

  ; Print hello world when done to make sure we succeed.
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




section .bss                    ; block started by symbol
; Entries in the bss section are automatically set to zero by the linker.
; This is useful, as we only want certain bits set to 1, and most of them
; set to zero.

; Makes sure our tables are aligned correctly.
align 4096
; the idea is that the addresses here will be set to a multiple of 4096,
; hence ‘aligned’ to 4096 byte chunks

; The resb directive reserves bytes; we want to reserve space for each entry.
p4_table:
  resb 4096
p3_table:
  resb 4096
p2_table:
  resb 4096
