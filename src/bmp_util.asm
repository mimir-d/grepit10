; loader.asm
bits 16

%include "syntax_macros.mac"
%include "bmp_util.inc"

; renderer.asm
extern render_bitblt
extern render_maskblt
extern render_background

; file_util.asm
extern open_file
extern close_file
extern read_file
extern seek_file

; util.asm
extern memcpy

%define BMP_SIGNATURE	4D42h

struc BmpFileHeader
	.signature:		resw 1
	.size:			resd 1
	.reserved:		resd 1
	.bits_offset:	resd 1
endstruc

struc BmpHeader
	.header_size:		resd 1
	.width:				resd 1
	.height:			resd 1
	.planes:			resw 1
	.bit_count:			resw 1
	.compression:		resd 1
	.size_image:		resd 1
	.pels_per_meter_x:	resd 1
	.pels_per_meter_y:	resd 1
	.colors_used:		resd 1
	.colors_important:	resd 1
	.red_mask:			resd 1
	.green_mask:		resd 1
	.blue_mask:			resd 1
	.alpha_mask:		resd 1
	.cs_type:			resd 1
	.endpoints:			resd 9
	.gamma_red:			resd 1
	.gamma_green:		resd 1
	.gamma_blue:		resd 1
endstruc

segment code CLASS=code

; files need to have size < 65535
; 8bit indexed with mode 13 palette
proc bmp_load
	%arg seg_filename:word, data_filename:word
	%arg seg_bmp_info:word, data_bmp_info:word
	%arg seg_bmp_data:word, data_bmp_data:word
	stack_reserve 6
	%local file_handle:word
	%local y:word, bmp_stride:word
	mpush es, si, di, bx

	movax fs, bss

	ccall open_file, word [seg_filename], word [data_filename]
	cmp ax, -1
	jz .failed
	mov [file_handle], ax

	; read file header
	ccall read_file, word [file_handle], BmpFileHeader_size, segaddr(bmp_file_header)
	cmp ax, 0
	jz .failed

	; check bmp signature
	cmp word [fs:bmp_file_header + BmpFileHeader.signature], BMP_SIGNATURE
	jnz .failed

	; read bmp header
	ccall read_file, word [file_handle], BmpHeader_size, segaddr(bmp_header)
	cmp ax, 0
	jz .failed

	; go to data
	ccall seek_file, 												\
		word [file_handle], 										\
		word [fs:bmp_file_header + BmpFileHeader.bits_offset],		\
		word [fs:bmp_file_header + BmpFileHeader.bits_offset + 2]
	cmp ax, -1
	jz .failed

	; read bmp data
	ccall read_file, 									\
		word [file_handle], 							\
		word [fs:bmp_header + BmpHeader.size_image],	\
		segaddr(bmp_data)
	jz .failed

	; y is inversed in bmp

	mov bx, [fs:bmp_header + BmpHeader.width]
	; bmp stride
	mov dx, bx
	add dx, 3
	and dx, ~11b
	mov [bmp_stride], dx

	mov es, [seg_bmp_data]
	mov di, [data_bmp_data]

	mov si, bmp_data
	add si, [fs:bmp_header + BmpHeader.size_image]
	sub si, [bmp_stride]
	forinc word [y], 0, [fs:bmp_header + BmpHeader.height]
		ccall memcpy, es, di, seg bmp_data, si, bx
		add di, bx
		sub si, [bmp_stride]
	endfor

	ccall close_file, word [file_handle]
	cmp ax, -1
	jz .failed

	; store bmp info
	movax es, [seg_bmp_info]
	mov di, [data_bmp_info]
	movax [es:di + BmpInfo.width], [fs:bmp_header + BmpHeader.width]
	movax [es:di + BmpInfo.height], [fs:bmp_header + BmpHeader.height]
	movax [es:di + BmpInfo.data_ptr], [data_bmp_data]
	movax [es:di + BmpInfo.data_ptr + 2], [seg_bmp_data]
	movax [es:di + BmpInfo.stride], [fs:bmp_header + BmpHeader.width]

	xor ax, ax
	jmp .eof
