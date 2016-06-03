global start
extern long_mode_start

section .text
bits 32
start:
  mov esp, stack_top            ; Used for erroring

  call check_multiboot
  call check_cpuid
  call check_long_mode

  call setup_page_tables
  call enable_paging

  call setup_SSE

  ; load our GDT
  lgdt [gdt64.pointer]

  ; Our last task is to update several special registers called 'segment
  ; registers'. Again, we're not using segmentation, but things won't work
  ; unless we set them properly.

  ; update selectors
  mov ax, gdt64.data
  mov ss, ax
  mov ds, ax
  mov es, ax
  ; Here's a short rundown of these registers:
  ;
  ; ax: This isn't a segment register. It's a sixteen-bit register. Remember
  ; 'eax' from our loop accumulator? The 'e' was for 'extended', and it's the
  ; thirty-two bit version of the ax register. The segment registers are sixteen
  ; bit values, so we start off by putting the data part of our GDT into it,
  ; to load into all of the segment registers.
  ;
  ; ss: The 'stack segment' register. We don't even have a stack yet, that's how
  ; little we're using this. Still needs to be set.
  ;
  ; ds: the 'data segment' register. This points to the data segment of our GDT,
  ; which is conveniently what we loaded into ax.
  ;
  ; es: an 'extra segment' register. Not used, still needs to be set.

  ; Updates the code segment register
  ; jump to long mode!
  jmp gdt64.code:long_mode_start
  hlt

; Checks if we're booting using grub
check_multiboot:
  cmp eax, 0x36d76289
  jne .no_multiboot
  ret
.no_multiboot:
  mov al, "0"
  jmp error

check_cpuid:
  ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
  ; in the FLAGS register. If we can flip it, CPUID is available.

  ; Copy FLAGS in to EAX via stack
  pushfd
  pop eax

  ; Copy to ECX as well for comparing later on
  mov ecx, eax

  ; Flip the ID bit
  xor eax, 1 << 21

  ; Copy EAX to FLAGS via the stack
  push eax
  popfd

  ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
  pushfd
  pop eax

  ; Restore FLAGS from the old version stored in ECX (i.e. flipping the
  ; ID bit back if it was ever flipped).
  push ecx
  popfd

  ; Compare EAX and ECX. If they are equal then that means the bit
  ; wasn't flipped, and CPUID isn't supported.
  cmp eax, ecx
  je .no_cpuid
  ret
.no_cpuid:
  mov al, "1"
  jmp error

; Checks if process is 64-bit
check_long_mode:
  ; test if extended processor info in available
  mov eax, 0x80000000    ; implicit argument for cpuid
  cpuid                  ; get highest supported argument
  cmp eax, 0x80000001    ; it needs to be at least 0x80000001
  jb .no_long_mode       ; if it's less, the CPU is too old for long mode

  ; use extended info to test if long mode is available
  mov eax, 0x80000001    ; argument for extended processor info
  cpuid                  ; returns various feature bits in ecx and edx
  test edx, 1 << 29      ; test if the LM-bit is set in the D-register
  jz .no_long_mode       ; If it's not set, there is no long mode
  ret
.no_long_mode:
  mov al, "2"
  jmp error

setup_page_tables:
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

  ret

enable_paging:
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

  ret

; Prints `ERR: ` and the given error code to screen and hangs.
; parameter: error code (in ascii) in al
error:
  mov dword [0xb8000], 0x4f524f45
  mov dword [0xb8004], 0x4f3a4f52
  mov dword [0xb8008], 0x4f204f20
  mov byte  [0xb800a], al
  hlt

; Check for SSE and enable it. If it's not supported throw error "a".
setup_SSE:
  ; check for SSE
  mov eax, 0x1
  cpuid
  test edx, 1<<25
  jz .no_SSE

  ; enable SSE
  mov eax, cr0
  and ax, 0xFFFB      ; clear coprocessor emulation CR0.EM
  or ax, 0x2          ; set coprocessor monitoring  CR0.MP
  mov cr0, eax
  mov eax, cr4
  or ax, 3 << 9       ; set CR4.OSFXSR and CR4.OSXMMEXCPT at the same time
  mov cr4, eax

  ret
.no_SSE:
  mov al, "a"
  jmp error

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
stack_bottom:
  resb 64
stack_top:

section .rodata                 ; stands for read only data
; Setting up our GDT or Global Descriptor Table
; See for more info: http://wiki.osdev.org/Global_Descriptor_Table
gdt64:
  ; first entry in GDT needs to be a zero value
  dq 0
.code: equ $ - gdt64
  ; Set up the code segment of the GDT
  ; | is bitwise or
  dq (1<<44) | (1<<47) | (1<<41) | (1<<43) | (1<<53)
  ; why these bits? Well, as we’ve seen with other table entries,
  ; each bit has a meaning. Here’s a summary:
  ; 44: ‘descriptor type’: This has to be 1 for code and data segments
  ; 47: ‘present’: This is set to 1 if the entry is valid
  ; 41: ‘read/write’: If this is a code segment, 1 means that it’s readable
  ; 43: ‘executable’: Set to `1 for code segments
  ; 53: ‘64-bit’: if this is a 64-bit GDT, this should be set
.data: equ $ - gdt64
  ; Set up the data segment
  dq (1<<44) | (1<<47) | (1<<41)
.pointer:
  ; length of the gdt
  dw .pointer - gdt64 - 1
  ; address of the gdt
  dq gdt64

