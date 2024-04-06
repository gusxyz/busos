; Bus Bootloader
; CAMEL CASE DUMB DUMB
; this is a currently a 93 line hello world program
org 0x7C00 ; legacy boot expects the Operating System here.
bits 16 ; the cpu will always starts in 16 bit from bios we cant access 32 bit mode just yet.

; MACROS

;end line
%define ENDL 0X0D, 0x0A 

; FAT12 header - copy and pasted from nanobytes os project
jmp short start
nop ; no operation

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0                    ; 0x00 floppy, 0x80 hdd, useless
                            db 0                    ; reserved
ebr_signature:              db 29h
ebr_volume_id:              db 69h, 42h, 07h, 11h   ; serial number, value doesn't matter
ebr_volume_label:           db 'BUS      OS'        ; 11 bytes, padded with spaces

ebr_system_id:              db 'FAT12   '           ; 8 bytes


start:
    jmp main ; gurantees that our startpoint is main otherwise adding another function will make it run first

; prints a string to the screen using an intterupt
; Params:
; - ds:si points to a string
print:
    ; save the register we will modify
    push si
    push ax

.loop:
    lodsb   ; loads next data from DS:SI to AL/AX/EAX then increments SI by the number of bytes loaded
    or al, al   ; verifys if next character is null;
    jz .done ; jz jumpts to destination if zero flag is set

    mov ah, 0x0e ; call bios interrupt
    mov bh, 0 ; set page number to 0
    int 0x10 ; trigger interupt

    jmp .loop

.done:
    ; pop to memory these registers
    pop ax
    pop si
    ret

main:
    ; initailize the data segments
    mov ax, 0 ; cant write to ds/es directly
    mov ds, ax ; maindata segment
    mov es, ax ; extra data segment

    ; initializing the stack
    mov ss, ax
    mov sp, 0x7C00 ; stack grows downwards from where its loaded in mezmory

    ; reading from disk
    mov [ebr_drive_number], dl; set low bits of dx register to the drive number
    
    mov ax, 1 ; LBA=1 secend sector from disk
    mov cl, 1 ; sector to read
    mov bx, 0x7E00 ; set bx to the end of our
    call diskRead

    ;print our message
    mov si, msgLoadingText ; move the variable into si register
    call print ; calling the print function

    cli
    hlt

; General; Handlers

readError:
    mov si, readErrorText
    call bdb_sectors_per_cluster
    jmp waitKeyReboot

waitKeyReboot:
    mov ah, 0
    int 16  ; interrupt to wait for a keypress
    jmp 0FFFFh:0 ; jump to beggining of the BIOS to reboot.
    hlt

.halt:
    cli ; blocks intterupts
    hlt ; halts


; Disk Handlers


; Converts an LBA adress to a CHS adress
; Params:
;   - ax: LBA Address
; Returns:
;   - cx [bits 0-5]: sector number 
;   - cx [bits 6-15]: cylinder 
;   - dh: head

lbaToChs:
    push ax
    push dx

    xor dx, dx  ; dx = 0 aka clear to zero
    div word [bdb_sectors_per_track] ; ax = LBA/SectorsPerTrack

    inc dx ; dx = (LBA % SectorsPerTrack + 1) = sector
    mov cx,dx ; cx = sector

    xor dx, dx 
    div word [bdb_heads]    ; ax = (LBA / SectorsPerTrack) / Heads

    mov dh,dl ; move head number into dh
    mov ch, al ; ch = cylinders low 8 bits from al 
    shl ah, 6 ; shift upper two bits left 6 on ah register
    or cl, ah ; put upper 2 bits of cylinder into cl

    pop ax
    mov dl, al ; restore DL
    pop ax
    ret

; Read a sector from the disk
; Paramter
; ax lba adress
; cl number of sectors to read up to 128
; dl drive number
; es:bx memeory adress

diskRead:
    push ax ; save everything
    push bx
    push cx
    push dx
    push di

    push cx ; save the cl
    call lbaToChs ; compute CHS
    pop ax ; AL = number sectors to read

    mov ah, 02h 
    mov di, 3 ; retry count

.retry:
    pusha   ;push all registers protect from da bios
    stc ; set carry flag just in case bios dosent
    int 13h ; carry flag cleared = success
    jnc .done ; jnc = jump if not carry
    
    ; we failed boys
    popa 
    call diskReset

    dec di ; decerement the retry account
    test di, di ; check loop condition sets the flag for jnz
    jnz .retry

.fail: ; went through the 3 retries and failed each time
    jmp readError

.done:
    popa ; popall

    pop di ; 
    pop dx
    pop cx
    pop bx
    pop ax ; we have to save all the registers
    ret ; always return at the end of a function just like any other language 

; Resets disk controller
; Params:
;   dl: drive number

diskReset:
    pusha ; save everything to stack
    mov ah, 0
    stc ; carry FLAGGIN
    int 13h ; reset disk
    jc readError ; if issue read error
    popa ; retrieve from stack
    ret ; always return



; la finest string collection

msgLoadingText: db 'Bus Bootloader is loading..,', ENDL, 0
readErrorText: db 'Error reading from the floppy.', ENDL 0

times 510-($-$$) db 0
DW 0AA55h