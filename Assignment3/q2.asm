
[org 0x0100]
jmp start

; ---------------- constants ----------------
TOP     equ 4          ; text area rows 4..20, cols 10..70
BOT     equ 20
LEFT    equ 10
RIGHT   equ 70
WIDTH   equ 61         ; RIGHT-LEFT+1
NLINES  equ 13

%macro PUSHI 1         ; 8088 has no push imm
    mov ax, %1
    push ax
%endmacro

; ---------------- data ----------------
title:   db ' TEXT VIEWPORT MANAGER ', 0
status1: db 'Total Matches Found: ', 0
status2: db ' | Viewport Status: ACTIVE', 0
kw:      db 'video', 0

l1:  db 'Assembly language gives you direct control of the hardware.', 0
l2:  db 'On the 8088, text mode video memory starts at segment B800.', 0
l3:  db 'Each screen cell holds one character byte and one attribute', 0
l4:  db 'byte, so the video buffer is 4000 bytes for 80 by 25 cells.', 0
l5:  db 'A viewport window scrolls its own lines upward using MOVSW', 0
l6:  db 'while the borders and the outer screen stay untouched.', 0
l7:  db 'A keyword search compares each row of video text with REPE', 0
l8:  db 'CMPSB and then rewrites only the attribute byte of a match.', 0
l9:  db 'Every video cell keeps its letter, only the colour changes.', 0
l10: db 'Scrolling uses row strides of 160 bytes between text rows.', 0
l11: db 'The count of matches is printed by a stack based printNum.', 0
l12: db 'Good video code is modular, clean and easy to read.', 0
l13: db 'Practice every day and the video output will look right.', 0

text_lines: dw l1,l2,l3,l4,l5,l6,l7,l8,l9,l10,l11,l12,l13

; =====================================================
; MAIN
; =====================================================
start:
    ; clear screen
    PUSHI 0x0720
    call clear_screen

    ; window: top, left, bottom, right, attr
    PUSHI 3
    PUSHI 8
    PUSHI 21
    PUSHI 72
    PUSHI 0x0F
    call draw_window

    ; title centered on row 3 (col 29), attr 0x1E
    PUSHI 3
    PUSHI 29
    call rc2off
    push ax
    PUSHI title
    PUSHI 0x1E
    call print_string

    ; stream text: row, col, width, table, count, attr
    PUSHI TOP
    PUSHI LEFT
    PUSHI WIDTH
    PUSHI text_lines
    PUSHI NLINES
    PUSHI 0x07
    call stream_text

    mov ah, 0              ; wait key, then scroll
    int 0x16

    ; scroll window up: top, left, bottom, right, N
    PUSHI TOP
    PUSHI LEFT
    PUSHI BOT
    PUSHI RIGHT
    PUSHI 2
    call scroll_window_up

    ; highlight keyword: offset, attr
    PUSHI kw
    PUSHI 0xCE
    call find_and_highlight
    mov bx, ax             ; BX = match count

    ; status bar on row 23
    PUSHI 23
    PUSHI 20
    call rc2off
    push ax
    PUSHI status1
    PUSHI 0x0F
    call print_string      ; AX = next video offset

    push ax
    push bx
    PUSHI 0x0E
    call printNum          ; AX = next video offset

    push ax
    PUSHI status2
    PUSHI 0x0F
    call print_string

    mov ah, 0              ; wait key, exit
    int 0x16
    mov ax, 0x4c00
    int 0x21

; =====================================================
; rc2off(row, col) -> AX = (row*80+col)*2
; =====================================================
rc2off:
    push bp
    mov bp, sp
    push dx
    mov ax, [bp+6]         ; row
    mov dx, 80
    mul dx
    add ax, [bp+4]         ; col
    shl ax, 1
    pop dx
    pop bp
    ret 4

; =====================================================
; clear_screen(fillword)
; =====================================================
clear_screen:
    push bp
    mov bp, sp
    push ax
    push cx
    push di
    push es
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, [bp+4]
    mov cx, 2000
    cld
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    pop bp
    ret 2

