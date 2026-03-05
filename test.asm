;==========================Settings======================================
.286
LOCALS @@
.model tiny
.code
org 100h
;========================================================================
Start:
    Inf:
                    mov bx, 1000h
                    mov si, 0F60h
                    mov dx, 1212h
                    mov es, 0b800h
                    in al, 60h
                    cmp al, 12h
                    je Exit
                    jmp Inf

    Exit:
                    mov ax, 4c00h
                    int 21h
end Start