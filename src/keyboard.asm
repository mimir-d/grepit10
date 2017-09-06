; keyboard.asm
bits 16

%define KB_INT  09h
%define KB_PORT 60h
%define SCANCODE_KEYUP_BIT	80h

%include "syntax_macros.mac"
%include "util.mac"
%include "kb_scancodes.mac"

segment code use16 CLASS=code

scan_table: db 																						\
	0, 		  KB_ESC,   '1',          '2',        '3',      '4',       '5',         '6', 			\
	'7',      '8',      '9',          '0',        '-',      '=',       `\b`,        `\t`, 			\
	'q',      'w',      'e',          'r',        't',      'y',       'u',         'i', 			\
	'o',      'p',      '[',          ']',        `\n`,      KB_LCTRL, 'a',         's', 			\
	'd',      'f',      'g',          'h',        'j',      'k',       'l',         ';', 			\
	`\'`,     `\``,     KB_LSHIFT,    `\\`,       'z',      'x',       'c',         'v', 			\
	'b',      'n',      'm',          ',',        '.',      '/',       KB_RSHIFT,   KB_NUM_MUL, 	\
	KB_LALT,  ' ',      KB_CAPSLK,    KB_F1,      KB_F2,    KB_F3,     KB_F4,       KB_F5, 			\
	KB_F6,    KB_F7,    KB_F8,        KB_F9,      KB_F10,   KB_NUMLK,  KB_SCRLK,    KB_NUM_7, 		\
	KB_NUM_8, KB_NUM_9, KB_NUM_MINUS, KB_NUM_4,   KB_NUM_5, KB_NUM_6,  KB_NUM_PLUS, KB_NUM_1, 		\
	KB_NUM_2, KB_NUM_3, KB_NUM_0,     KB_NUM_DOT, KB_SYSRQ, 0,         0,           KB_F11, 		\
	KB_F12,   0,        0,            0,          0,        0,         0,           0,				\
	0,        0,        0,            0,          0,        0,         0,           0,				\
	0,        0,        0,            0,          0,        0,         0,           0,				\
	0,        0,        0,            0,          0,        0,         0,           0,				\
	0,        0,        0,            0,          0,        0,         0,           0

old_kb_isr: resw 2
key_states: times 256 db 0

kb_isr:
	pushf
	mpush ax, bx
	sti

	xor ax, ax
	in al, KB_PORT

	test al, SCANCODE_KEYUP_BIT
	jnz .key_up

	mov bx, ax
	mov bl, [cs:scan_table + bx]
	mov byte [cs:key_states + bx], 1
	jmp .old_isr

.key_up:
	and al, SCANCODE_KEYUP_BIT - 1
	mov bx, ax
	mov bl, [cs:scan_table + bx]
	mov byte [cs:key_states + bx], 0

.old_isr:
	pushf
	call far [cs:old_kb_isr]

	mpop bx, ax
	popf
	iret

sys_inited: db 0

proc init_kb_system
	set_isr_cs KB_INT, code, kb_isr, old_kb_isr

	mov byte [cs:sys_inited], 1
	xor ax, ax
endproc

proc shutdown_kb_system
	cmp byte [cs:sys_inited], 1
	jnz .eof

	restore_isr_cs KB_INT, old_kb_isr
	xor ax, ax
.eof:
	mov byte [cs:sys_inited], 0
endproc

proc get_key_pressed
	%arg key_code:byte
	push bx

	xor bh, bh
	mov bl, [key_code]
	xor ax, ax
	mov al, [cs:key_states + bx]

	pop bx
endproc