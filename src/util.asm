; util.asm
bits 16

%define RAND_A_PARAM 0CB30h
%define RAND_C_PARAM 0C39EC3h

%include "syntax_macros.mac"

segment code use16 CLASS=code

proc srandom
	%arg seed_low:word, seed_high:word
	movax [cs:rand.random_x], [seed_low]
	movax [cs:rand.random_y], [seed_high]
endproc

; based on http://b2d-f9r.blogspot.ro/2010/08/16-bit-xorshift-rng-now-with-more.html
; formula t=(xˆ(x<<a)); x=y; return y=(yˆ(y>>c))ˆ(tˆ(t>>b));
proc rand
	push cx
    push dx

    ; db 0b8h dw 1 translates to
    ; 0b800 01 which is mov ax, 1
    ; this also allocates space for random x, y numbers
    db 0b8h                 ; t=(x^(x shl a))
.random_x: dw 1
    mov dx, ax
    mov cl, 5
    shl dx, cl
    xor ax, dx
    mov dx, ax               ; y=(y^(y shr c))^(t^(t shr b))
    mov cl, 3                ;                  ^^^^^^^^^^^
    shr dx, cl
    xor ax, dx
    push ax                  ; save t^(t shr b)
    db 0b8h
.random_y: dw 1
    mov [cs:.random_x], ax   ; x=y
    mov dx, ax               ; y=(y^(y shr c))^(t^(t shr b))
    shr dx, 1                ;    ^^^^^^^^^^^
    xor ax, dx
    pop dx
    xor ax, dx
    mov [cs:.random_y], ax

    pop dx
    pop cx
endproc

unaligned_mask_bits: dd 0, 0FFh, 0FFFFh, 0FFFFFFh

proc memset
	%arg seg_dest:word, data_dest:word
	%arg value:word, num:word

	mpush es, di, si, ebx, eax
	cld

	cmp word [num], 0
	je .no_remaining

	mov es, [seg_dest]
	mov di, [data_dest]

	mov ebx, 01010101h
	xor edx, edx
	mov dl, [value]
	imul ebx, edx
	
	; align to 4 bytes (dword)
	mov ax, di
	and ax, 11b
	jnz .not_aligned
	
.prepare_aligned_copy:
	mov cx, [num]
	and cx, ~11b
	jmp .aligned

.not_aligned:
	mov cx, 4
	sub cx, ax

	; at most [num] bytes, cx = min(cx, [num])
	cmp cx, [num]
	jb .unaligned_prepare
	mov cx, [num]

.unaligned_prepare:
	sub [num], cx
	; unaligned copy of start bytes
	; no "rep movsb" for less than 4 bytes
.unaligned_start:
	mov eax, [cs:unaligned_mask_bits + ecx*4]

	mov edx, ebx
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax

	add si, cx
	add di, cx

	; if all bytes were unaligned prefix
	cmp word [num], 0
	jz .no_remaining
	jmp .prepare_aligned_copy

.aligned:
	sub [num], cx
	shr cx, 2
	jz .no_aligned_bytes

	mov eax, ebx
	rep stosd

.no_aligned_bytes:
	; remaining bytes
	mov cx, [num]
	test cx, cx
	jz .no_remaining

	; unaligned copy of end bytes
	mov eax, [cs:unaligned_mask_bits + ecx*4]

	mov edx, ebx
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax
	
.no_remaining:
	mpop eax, ebx, si, di, es
endproc

; this uses some 32bit memory addressing
; if needed, replace with 16bit addressing (2x slower)
proc memcpy
	%arg seg_dest:word, data_dest:word
	%arg seg_src:word, data_src:word
	%arg num:word

	mpush ds, es, si, di, ebx, eax
	cld

	mov bx, [num]
	cmp bx, 0
	je .no_remaining

	mov ds, [seg_src]
	mov si, [data_src]
	mov es, [seg_dest]
	mov di, [data_dest]
	
	; align to 4 bytes (dword)
	mov ax, di
	and ax, 11b
	jnz .not_aligned
	
.prepare_aligned_copy:
	mov cx, bx
	and cx, ~11b
	jmp .aligned

.not_aligned:
	mov cx, 4
	sub cx, ax

	; at most [num] bytes, cx = min(cx, [num])
	cmp cx, bx
	jb .unaligned_prepare
	mov cx, bx

.unaligned_prepare:
	sub bx, cx
	; unaligned copy of start bytes
	; no "rep movsb" for less than 4 bytes
.unaligned_start:
	mov eax, [cs:unaligned_mask_bits + ecx*4]

	mov edx, [ds:si]
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax

	add si, cx
	add di, cx

	; if all bytes were unaligned prefix
	cmp bx, 0
	jz .no_remaining
	jmp .prepare_aligned_copy

.aligned:
	sub bx, cx
	shr cx, 2
	jz .no_aligned_bytes
	rep movsd

.no_aligned_bytes:
	; remaining bytes
	mov cx, bx
	test cx, cx
	jz .no_remaining

	; unaligned copy of end bytes
	mov eax, [cs:unaligned_mask_bits + ecx*4]

	mov edx, [ds:si]
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax
	
.no_remaining:
	mpop eax, ebx, di, si, es, ds
endproc

proc memcpy_masked
	%arg seg_dest:word, data_dest:word
	%arg seg_src:word, data_src:word
	%arg seg_mask:word, data_mask:word
	%arg num:word

	mpush ds, es, si, di, ebx, eax
	cld

	cmp word [num], 0
	je .no_remaining

	mov ds, [seg_src]
	mov si, [data_src]
	mov es, [seg_dest]
	mov di, [data_dest]
	mov fs, [seg_mask]
	mov bx, [data_mask]
	
	; align to 4 bytes (dword)
	mov ax, di
	and ax, 11b
	jnz .not_aligned
	
.prepare_aligned_copy:
	mov cx, [num]
	and cx, ~11b
	jmp .aligned

.not_aligned:
	mov cx, 4
	sub cx, ax

	; at most [num] bytes, cx = min(cx, [num])
	cmp cx, [num]
	jb .unaligned_prepare
	mov cx, [num]

.unaligned_prepare:
	sub [num], cx
	; unaligned copy of start bytes
	; no "rep movsb" for less than 4 bytes
.unaligned_start:
	mov eax, [cs:unaligned_mask_bits + ecx*4]
	and eax, [fs:bx]

	mov edx, [ds:si]
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax

	add si, cx
	add di, cx
	add bx, cx

	; if all bytes were unaligned prefix
	cmp word [num], 0
	jz .no_remaining
	jmp .prepare_aligned_copy

.aligned:
	sub [num], cx
	shr cx, 2
	jz .no_aligned_bytes

.aligned_loop:
	mov eax, [fs:bx]

	mov edx, [ds:si]
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax

	add si, 4
	add di, 4
	add bx, 4
	loop .aligned_loop

.no_aligned_bytes:
	; remaining bytes
	mov cx, [num]
	test cx, cx
	jz .no_remaining

	; unaligned copy of end bytes
	mov eax, [cs:unaligned_mask_bits + ecx*4]
	and eax, [fs:bx]

	mov edx, [ds:si]
	and edx, eax

	not eax
	and eax, [es:di]

	or eax, edx
	mov [es:di], eax
	
.no_remaining:
	mpop eax, ebx, di, si, es, ds
endproc