.failed:
	mov ax, -1
.eof:
	mpop bx, di, si, es
endproc

proc bmp_extract_mask
	%arg seg_bmp_info:word, data_bmp_info:word
	%arg seg_bmp_data:word, data_bmp_data:word
	%arg color_key:word
	%arg seg_mask_info:word, data_mask_info:word
	%arg seg_mask_data:word, data_mask_data:word
	stack_reserve 2
	%local i:word

	mpush es, ds, si, di, bx

	mov ds, [seg_bmp_data]
	mov si, [data_bmp_data]
	mov es, [seg_mask_data]
	mov di, [data_mask_data]
	xor dx, dx
	mov dl, [color_key]

	movax fs, [seg_bmp_info]
	mov bx, [data_bmp_info]

	mov cx, [fs:bx + BmpInfo.height]
	imul cx, [fs:bx + BmpInfo.width]
	forinc word [i], 0, cx
		if {cmp [ds:si], dl}, z
			mov byte [es:di], 0
		else
			mov byte [es:di], 0FFh
		endif
		inc si
		inc di
	endfor

	; store mask info (copy from source)
	mov ds, [seg_bmp_info]
	mov si, [data_bmp_info]
	mov es, [seg_mask_info]
	mov di, [data_mask_info]
	mov cx, BmpInfo_size
	rep movsb

	mov di, [data_mask_info]
	movax [es:di + BmpInfo.data_ptr + 2], [seg_mask_data]
	movax [es:di + BmpInfo.data_ptr], [data_mask_data]

	mpop bx, di, si, ds, es
endproc

proc bmp_render_background
	%arg seg_bmp_info:word, data_bmp_info:word
	push bx

	movax fs, [seg_bmp_info]
	mov bx, [data_bmp_info]
	ccall render_background, word [fs:bx + BmpInfo.data_ptr + 2], word [fs:bx + BmpInfo.data_ptr]

	pop bx
endproc

proc bmp_render
	%arg seg_bmp_info:word, data_bmp_info:word
	%arg x_dst:word, y_dst:word
	push bx

	movax fs, [seg_bmp_info]
	mov bx, [data_bmp_info]
	ccall render_bitblt,														\
		word [x_dst], word [y_dst],												\
		word [fs:bx + BmpInfo.width], word [fs:bx + BmpInfo.height],			\
		word [fs:bx + BmpInfo.data_ptr + 2], word [fs:bx + BmpInfo.data_ptr],	\
		0, 0,																	\
		word [fs:bx + BmpInfo.width]

	pop bx
endproc

proc bmp_render_masked
	%arg seg_bmp_info:word, data_bmp_info:word
	%arg seg_mask_info:word, data_mask_info:word
	%arg x_dst:word, y_dst:word
	push bx

	; save mask info, only bx is used for addressing
	movax fs, [seg_mask_info]
	mov bx, [data_mask_info]
	mov cx, [fs:bx + BmpInfo.data_ptr + 2]
	mov dx, [fs:bx + BmpInfo.data_ptr]

	movax fs, [seg_bmp_info]
	mov bx, [data_bmp_info]

	ccall render_maskblt,														\
		word [x_dst], word [y_dst],												\
		word [fs:bx + BmpInfo.width], word [fs:bx + BmpInfo.height],			\
		word [fs:bx + BmpInfo.data_ptr + 2], word [fs:bx + BmpInfo.data_ptr],	\
		0, 0,																	\
		word [fs:bx + BmpInfo.width],											\
		cx, dx

	pop bx
endproc
; %arg x_dst:word, y_dst:word
; 	%arg width_dst:word, height_dst:word
; 	%arg seg_src:word, data_src:word
; 	%arg x_src:word, y_src:word
; 	%arg stride_src:word
; 	%arg seg_mask:word, data_mask:word

segment bss private align=4 CLASS=data
bmp_data: resb 64000
bmp_file_header: resb BmpFileHeader_size
bmp_header: resb BmpHeader_size
