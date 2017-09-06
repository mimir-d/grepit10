; renderer.asm
bits 16

; VGA CRT controller
%define CRTC_STATUS		03DAh
%define CRTC_VRETRACE	1000b
%define VIDEO_START		0A000h

%define TARGET_FPS	45
%define MS_PER_FRAME 1000/TARGET_FPS

%define RES_X 	320
%define RES_Y	200

%include "syntax_macros.mac"

; timer.asm
extern msdelay
extern timer_get_msecs

; util.asm
extern memset
extern memcpy
extern memcpy_masked

segment code CLASS=code

sys_inited: db 0
frame_start_time: dw 0
frame_end_time: dw 0

proc init_render_system
	; set video mode
	; 13h chain4
	mov ax, 13h
	int 10h

	mov byte [cs:sys_inited], 1
	xor ax, ax
endproc

proc shutdown_render_system
	cmp byte [cs:sys_inited], 1
	jnz .eof

	; set video mode text
	mov ax, 3h
	int 10h
	xor ax, ax
.eof:
	mov byte [cs:sys_inited], 0
endproc

proc vsync
	mov dx, CRTC_STATUS
.L1:
	in al, dx
	and al, CRTC_VRETRACE
	jnz .L1
.L2:
	in al, dx
	and al, CRTC_VRETRACE
	jz .L2
endproc

proc render_clear
	ccall memset, segaddr(video_buffer), 0, RES_X * RES_Y
endproc

proc render_flip
	ccall vsync
	ccall memcpy, VIDEO_START, 0, segaddr(video_buffer), RES_X * RES_Y
endproc

proc render_beginframe
	ccall timer_get_msecs
	mov [cs:frame_start_time], ax
endproc

proc render_endframe
	ccall timer_get_msecs
	mov [cs:frame_end_time], ax

	; frame limiter
	sub ax, [cs:frame_start_time]
	mov dx, MS_PER_FRAME
	sub dx, ax
	cmp dx, 0
	jle .end_frame
	ccall msdelay, dx
.end_frame:
endproc

proc put_pixel
	%arg x:word, y:word, color:byte
	push di

	xor ax, ax
	mov cx, [y]
	shl cx, 8
	add ax, cx
	mov cx, [y]
	shl cx, 6
	add ax, cx
	add ax, [x]
	mov di, ax

	movax fs, seg video_buffer

	mov al, [color]
	mov [fs:di + video_buffer], al

	pop di
endproc

proc draw_rect
	stack_reserve 8
	%arg x:word, y:word, width:word, height:word, color:word
	%local currx:word, curry:word
	%local xf:word, yf:word

	movax [xf], [x]
	add ax, [width]
	mov [xf], ax

	movax [yf], [y]
	add ax, [height]
	mov [yf], ax

	forinc word [curry], [y], [yf]
		forinc word [currx], [x], [xf]
			ccall put_pixel, word [currx], word [curry], word [color]
		endfor
	endfor
endproc

proc bitblt
	%arg seg_dst:word, data_dst:word
	%arg x_dst:word, y_dst:word
	%arg width_dst:word, height_dst:word
	%arg seg_src:word, data_src:word
	%arg x_src:word, y_src:word
	%arg stride_dst:word, stride_src:word
	stack_reserve 4
	%local y:word, yf:word

	; add x, y offset in src
	addax [data_src], [x_src]
	mov dx, [y_src]
	if {test dx, dx}, nz
		imul dx, [stride_src]
		add [data_src], dx
	endif

	; add x, y offset in dst
	addax [data_dst], [x_dst]
	mov dx, [y_dst]
	if {test dx, dx}, nz
		imul dx, [stride_dst]
		add [data_dst], dx
	endif

	for {movax [y], 0}, {cmpax word [y], [height_dst]}, l, {inc word [y]}
		ccall memcpy, 							\
			word [seg_dst], word [data_dst], 	\
			word [seg_src], word [data_src], 	\
			word [width_dst]

		addax [data_dst], [stride_dst]
		addax [data_src], [stride_src]
	endfor
endproc

; assumes mask has same dims as src data
proc maskblt
	%arg seg_dst:word, data_dst:word
	%arg x_dst:word, y_dst:word
	%arg width_dst:word, height_dst:word
	%arg seg_src:word, data_src:word
	%arg x_src:word, y_src:word
	%arg stride_dst:word, stride_src:word
	%arg seg_mask:word, data_mask:word
	stack_reserve 4
	%local y:word, yf:word

	; add x, y offset in src/mask
	addax [data_src], [x_src]
	addax [data_mask], [x_src]
	mov dx, [y_src]
	if {test dx, dx}, nz
		imul dx, [stride_src]
		add [data_src], dx
		add [data_mask], dx
	endif

	; add x, y offset in dst
	addax [data_dst], [x_dst]
	mov dx, [y_dst]
	if {test dx, dx}, nz
		imul dx, [stride_dst]
		add [data_dst], dx
	endif

	for {movax [y], 0}, {cmpax word [y], [height_dst]}, l, {inc word [y]}
		ccall memcpy_masked, 					\
			word [seg_dst], word [data_dst], 	\
			word [seg_src], word [data_src], 	\
			word [seg_mask], word [data_mask],	\
			word [width_dst]

		addax [data_dst], [stride_dst]
		addax [data_src], [stride_src]
		addax [data_mask], [stride_src]
	endfor
endproc

proc render_bitblt
	%arg x_dst:word, y_dst:word
	%arg width_dst:word, height_dst:word
	%arg seg_src:word, data_src:word
	%arg x_src:word, y_src:word
	%arg stride_src:word

	ccall bitblt, 								\
		segaddr(video_buffer), 					\
		word [x_dst], word [y_dst],				\
		word [width_dst], word [height_dst],	\
		word [seg_src], word [data_src],		\
		word [x_src], word [y_src],				\
		RES_X, word [stride_src]
endproc

proc render_maskblt
	%arg x_dst:word, y_dst:word
	%arg width_dst:word, height_dst:word
	%arg seg_src:word, data_src:word
	%arg x_src:word, y_src:word
	%arg stride_src:word
	%arg seg_mask:word, data_mask:word

	ccall maskblt, 								\
		segaddr(video_buffer), 					\
		word [x_dst], word [y_dst],				\
		word [width_dst], word [height_dst],	\
		word [seg_src], word [data_src],		\
		word [x_src], word [y_src],				\
		RES_X, word [stride_src],				\
		word [seg_mask], word [data_mask]
endproc

proc render_background
	%arg seg_src:word, data_src:word

	ccall memcpy, segaddr(video_buffer), word [seg_src], word [data_src], RES_X * RES_Y
endproc

segment video_seg private align=4 CLASS=data
video_buffer: resb 64000
