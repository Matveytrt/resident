;==========================Settings======================================
.286
LOCALS @@
.model tiny
.code
org 100h
;========================================================================
STOS_LINE       macro sym, clr, len
                mov al, sym
                mov ah, clr 
                mov cx, len
                repne stosw
                endm
;========================================================================
Start:
Main            proc
                mov ax, 3509h ;old int addr table
                int 21h ;return old int seg and ip
                mov Old_09_Ofs, bx
                mov bx, es
                mov Old_09_Seg, bx

                mov ax, 3508h ;old int addr table
                int 21h ;return old int seg and ip
                mov Old_08_Ofs, bx
                mov bx, es
                mov Old_08_Seg, bx

                push 0
                pop es ;int table

                cli
                mov bx, 4 * 09h ;9 * 4bytes
                mov es:[bx], offset New_09_Int
                mov ax, cs
                mov es:[bx + 2], ax ;swap interrupt
                sti

                cli
                mov bx, 4 * 08h ;8 * 4bytes
                mov es:[bx], offset New_08_Int
                mov ax, cs
                mov es:[bx + 2], ax ;swap interrupt
                sti

                call Copy_Buff ; first time copy vmem to safe

                mov ax, 3100h ;save code in memory and end_prog
                mov dx, offset End_Of_Prog
                shr dx, 4
                inc dx
                int 21h

                endp
;=========================================================================

;============================Data=========================================
Draw_Buf db 4000 dup (0) ;(80d * 25) * 2 bytes
Safe_Buf db 4000 dup (0) ;(80d * 25) * 2 bytes
_VmemSeg_ equ 0b800h
_VmemPos_ equ (5 * 80d + 40d) * 2
_RegStrLen_ equ 8
_NRegs_  equ 13
_FrmSize_ = (_RegStrLen_ + 2d) * (_NRegs_ + 2d)
color_0 = 0bh
symbol_0 = 03h
RegNames    db 'AX='
            db 'BX='
            db 'CX='
            db 'DX='
            db 'SI='
            db 'DI='
            db 'DS='
            db 'ES='
            db 'CS='
            db 'SS='
            db 'FR='
            db 'BP='
            db 'SP='
;=========================================================================

;==============================New_09_Int=================================
New_09_Int      proc
                push sp bp
                pushf
                push ss cs es ds
                push di si dx cx bx ax
                mov bp, sp

                
                in al, 60h ;get scancode
                cmp al, 35d ;'h' scancode
                jne @@next

                mov ax, cs
                mov ds, ax ;ds = cs
                mov si, offset Safe_Buf
                call Write_Vmem ;rewrite vmem

@@next:         in al, 60h ;get scancode
                cmp al, 45d ;'x' scancode
                jne @@exit

                mov ax, cs
                mov ds, ax ;ds = cs

                mov es, ax ;es = cs
                xor si, si
                mov di, offset Draw_Buf ;write ofs
                call Write_Draw

                mov si, offset Draw_Buf
                call Write_Vmem

@@exit:         in al, 61h 
                or al, 80h
                out 61h, al
                and al, not 80h
                out 61h, al

                mov al, 20h
                out 20h, al ;send EOI to ppi ctrler

                pop ax bx cx dx si di 
                pop ds es
                add sp, 2
                pop ss
                popf
                pop bp sp

                db 0eah
                Old_09_Ofs dw 0
                Old_09_Seg dw 0
         
                iret
                endp
;===================================New_09_Int===========================
;Entry: es - buf seg
;       di - write offset 
;Exit:  -
;Expected:
;Destroyed:
;Comment: 
;ToDo:
;========================================================================

;==============================New_08_Int=================================
New_08_Int      proc
                push sp bp
                pushf
                push ss cs es ds
                push di si dx cx bx ax
                
                cli
                call Check_Buff ;rewrite draw and vmem
                sti

                mov al, 20h
                out 20h, al ;send EOI to int ctrler

                pop ax bx cx dx si di 
                pop ds es
                add sp, 2
                pop ss
                popf
                pop bp sp
                db 0eah
                Old_08_Ofs dw 0
                Old_08_Seg dw 0
         
                iret
                endp
;===================================New_08_Int===========================
;Entry: es - buf seg
;       di - write offset 
;Exit:  -
;Expected:
;Destroyed:
;Comment: 
;ToDo:
;========================================================================

;==============================Copy_Buff=================================
Copy_Buff       proc
                push cs

                mov ax, cs
                mov es, ax
                mov di, offset Safe_Buf
                
                mov ax, _VmemSeg_
                mov ds, ax
                mov si, _VmemPos_ + (160d * 2) ;pos + scroll 2 lines
                mov cx, (_NRegs_ + 2d)
                
