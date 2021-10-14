[BITS 16]   ;; this tells the assembler that boot code is running on the 16-bit mode
[ORG 0x7c00]    ;; code will be start from 0x7c00 which is the address the start address of the first sector

start:
    ;; initialize [ds, es, ss] with 0000
    ;; make stack pointer pointing to 0x7c00 -> first push will be stored in 0x7bfe
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

TestDiskExtension:
    mov [DriveId],dl
    mov ah,0x41
    mov bx,0x55aa
    int 0x13
    jc NotSupport
    cmp bx,0xaa55
    jne NotSupport

LoadLoader:
    mov si, ReadPacket
    mov word[si], 0x10
    mov word[si + 2], 5
    mov word[si + 4], 0x7e00
    mov word[si + 6], 0
    mov dword[si + 8], 1
    mov dword[si + 0xc], 0
    mov dl, [DriveId]
    mov ah, 0x42
    int 0x13
    jc ReadError
    mov dl, [DriveId]
    jmp 0x7e00

ReadError:
NotSupport:
    mov ah, 0x13    ;; ah holds the function code [0x13 -> print string]
    mov al, 1   ;; al specifies the write mode (the cursor will be placed at the end of the string)
    mov bx, 0xa ;; [bx -> 00001010], bh represents page number, bl holds the information of character attributes (a -> character is green)
    xor dx, dx  ;; dh represents rows, dl represents columns [(0, 0) -> is the beginning of the screen]
    mov bp, Message ;; bp holds the start address of the string
    mov cx, MessageLength   ;; cx holds string length
    int 0x10    ;; calling BIOS service to print a character (interupt 0x10)

End:
    hlt
    jmp End

DriveId:    db  0
Message:    db  "We have an error in boot process"
MessageLength:  equ $-Message
ReadPacket: times 16 db 0

times (0x1be - ($-$$)) db 0 ;; directive [times] repeats commant in specific times
                            ;; [$] -> refers to the address of the line itself (here is the end of the message)
                            ;; [$$] -> refers to the address of the 1st lint in the section (here is the start of the code)
                            ;; as a result of this expression the space from the end of the message to the offset [0x1be] is filled with 0s
                            ;; in offset 0x1be we have what it is called partition entries (there are four entries with each entry being 16 bytes in size)

    db 80h                  ;; boot indicator
    db 0, 2, 0              ;; starting CHS (cylinder, head, sector)
                            ;; [1st byte] -> head value
                            ;; [2nd byte] -> (bits 0 to 5 is used as sector value) (bits 6 and 7 are used as cylinder value)
                            ;; [3rd byte] -> holds the lower 8 bits of cylinder value

    db 0f0h                 ;; partion type
    db 0ffh, 0ffh, 0ffh     ;; ending CHS (ffh -> maximum value of a byte)

    dd 1                    ;; represents LBA address of starting sector (LBA -> Logical Block Address)
                            ;; we will load the file using LBA instead of CHS value
    dd (20 * 16 * 63 - 1)   ;; how many sectors the partition has (we set it as 10mb)
                            ;; []

    times (16 * 3) db 0     ;; last three entries are filled with 0s

    ;; last two bytes are signature which should be 55h, AAh
    db 0x55
    db 0xaa