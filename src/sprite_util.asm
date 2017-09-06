; sprite_util.asm
bits 16

%include "syntax_macros.mac"
%include "bmp_util.inc"
%include "sprite_util.inc"

; bmp_util.asm
extern bmp_load
extern bmp_extract_mask

; file_util.asm
extern open_file
extern close_file
extern read_file

; renderer.asm
extern render_maskblt

struc SpriteHeader
	.bmp_filename:	resb 256
	.sprite_width:	resw 1
	.sprite_height:	resw 1
	.color_key:		resw 1
	.num_anims:		resw 1
	.num_frames:	resw SPRITE_MAX_ANIMS
	.anim_fps:		resw SPRITE_MAX_ANIMS
endstruc

segment code CLASS=code

proc sprite_load
	%arg seg_sprite_filename:word, data_sprite_filename:word
	%arg seg_sprite:word, data_sprite:word
	%arg seg_bmp_store:word, data_bmp_store:word
	%arg seg_mask_store:word, data_mask_store:word
	stack_reserve 2
	%local file_handle:word
	mpush bx, di

	ccall open_file, word [seg_sprite_filename], word [data_sprite_filename]
	cmp ax, -1
	jz .failed
	mov [file_handle], ax

	ccall read_file, word [file_handle], SpriteHeader_size, bss, sprite_header
	jz .failed

	; load the sprite bmp
	mov dx, [data_sprite]
	add dx, Sprite.bmp_info

	ccall bmp_load, 										\
		segaddr(sprite_header) + SpriteHeader.bmp_filename,	\
		word [seg_sprite], dx,								\
		word [seg_bmp_store], word [data_bmp_store]
	cmp ax, -1
	jz .failed

	; create transparency mask
	movax fs, bss
	mov dx, [data_sprite]
	mov ax, dx
	add ax, Sprite.bmp_info
	add dx, Sprite.mask_info

	ccall bmp_extract_mask,									\
		word [seg_sprite], ax,								\
		word [seg_bmp_store], word [data_bmp_store],		\
		word [fs:sprite_header + SpriteHeader.color_key], 	\
		word [seg_sprite], dx,                              \
		word [seg_mask_store], word [data_mask_store]

	ccall close_file, word [file_handle]
	cmp ax, -1
	jz .failed

	; store sprite info
	movax fs, bss
	movax gs, [seg_sprite]
	mov bx, [data_sprite]

	movax [gs:bx + Sprite.frame_width], [fs:sprite_header + SpriteHeader.sprite_width]
	movax [gs:bx + Sprite.frame_height], [fs:sprite_header + SpriteHeader.sprite_height]
	movax [gs:bx + Sprite.num_anims], [fs:sprite_header + SpriteHeader.num_anims]

	mov cx, SPRITE_MAX_ANIMS
	xor di, di
.num_frames_loop:
	movax [gs:bx + di + Sprite.num_frames], [fs:sprite_header + di + SpriteHeader.num_frames]
	add di, 2
	loop .num_frames_loop

	mov cx, SPRITE_MAX_ANIMS
	xor di, di
.anim_fps_loop:
	movax [gs:bx + di + Sprite.anim_fps], [fs:sprite_header + di + SpriteHeader.anim_fps]
	add di, 2
	loop .anim_fps_loop

	mov word [gs:bx + Sprite.anim_index], 0
	mov word [gs:bx + Sprite.anim_frame], 0
	mov word [gs:bx + Sprite.anim_state], 0

	xor ax, ax
	jmp .eof
.failed:
	mov ax, -1
.eof:
	mpop di, bx
endproc

