; timer.asm
bits 16

%define TIMER_ISR_FREQ 		1193
%define PIT_ISR_OVERFLOW 	10000h

%define PIT_INT			08h
%define PIT_CMD_PORT 	43h
%define PIT_CH0_PORT 	40h
%define PIT_MODE_2_16B 	00_11_010_0b
%define OCW_EOI 		20h
%define PIC1_CMD_PORT 	20h

%include "util.mac"
%include "syntax_macros.mac"

segment code use16 CLASS=code

old_pit_isr:    resw 2
millisecs: 		dw 0
clock_ticks: 	dd 0

pit_isr:
	pushf
	push ax
	cli

	inc word [cs:millisecs]

	; incr PIT timer 0
	add dword [cs:clock_ticks], TIMER_ISR_FREQ
	cmp dword [cs:clock_ticks], PIT_ISR_OVERFLOW
	jl .no_call_old_isr

	; overflow, call old ISR
	sub dword [cs:clock_ticks], PIT_ISR_OVERFLOW
	
	sti
	pushf
	call far [cs:old_pit_isr]
	jmp .isr_out

.no_call_old_isr:
	; end of interrupt signal
	mov al, OCW_EOI
	out PIC1_CMD_PORT, al

.isr_out:
	sti
	pop ax
	popf
	iret

sys_inited: db 0

proc init_timer_system
	set_isr_cs PIT_INT, code, pit_isr, old_pit_isr

	mov al, PIT_MODE_2_16B
	out PIT_CMD_PORT, al

	mov al, TIMER_ISR_FREQ % 100h
	out PIT_CH0_PORT, al
	mov al, TIMER_ISR_FREQ / 100h
	out PIT_CH0_PORT, al

	mov byte [cs:sys_inited], 1
	xor ax,ax
endproc

proc shutdown_timer_system
	cmp byte [cs:sys_inited], 1
	jnz .eof

	; restore timer
	mov al, PIT_MODE_2_16B
	out PIT_CMD_PORT, al

	xor al, al
	out PIT_CH0_PORT, al
	out PIT_CH0_PORT, al

	restore_isr_cs PIT_INT, old_pit_isr
	xor ax, ax
.eof:
	mov byte [cs:sys_inited], 0
endproc

proc msdelay
	%arg msec:word
	mov cx, [cs:millisecs] ; store initial count

.busy_wait:
	cli
	mov ax, [cs:millisecs]
	sub ax, cx
	cmp ax, [msec] ; compare with given delay
	jz .delay_done

	sti
	times 10 nop ; wait a bit for interrupt to be handled
	jmp .busy_wait

.delay_done:
	sti
endproc

proc timer_get_ticks
	xor ax, ax
	int 1Ah
	mov ax, dx
	mov dx, cx
endproc

proc timer_get_msecs
	mov ax, [cs:millisecs]
endproc