@@nextline:     mov dx, cx ;save cx
                mov cx, (_RegStrLen_ + 2d)
                rep movsw ;copy line from ds:si -> es:di
                lea si, [si + (80d - _RegStrLen_ - 2d) * 2] ;next line
                mov cx, dx
                loop @@nextline

                pop ds
                ret
                endp
;==============================Copy_Buff=================================
;Entry: 
;Exit:  
;Expected:
;Destroyed: ax, di, si, cx, dx
;Comment: copy vmem under frame to buff
;ToDo:
;========================================================================

;==============================Check_Buff================================
Check_Buff      proc 

                mov ax, cs
                mov ds, ax ;ds = cs
                mov si, offset Draw_Buf
                xor bx, bx

                mov ax, _VmemSeg_
                mov es, ax
                mov di, _VmemPos_
                mov cx, (_NRegs_ + 2d)

@@lp:           mov dx, cx ;save cx
                mov cx, (_RegStrLen_ + 2d) ;line size

@@checkline:    test cx, cx
                jz @@equal
                repe cmpsw ;cmps words in vmem and draw buf
                je @@equal
                sub di, 2d ;word back
                sub si, 2d

                mov ax, es:[di] ;get not_equ sym

                mov word ptr ds:[si], ax ;fill draw buf
                lea bx, [si + Safe_Buf - Draw_Buf]
                mov word ptr ds:[bx], ax ;fill save buf

                add di, 2d
                add si, 2d
                jmp @@checkline
@@equal:        lea di, [di + (80d - _RegStrLen_ - 2d) * 2] ;nextline
                mov cx, dx ;get cx
                loop @@lp
                
                ret
                endp
;==============================Check_Buff================================
;Entry: -
;       es:di - vmem
;       ds:si - draw buf
;       ds:bx - safe buf
;Exit:  
;Expected:
;Destroyed: ax, bx, cx, dx, es:di, si
;Comment: comparing vmem under frame with draw_buff 
;rewrite safe and draw bufs
;ToDo:
;========================================================================

;==============================Write_Draw================================
Write_Draw      proc 
                STOS_LINE 201, color_0, 1 ;lft corner
                STOS_LINE 205, color_0, _RegStrLen_ ;up line
                STOS_LINE 187, color_0, 1 ;rght corner

                mov cx, _NRegs_
@@next_reg:     
                mov dx, [bp + si] ; dx = cur_reg si = 2 * reg_idx
                call Write_Reg ;write val(dx) to buf (Reg=0000h)
                add si, 2 ;next reg
                loop @@next_reg ; 'AX=0000h'...

                STOS_LINE 200, color_0, 1 ;lft corner
                STOS_LINE 205, color_0, _RegStrLen_ ;dwn line
                STOS_LINE 188, color_0, 1 ;rght corner

                ret
                endp
;==============================Write_Draw================================
;Entry: di = offset Draw_Buf
;       es:di - write offset 
;       si = stack ofs
;Exit:  
;Expected:
;Destroyed: ax, dx, di, si, cx
;Comment: write frame with reg values to draw_buf 
;ToDo:
;========================================================================

;==============================Write_Reg=================================
Write_Reg       proc
                push bx cx si

                STOS_LINE 186, color_0, 1 ;1 piece

                mov bx, si ;bx = 2 * idx
                shr si, 1 ;si = idx
                add si, bx ;3 * idx (strlen * reg_idx)
                lea si, [si + RegNames] ;reg_data + strlen * idx
                
                mov cx, 3 ;strlen("AX=")
                mov ah, color_0 ;atribute color
                
@@lp:           lodsb ;RegData[i][k] -> al
                stosw ;ax -> draw_buf
                loop @@lp
                call Itoa ;dx -> draw_buf

                STOS_LINE 186, color_0, 1 ;1 piece

                pop si cx bx
                ret
                endp
;==============================Write_Reg=================================
;Entry: dx - reg_value
;       si - 2*reg_idx
;       es:di - write offset 
;Exit:  
;Expected:
;Destroyed: ax, dx, di
;Comment: write reg value to draw_buf 
;ToDo:
;========================================================================

;==============================Write_Vmem================================
Write_Vmem      proc
                push _VmemSeg_
                pop es ;vmem seg

                mov di, _VmemPos_ ; vmem pos
                mov cx, (_NRegs_ + 2d); size = regstrlen * 

@@vmem:         mov dx, cx ;save cx
                mov cx, (_RegStrLen_  + 2d)
                rep movsw
                lea di, [di + (80d - _RegStrLen_ - 2d) * 2] ;next line
                mov cx, dx
                loop @@vmem

@@exit:         ret
                endp
;==============================Write_Vmem================================
;Entry: si - buf ofs
;Exit:  
;Expected:
;Destroyed: ax, bx, es:di
;Comment: write draw_buf to vmem 
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