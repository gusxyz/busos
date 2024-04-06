; BusOS
; this is a currently a 61 line hello world program
org 0x7C00 ; legacy boot expects the Operating System here.
bits 16 ; the cpu will always starts in 16 bit from bios we cant access 32 bit mode just yet.

; MACROS

;end line
%define ENDL 0X0D, 0x0A 

start:
    jmp main ; gurantees that our startpoint is main otherwise adding another function will make it run first

;
; prints a string to the screen using TTY
; Params:
; - ds:si points to a string
;
biosprint:
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
    mov sp, 0x7C00 ; stack grows downwards from where its loaded in memory

    ;print our message
    mov si, msg_hello ; move the variable into si register
    call biosprint ; calling the biosprint function

    hlt

.halt:
    jmp .halt  

msg_hello: db 'Hello World from the Bootloader!', ENDL, 0

times 510-($-$$) db 0
DW 0AA55h