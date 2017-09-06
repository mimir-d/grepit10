; engine.asm
bits 16

%include "syntax_macros.mac"
%include "kb_scancodes.mac"

; renderer.asm
extern init_render_system
extern shutdown_render_system
extern draw_rect
extern render_clear
extern render_flip
extern render_beginframe
extern render_endframe

; timer.asm
extern init_timer_system
extern shutdown_timer_system
extern timer_get_ticks

; keyboard.asm
extern init_kb_system
extern shutdown_kb_system
extern get_key_pressed

; util.asm
extern srandom

segment code use16 CLASS=code

init_cb: resw 2
shutdown_cb: resw 2
update_cb: resw 2
render_cb: resw 2
engine_done: resb 1

%macro define_engine_set_callback 2
	proc engine_set_%{1}_callback
		%arg seg_cb:word, callback:word

		movax [cs:%2], [callback]
		movax [cs:%2 + 2], [seg_cb]
		xor ax, ax
	endproc
%endmacro

define_engine_set_callback init, init_cb
define_engine_set_callback shutdown, shutdown_cb
define_engine_set_callback update, update_cb
define_engine_set_callback render, render_cb

%macro try_init_system 1
	ccall %1
	test ax, ax
	jnz .eof
%endmacro
proc init_engine
	try_init_system init_kb_system
	try_init_system init_timer_system
	try_init_system init_render_system

	ccall timer_get_ticks
	ccall srandom, ax, dx

	mov byte [cs:engine_done], 0

	; return value = 0
	xor ax, ax
	call far [cs:init_cb]
.eof:
endproc

proc shutdown_engine
	call far [cs:shutdown_cb]

	ccall shutdown_render_system
	ccall shutdown_timer_system
	ccall shutdown_kb_system
endproc

proc engine_mainloop
	do
		ccall render_beginframe

		call [cs:update_cb]
		call [cs:render_cb]
		call render_flip

		ccall render_endframe

		mov al, [cs:engine_done]
	while {test al, al}, z
endproc

proc engine_signalstop
	mov byte [cs:engine_done], 1
endproc