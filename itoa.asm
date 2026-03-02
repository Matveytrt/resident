;==========================Settings======================================
.286
.model tiny
.code
LOCALS @@
org 100h
;========================================================================

;===================================Data=================================
DATASEG
Buff db 80*25 dup (0)
;========================================================================

;===================================Code=================================
CODESEG
Start:
;===================================Main=================================
Main            proc
                mov dx, 266d
                mov di, offset Buff
                call Itoa

                push 0b800h
                pop es
                xor si, si
                mov di, (80d *5 + 40d) * 2
                mov si, offset Buff
                mov cx, 4

@@lp:           lodsb
                mov ah, 4ch
                stosw
                loop @@lp    

                mov ax, 4c00h
				int 21h
                endp
;========================================================================

;===================================Itoa=================================
Itoa            proc
                mov cx, 4d ;4-digits

@@lp:           mov al, dh ;cpy dh to al
                shr al, 4 ; al -> 4bit

                cmp al, 9 ;is
                ja @@not_digit
                add al, 48d ;get ascii

@@write_2_buf:  stosb
                shl dx, 4 ; dx <- 4bit
                loop @@lp

                jmp @@exit

@@not_digit:    add al, 55d; get ascii
                jmp @@write_2_buf

@@exit:         ret
                endp
;===================================Itoa=================================
;Entry: es - buf seg
;       di - write offset 
;       dx - value
;Exit:  es:di - buf_pos
;Expected:
;Destroyed: ax, di, cx, dx
;Comment: convet int to ascii and write res in buf
;ToDo:
;========================================================================

;====================================End=================================
end             Start