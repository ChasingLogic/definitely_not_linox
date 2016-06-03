section .multiboot_header
header_start:
  dd 0xe85250d6 ; magic number
  dd 0          ; protected mode code
  dd header_end - header_start  ; header length

  ; checksum
  dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))
  ; Explanation of the checksum
  ; You might wonder why we're subtracting these values from 0x100000000. To
  ; answer this we can look at what the multiboot spec says about the checksum
  ; value in the header:
  ; 
  ; The field checksum is a 32-bit unsigned value which, when added to the other
  ; magic fields (i.e. magic, architecture and header_length), must have a
  ; 32-bit unsigned sum of zero.
  ; 
  ; Since 0x100000000 is effectively 0 (because 0xFFFFFFFF + 1 = 0x100000000
  ; which the computer cant represent so it wraps around to 0) we determine the
  ; number we need to reach that value by subtracting the sum of our header
  ; length, protected mode code, and magic number (which comes from the GRUB
  ; documentation), an example let's say that:
  ; (0xe85250d6 + 0 + (header_end - header_start)) = 0xFFFFFFFE
  ; Then our checksum value would be 0x00000002

  ; required end tag
  dw 0                          ; type
  dw 0                          ; flags
  dd 8                          ; size
header_end:
