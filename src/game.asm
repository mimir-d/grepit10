; main.asm
bits 16

%include "syntax_macros.mac"
%include "kb_scancodes.mac"

%define WIDTH 320
%define HEIGHT 200

%define SPEED_X 	3
%define SPEED_JUMP 	13
%define GRAVITY_Y	-1

; engine.asm
extern engine_set_init_callback
extern engine_set_shutdown_callback
extern engine_set_update_callback
extern engine_set_render_callback
extern init_engine
extern shutdown_engine
extern engine_mainloop
extern engine_signalstop

; renderer.asm
extern put_pixel
extern draw_rect
extern render_clear
extern render_bitblt
extern render_maskblt

; loader.asm
extern bmp_load
extern bmp_extract_mask
extern bmp_render_background
extern bmp_render
extern bmp_render_masked
%include "bmp_util.inc"

; sprite_util.asm
extern sprite_load
extern sprite_render
extern sprite_update
extern sprite_set_anim_fps_factor
extern sprite_set_anim_index
%include "sprite_util.inc"

; keyboard.asm
extern get_key_pressed

; util.asm
extern rand
extern memset
extern memcpy

%define OBJ_VISIBLE	80h

%define MARIO_STATE_NONE		0
%define MARIO_STATE_RIGHT_LEFT	1h ; bit is set if right, else left
%define MARIO_STATE_WALK		2h
%define MARIO_STATE_JUMP		4h

%define MARIO_ANIM_WALK_RIGHT	0
%define MARIO_ANIM_WALK_LEFT	1
%define MARIO_ANIM_STAND_RIGHT	2
%define MARIO_ANIM_STAND_LEFT	3
%define MARIO_ANIM_JUMP_RIGHT	4
%define MARIO_ANIM_JUMP_LEFT	5

struc GameState
	.pos:		resw 2
	.speed: 	resw 2
	.accel: 	resw 2
	.mario: 	resb 1
	.coin:		resb 1
	.win: 	resb 1
endstruc
%define state(x) fs:game_state + GameState.%+ x

segment code use16 CLASS=code

wait_key:
	mov ah, 0
	int 16h
	ret

proc init_cb
	; load background bmp
	ccall bmp_load, segaddr(bg_bmp_filename), segaddr(bg_bmp_info), segaddr(bg_buffer)

	; load mario sprite
	ccall sprite_load, segaddr(mario_spr_filename), segaddr(mario_sprite), segaddr(mario_spr_bmp_store), segaddr(mario_spr_mask_store)

	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_RIGHT
	ccall sprite_set_anim_fps_factor, segaddr(mario_sprite), 4
	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_LEFT
	ccall sprite_set_anim_fps_factor, segaddr(mario_sprite), 4
	ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_RIGHT

	; load coin sprite
	ccall sprite_load, segaddr(coin_spr_filename), segaddr(coin_sprite), segaddr(coin_spr_bmp_store), segaddr(coin_spr_mask_store)

	; load winner bmp
	ccall bmp_load, segaddr(winner_filename), segaddr(winner_bmp), segaddr(winner_bmp_store)
	ccall bmp_extract_mask, segaddr(winner_bmp), segaddr(winner_bmp_store), 15, segaddr(winner_mask), segaddr(winner_mask_store)

	xor ax, ax
endproc

proc shutdown_cb
	; maybe stuff here?
endproc

proc update_input
	movax fs, data

	ccall get_key_pressed, KB_ESC
	if {test ax, ax}, nz
		ccall engine_signalstop
	endif

	; read keyboard input
	if {ccall get_key_pressed, KB_RIGHT_ARROW}, {test ax, ax}, nz
		mov word [state(speed)], SPEED_X

		or word [state(mario)], MARIO_STATE_RIGHT_LEFT | MARIO_STATE_WALK
	elseif {ccall get_key_pressed, KB_LEFT_ARROW}, {test ax, ax}, nz
		mov word [state(speed)], -SPEED_X

		and word [state(mario)], ~MARIO_STATE_RIGHT_LEFT
		or word [state(mario)], MARIO_STATE_WALK
	else
		mov word [state(speed)], 0

		and word [state(mario)], ~MARIO_STATE_WALK
	endif

	; if {ccall get_key_pressed, KB_UP_ARROW}, {test ax, ax}, nz
	; 	mov word [state(speed)+2], SPEED_X
	; elseif {ccall get_key_pressed, KB_DOWN_ARROW}, {test ax, ax}, nz
	; 	mov word [state(speed)+2], -SPEED_X
	; else
	; 	mov word [state(speed)+2], 0
	; endif

	if {ccall get_key_pressed, KB_SPACE}, {test ax, ax}, nz
		if {test byte [state(mario)], MARIO_STATE_JUMP}, z
			mov word [state(speed) + 2], SPEED_JUMP
			or byte [state(mario)], MARIO_STATE_JUMP
		endif
	endif
endproc

proc update_collisions
	movax fs, data

	if {cmp word [state(pos)], 262}, ge
		if {cmp word [state(pos)], 274}, le
			if {cmp word [state(pos) + 2], 62}, ge
				if {cmp word [state(pos) + 2], 94}, le
					and byte [state(coin)], ~OBJ_VISIBLE
					or byte [state(win)], OBJ_VISIBLE
				endif
			endif
		endif
	endif