proc sprite_render
	%arg seg_sprite:word, data_sprite:word
	%arg x_dst:word, y_dst:word
	push bx

	movax fs, [seg_sprite]
	mov bx, [data_sprite]

	mov cx, [fs:bx + Sprite.frame_width]
	imul cx, [fs:bx + Sprite.anim_frame]
	mov dx, [fs:bx + Sprite.frame_height]
	imul dx, [fs:bx + Sprite.anim_index]

	ccall render_maskblt,																									\
		word [x_dst], word [y_dst],																							\
		word [fs:bx + Sprite.frame_width], word [fs:bx + Sprite.frame_height],										\
		word [fs:bx + Sprite.bmp_info + BmpInfo.data_ptr + 2], word [fs:bx + Sprite.bmp_info + BmpInfo.data_ptr],	\
		cx, dx,																												\
		word [fs:bx + Sprite.bmp_info + BmpInfo.width],																	\
		word [fs:bx + Sprite.mask_info + BmpInfo.data_ptr + 2], word [fs:bx + Sprite.mask_info + BmpInfo.data_ptr]

	pop bx
endproc

; advance current sprite animation with a screen frame
proc sprite_update
	%arg seg_sprite:word, data_sprite:word
	mpush bx, di

	movax fs, [seg_sprite]
	mov bx, [data_sprite]

	; quick out if there is only one frame in this anim
	mov di, [fs:bx + Sprite.anim_index]
	imul di, 2
	; mov word [fs:bx + di + Sprite.num_frames], 4
	; mov word [fs:bx + di + Sprite.anim_fps], 7
	mov cx, [fs:bx + di + Sprite.num_frames]
	cmp cx, 1
	jz .eof

	inc word [fs:bx + Sprite.anim_state]
	mov ax, [fs:bx + di + Sprite.anim_fps]
	if {cmp [fs:bx + Sprite.anim_state], ax}, z
		mov word [fs:bx + Sprite.anim_state], 0
		inc word [fs:bx + Sprite.anim_frame]

		; if animation ended, reset to 0 the sprite frame
		if {cmp [fs:bx + Sprite.anim_frame], cx}, z
			mov word [fs:bx + Sprite.anim_frame], 0
		endif
	endif

.eof:
	mpop di, bx
endproc

	; .anim_fps:		resb SPRITE_MAX_ANIMS

	; ; SPRITE STATE
	; ; animations are on y axis
	; .anim_index:	resb 1
	; ; current frame in animation
	; ; resets to 0 when no more animation frames
	; .anim_frame:	resb 1
	; ; current screen frame for current sprite frame
	; ; resets to 0 on each sprite frame advance
	; .anim_state:	resb 1

; multiply by the factor each anim_fps in the sprite
proc sprite_set_anim_fps_factor
	%arg seg_sprite:word, data_sprite:word
	%arg fps_factor:word
	mpush bx, di

	movax fs, [seg_sprite]
	mov bx, [data_sprite]
	mov ax, [fps_factor]

	mov di, [fs:bx + Sprite.anim_index]
	imul di, 2
	imul ax, [fs:bx + di + Sprite.anim_fps]
	mov [fs:bx + di + Sprite.anim_fps], ax

	mpop di, bx
endproc

proc sprite_reset
	%arg seg_sprite:word, data_sprite:word

	push bx

	movax fs, [seg_sprite]
	mov bx, [data_sprite]

	mov word [fs:bx + Sprite.anim_frame], 0
	mov word [fs:bx + Sprite.anim_state], 0

.eof:
	pop bx
endproc

proc sprite_set_anim_index
	%arg seg_sprite:word, data_sprite:word
	%arg anim_index:word
	push bx

	mov dx, [anim_index]
	; check if valid anim index
	cmp dx, [fs:bx + Sprite.num_anims]
	jge .eof

	movax fs, [seg_sprite]
	mov bx, [data_sprite]

	; change only if different
	cmp [fs:bx + Sprite.anim_index], dx
	jz .eof

	mov [fs:bx + Sprite.anim_index], dx
	ccall sprite_reset, word [seg_sprite], word [data_sprite]

.eof:
	pop bx
endproc

segment bss private CLASS=data

sprite_header: resb SpriteHeader_size