; =====================================================
; draw_window(top, left, bottom, right, attr)
; top[bp+12] left[bp+10] bottom[bp+8] right[bp+6] attr[bp+4]
; =====================================================
draw_window:
    push bp
    mov bp, sp
    sub sp, 2              ; [bp-2] = interior width
    push ax
    push cx
    push dx
    push di
    push es

    mov ax, 0xb800
    mov es, ax
    cld

    mov ax, [bp+6]
    sub ax, [bp+10]
    dec ax
    mov [bp-2], ax

    ; ---- top border
    push word [bp+12]
    push word [bp+10]
    call rc2off
    mov di, ax
    mov ah, [bp+4]
    mov al, 0xC9
    stosw
    mov al, 0xCD
    mov cx, [bp-2]
    rep stosw
    mov al, 0xBB
    stosw

    ; ---- middle rows
    mov dx, [bp+12]
    inc dx
dw_mid:
    cmp dx, [bp+8]
    jae dw_bottom
    push dx
    push word [bp+10]
    call rc2off
    mov di, ax
    mov ah, [bp+4]
    mov al, 0xBA
    stosw
    mov ax, 0x0720         ; blank interior, normal attr
    mov cx, [bp-2]
    rep stosw
    mov ah, [bp+4]
    mov al, 0xBA
    stosw
    inc dx
    jmp dw_mid

    ; ---- bottom border
dw_bottom:
    push word [bp+8]
    push word [bp+10]
    call rc2off
    mov di, ax
    mov ah, [bp+4]
    mov al, 0xC8
    stosw
    mov al, 0xCD
    mov cx, [bp-2]
    rep stosw
    mov al, 0xBC
    stosw

    pop es
    pop di
    pop dx
    pop cx
    pop ax
    mov sp, bp
    pop bp
    ret 10

; =====================================================
; print_string(videoOffset, strOffset, attr) -> AX = end offset
; offset[bp+8] str[bp+6] attr[bp+4]
; =====================================================
print_string:
    push bp
    mov bp, sp
    push es
    push si
    push di
    mov ax, 0xb800
    mov es, ax
    mov di, [bp+8]
    mov si, [bp+6]
    mov ah, [bp+4]
    cld
ps_loop:
    lodsb
    cmp al, 0
    je ps_done
    stosw
    jmp ps_loop
ps_done:
    mov ax, di
    pop di
    pop si
    pop es
    pop bp
    ret 6

; =====================================================
; stream_text(row, col, width, table, count, attr)
; row[bp+14] col[bp+12] width[bp+10] table[bp+8] count[bp+6] attr[bp+4]
; =====================================================
stream_text:
    push bp
    mov bp, sp
    sub sp, 4              ; [bp-2]=current row, [bp-4]=line index
    push ax
    push bx
    push cx
    push si
    push di
    push es

    mov ax, 0xb800
    mov es, ax
    cld
    mov ax, [bp+14]
    mov [bp-2], ax
    mov word [bp-4], 0
st_line:
    mov ax, [bp-4]
    cmp ax, [bp+6]
    jae st_done
    mov bx, [bp-4]
    shl bx, 1
    add bx, [bp+8]
    mov si, [bx]           ; SI -> line text
    push word [bp-2]
    push word [bp+12]
    call rc2off
    mov di, ax
    mov cx, [bp+10]        ; max chars (margins)
    mov ah, [bp+4]
st_char:
    lodsb
    cmp al, 0
    je st_next
    stosw
    loop st_char
st_next:
    inc word [bp-2]
    inc word [bp-4]
    jmp st_line
st_done:
    pop es
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret 12

; =====================================================
; scroll_window_up(top, left, bottom, right, N)
; top[bp+12] left[bp+10] bottom[bp+8] right[bp+6] N[bp+4]
; =====================================================
scroll_window_up:
    push bp
    mov bp, sp
    sub sp, 4              ; [bp-2]=width in cells, [bp-4]=current row
    push ax
    push cx
    push si
    push di
    push ds
    push es

    mov ax, 0xb800
    mov ds, ax
    mov es, ax
    cld

    mov ax, [bp+6]
    sub ax, [bp+10]
    inc ax
    mov [bp-2], ax
    mov ax, [bp+12]
    mov [bp-4], ax