endproc

proc update_objects
	movax fs, data

	; update physics
	addax [state(speed)], [state(accel)]
	addax [state(speed) + 2], [state(accel) + 2]

	addax [state(pos)], [state(speed)]
	addax [state(pos) + 2], [state(speed) + 2]

	; limit to lower bound platform
	if {cmp word [state(pos) + 2], 16}, le
		mov word [state(pos) + 2], 16
		mov word [state(speed) + 2], 0

		and byte [state(mario)], ~MARIO_STATE_JUMP
	endif

	; limit left
	if {cmp word [state(pos)], 0}, le
		mov word [state(pos)], 0
	endif

	; limit right
	if {cmp word [state(pos)], 304}, ge
		mov word [state(pos)], 304
	endif

	; limit top
	if {cmp word [state(pos)+2], 200}, ge
		mov word [state(pos)+2], 200
	endif

	if {test word [state(mario)], MARIO_STATE_JUMP}, nz
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_JUMP_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_JUMP_LEFT
		endif
	elseif {test word [state(mario)], MARIO_STATE_WALK}, nz
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_WALK_LEFT
		endif
	else
		if {test word [state(mario)], MARIO_STATE_RIGHT_LEFT}, nz
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_RIGHT
		else
			ccall sprite_set_anim_index, segaddr(mario_sprite), MARIO_ANIM_STAND_LEFT
		endif
	endif
endproc

proc update_anims
	ccall sprite_update, segaddr(mario_sprite)
	ccall sprite_update, segaddr(coin_sprite)
endproc

proc update_cb
	ccall update_input
	ccall update_collisions
	ccall update_objects
	ccall update_anims
endproc

proc render_objects
	movax fs, data
	if {test byte [state(win)], OBJ_VISIBLE}, nz
		mov ax, HEIGHT
		sub ax, 16+41+64+30
		if {test byte [state(win)], OBJ_VISIBLE}, nz
			ccall bmp_render_masked, segaddr(winner_bmp), segaddr(winner_mask), 25, ax
		endif
	endif

	movax fs, data
	mov ax, HEIGHT
	sub ax, 70
	if {test byte [state(coin)], OBJ_VISIBLE}, nz
		ccall sprite_render, segaddr(coin_sprite), 270, ax
	endif

	movax fs, data
	mov ax, HEIGHT
	sub ax, [state(pos) + 2]
	ccall sprite_render, segaddr(mario_sprite), word [state(pos)], ax
endproc

proc render_cb
	ccall render_clear
	ccall bmp_render_background, segaddr(bg_bmp_info)

	ccall render_objects
endproc

proc ..start
	; push engine callbacks
	ccall engine_set_init_callback, segaddr(init_cb)
	ccall engine_set_shutdown_callback, segaddr(shutdown_cb)
	ccall engine_set_update_callback, segaddr(update_cb)
	ccall engine_set_render_callback, segaddr(render_cb)

	; run engine
	ccall init_engine
	if {test ax, ax}, z
		ccall engine_mainloop
	endif
	ccall shutdown_engine
	if {test ax, ax}, nz
		; print some fail msg
	endif

	mov ax, 4C00h
	int 21h
endproc

;------------------------------------------------------------------------------
; program data segment
;------------------------------------------------------------------------------
segment data use16 CLASS=data

game_state: istruc GameState
	at GameState.pos, dw 10, 10
	at GameState.speed, dw 0, 0
	at GameState.accel, dw 0, GRAVITY_Y
	at GameState.mario, db MARIO_STATE_NONE
	at GameState.coin, db OBJ_VISIBLE
	at GameState.win, db 0
iend

bg_bmp_filename: db "bg.bmp", 0
mario_spr_filename: db "mario.spr", 0
coin_spr_filename: db "coin.spr", 0
winner_filename: db "winner.bmp", 0

;------------------------------------------------------------------------------
; background bmp data segment
;------------------------------------------------------------------------------
segment bg_seg private align=4 CLASS=data

bg_buffer: resb 64000
bg_bmp_info: resb BmpInfo_size

;------------------------------------------------------------------------------
; sprite data segment
;------------------------------------------------------------------------------
segment sprite_seg private CLASS=data

mario_sprite: resb Sprite_size
align 4
mario_spr_bmp_store: resb 64*96
align 4
mario_spr_mask_store: resb 64*96

coin_sprite: resb Sprite_size
align 4
coin_spr_bmp_store: resb 128*16
align 4
coin_spr_mask_store: resb 128*16

;------------------------------------------------------------------------------
; other bmp data segment
;------------------------------------------------------------------------------
segment other_seg private CLASS=data

winner_bmp: resb BmpInfo_size
winner_mask: resb BmpInfo_size
align 4
winner_bmp_store: resb 96*96
align 4
winner_mask_store: resb 96*96

;------------------------------------------------------------------------------
; stack segment
;------------------------------------------------------------------------------
segment stack stack
    resw 1024
stacktop:
