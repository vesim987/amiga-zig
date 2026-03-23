SECTIONS {
  .text : { *(.text) }
  .data : { *(.data) }
  .bss (NOLOAD) : { *(.bss)  }
  .eh_frame (NOLOAD) : { *(.eh_frame) }
  .note (NOLOAD) : { *(.note.GNU-stack) *(.note.*) }
}
