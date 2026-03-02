;==========================Settings======================================
.286
LOCALS @@
.model tiny
.code
org 100h
;============================Data_Seg====================================
DATASEG
Draw_Buf db 4000 dup (0) ; (80d * 25) * 2 bytes
;========================================================================
CODESEG
;========================================================================
Start:
                mov ax, 3509h
                int 21h
                mov Old_09_Ofs, bx
                mov bx, es
                mov Old_09_Seg, bx

                push 0
                pop es ;int table
                cli
                mov bx, 4 * 09h ;9 * 4bytes
                mov es:[bx], offset GetRegs
                mov ax, cs
                mov es:[bx + 2], ax ;swap interrupt
                sti

                mov ax, 3100h
                mov dx, offset End_Of_Prog
                shr dx, 4
                inc dx
                int 21h
;==============================Get_Regs===================================
GetRegs         proc
                push bp
                pushf
                push ax bx cx dx si di es ds
                mov bp, sp

                ; 'ax', 
                ;stk pop -> val + buf addr -> (val to hex_str -> in buf) -> stosb -> reg = "str"h -> step
                ;

                ; irp REG <ax, bx ...>
                ; macro -> "REG = "
                ; func1 -> "0001h"

                in al, 60h ;get scancode
                cmp al, 45d ;'x' scancode
                jne @@exit
                
                push ds
                pop es ;code segment

                ; xor si, si
                ; inc si
                ; shl si, 1 ;si = 2
                lea di, [Draw_Buf + 5 * 80d + 40d];offset
                mov dx, [bp + 18]
                call Itoa ;write value to buff

                push 0b800h
                pop es
                mov di, 440d ;ofs vmem

                lea si, [Draw_Buf + 5 * 80d + 40d]
                mov cx, 4d ; 80x25 screen

@@lp:           lodsw
                stosw
                loop @@lp
                ; mov es:[bx], ax ;stosw to vmem

@@exit:         in al, 61h 
                or al, 80h
                out 61h, al
                and al, not 80h
                out 61h, al

                mov al, 20h
                out 20h, al ;send end of check to ppi ctrler

                pop ds es di si dx cx bx ax
                popf
                pop bp
                db 0eah
                Old_09_Ofs dw 0
                Old_09_Seg dw 0
         
                iret
                endp
;===================================Get_Regs=============================
;Entry: es - buf seg
;       di - write offset 
;Exit:  -
;Expected:
;Destroyed: ax, di, cx, dx
;Comment: 
;ToDo:
;========================================================================

;===================================Itoa=================================
Itoa            proc
                mov cx, 4d ;4-digits
                mov ah, 0bh ;atribute

@@lp:           mov al, dh ;cpy dh to al
                shr al, 4 ; al -> 4bit

                cmp al, 9 ;is
                ja @@not_digit
                add al, 48d ;get ascii

@@write_2_buf:  stosw
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
End_Of_Prog:
end             Start