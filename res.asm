;==========================Settings======================================
.286
LOCALS @@
.model tiny
.code
org 100h

;========================================================================
Start:
Main            proc
                mov ax, 3509h ;old int addr table
                int 21h ;return old int seg and ip
                mov Old_09_Ofs, bx
                mov bx, es
                mov Old_09_Seg, bx

                push 0
                pop es ;int table

                cli
                mov bx, 4 * 09h ;9 * 4bytes
                mov es:[bx], offset Get_Regs
                mov ax, cs
                mov es:[bx + 2], ax ;swap interrupt
                sti

                mov ax, 3100h ;save code in memory and end_prog
                mov dx, offset End_Of_Prog
                shr dx, 4
                inc dx
                int 21h

                endp
;=========================================================================
Draw_Buf db 4000 dup (0) ; (80d * 25) * 2 bytes
                _RegStrLen_ equ 8
                _NRegs_ equ 10
                RegNames    db 'AX='
                            db 'BX='
                            db 'CX='
                            db 'DX='
                            db 'SI='
                            db 'DI='
                            db 'DS='
                            db 'ES='
                            db 'BP='
                            db 'SP='
;==============================Get_Regs===================================
Get_Regs        proc
                pushf
                push sp bp es ds di si dx cx bx ax
                mov bp, sp

                in al, 60h ;get scancode
                cmp al, 45d ;'x' scancode
                jne @@exit
                
                push cs
                pop ds

                push ds
                pop es ;draw_buf seg

                xor si, si
                xor bx, bx
                mov di, offset Draw_Buf ;write ofs
                mov cx, _NRegs_

@@next_reg:     add si, 2 ;next reg
                mov dx, [bp + si] ; dx = cur_reg
                call Write_Reg ;write val(dx) to buf (Reg=0000h)
                inc bx ;reg_idx++
                loop @@next_reg ; 'AX=0000h'...

                push 0b800h
                pop es
                mov di, (5 * 80d + 40d) * 2 ; vmem pos

                mov si, offset Draw_Buf
                mov cx, _NRegs_ * _RegStrLen_ ; 10x8 size
                xor bx, bx ;cnter of strlen

@@lp:           cmp bx, _RegStrLen_
                jae @@next_line
                lodsw ;ds:si -> ax
                stosw ;ax -> es:di
                inc bx
                loop @@lp

                jmp @@exit

@@next_line:    xor bx, bx
                lea di, [di + (80d - _RegStrLen_) * 2] ;next line
                jmp @@lp

                        

@@exit:         in al, 61h 
                or al, 80h
                out 61h, al
                and al, not 80h
                out 61h, al

                mov al, 20h
                out 20h, al ;send end of check to ppi ctrler

                pop ax bx cx dx si di ds es bp sp
                popf
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

;==============================Write_Reg=================================
Write_Reg       proc
                push cx si

                mov si, bx
                shl si, 1 ;2 * bx
                add si, bx ;3 * bx (strlen * reg_idx)
                lea si, [si + RegNames] ;reg_data + strlen * idx
                
                mov cx, 3 ;strlen("AX=")
                mov ah, 0bh ;atribute color
                
@@lp:           lodsb ;RegData[i][k] -> al
                stosw ;ax -> draw_buf
                loop @@lp
                call Itoa ;dx -> draw_buf
 
                pop si cx
                ret
                endp
;==============================Write_Reg=================================
;Entry: dx - reg_value
;       bx - reg_idx
;       es:di - write offset 
;Exit:  
;Expected:
;Destroyed: ax, dx, di
;Comment: write reg value to draw_buf 
;ToDo:
;========================================================================

;===================================Itoa=================================
Itoa            proc

                mov cx, 4d ;4-digits

@@lp:           mov al, dh ;cpy dh to al
                shr al, 4 ; al -> 4bit

                cmp al, 9 ;is
                ja @@not_digit
                add al, 48d ;'0'+ num = ascii

@@write_2_buf:  stosw ;
                shl dx, 4 ; dx <- 4bit
                loop @@lp

                mov al, 'h' ; 0000h
                stosw
                jmp @@exit

@@not_digit:    add al, 55d; num + ('A' - 10) = ascii
                jmp @@write_2_buf

@@exit:         ret
                endp
;===================================Itoa=================================
;Entry: es - buf seg
;       di - write offset 
;       dx - value
;       ah - color atr
;Exit:  es:di - buf_pos
;Expected:
;Destroyed: al, cx, dx
;Comment: convet int to ascii and write res in buf
;ToDo:
;========================================================================

;====================================End=================================
End_Of_Prog:
end             Start