sw_copy:
    mov ax, [bp-4]
    add ax, [bp+4]         ; source row = r + N
    cmp ax, [bp+8]
    ja sw_blank
    push ax
    push word [bp+10]
    call rc2off
    mov si, ax             ; source offset
    push word [bp-4]
    push word [bp+10]
    call rc2off
    mov di, ax             ; dest offset
    mov cx, [bp-2]
    rep movsw
    inc word [bp-4]
    jmp sw_copy
sw_blank:
    mov ax, [bp-4]         ; first vacated row
    cmp ax, [bp+8]
    ja sw_done
    push ax
    push word [bp+10]
    call rc2off
    mov di, ax
    mov ax, 0x0720
    mov cx, [bp-2]
    rep stosw
    inc word [bp-4]
    jmp sw_blank
sw_done:
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    mov sp, bp
    pop bp
    ret 10

; =====================================================
; find_and_highlight(keywordOffset, attr) -> AX = match count
; keyword[bp+6] attr[bp+4]
; locals: [bp-2]=count [bp-4]=len [bp-6]=row [bp-8]=pos [bp-10]=last pos
;         line buffer = [bp-80] .. (61 bytes)
; (COM file: CS=DS=ES=SS, so the stack buffer is reachable via ES:DI)
; =====================================================
find_and_highlight:
    push bp
    mov bp, sp
    sub sp, 80
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es

    push cs
    pop ds
    push cs
    pop es
    cld

    ; keyword length with REPNE SCASB
    mov di, [bp+6]
    xor al, al
    mov cx, 0xFFFF
    repne scasb
    mov ax, 0xFFFE
    sub ax, cx             ; AX = length
    mov [bp-4], ax
    mov word [bp-2], 0
    mov bx, WIDTH
    sub bx, ax
    mov [bp-10], bx        ; last valid start position
    mov word [bp-6], TOP

fh_row:
    mov ax, [bp-6]
    cmp ax, BOT
    jbe fh_body
    jmp fh_done
fh_body:
    ; copy the row's characters (skip attributes) into the line buffer
    push word [bp-6]
    PUSHI LEFT
    call rc2off
    mov si, ax
    lea di, [bp-80]
    mov cx, WIDTH
    push ds
    mov ax, 0xb800
    mov ds, ax
fh_ex:
    movsb                  ; char -> buffer
    inc si                 ; skip attribute byte
    loop fh_ex
    pop ds

    mov word [bp-8], 0
fh_pos:
    mov ax, [bp-8]
    cmp ax, [bp-10]
    jbe fh_try
    jmp fh_next
fh_try:
    mov si, [bp+6]         ; keyword
    lea di, [bp-80]
    add di, [bp-8]
    mov cx, [bp-4]
    repe cmpsb
    jne fh_nomatch

    ; ---- match: recolor attribute bytes only
    inc word [bp-2]
    push word [bp-6]
    mov ax, LEFT
    add ax, [bp-8]
    push ax
    call rc2off
    mov di, ax
    inc di                 ; first attribute byte
    mov cx, [bp-4]
    mov al, [bp+4]
    push es
    mov bx, 0xb800
    mov es, bx
fh_hl:
    stosb
    inc di                 ; skip the character byte
    loop fh_hl
    pop es
    mov ax, [bp-4]
    add [bp-8], ax         ; skip past the match
    jmp fh_pos
fh_nomatch:
    inc word [bp-8]
    jmp fh_pos
fh_next:
    inc word [bp-6]
    jmp fh_row
fh_done:
    mov ax, [bp-2]
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov sp, bp
    pop bp
    ret 4

; =====================================================
; printNum(videoOffset, number, attr) -> AX = end offset
; offset[bp+8] number[bp+6] attr[bp+4]
; =====================================================
printNum:
    push bp
    mov bp, sp
    sub sp, 2              ; [bp-2] = digit count
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0xb800
    mov es, ax
    mov di, [bp+8]
    mov ax, [bp+6]
    mov bx, 10
    mov word [bp-2], 0
pn_div:
    xor dx, dx
    div bx
    add dl, '0'
    push dx                ; digits go on the stack
    inc word [bp-2]
    cmp ax, 0
    jne pn_div
    mov cx, [bp-2]
    mov ah, [bp+4]
    cld
pn_out:
    pop dx
    mov al, dl
    stosw
    loop pn_out
    mov ax, di

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    mov sp, bp
    pop bp
    ret 6
