; file_util.asm

%include "syntax_macros.mac"

%define DOS_OPEN_FILE	3D00h
%define DOS_CLOSE_FILE	3E00h
%define DOS_READ_FILE	3F00h
%define DOS_SEEK_FILE	4200h

segment code use16 CLASS=code

proc open_file
	%arg seg_filename:word, data_filename:word
	push ds
	
	movax ds, [seg_filename]
	mov dx, [data_filename]
	mov ax, DOS_OPEN_FILE
	int 21h
	jc .failed
	jmp .eof

.failed:
	mov ax, -1
	jmp .eof

.eof:
	pop ds
endproc

proc close_file
	%arg handle:word
	push bx

	mov ax, DOS_CLOSE_FILE
	mov bx, [handle]
	int 21h
	jnc .eof

	mov ax, -1 ; dont really care about the error though
.eof:
	pop bx
endproc

proc read_file
	%arg handle:word, size:word
	%arg seg_dst:word, data_dst:word

	mpush ds, bx

	mov bx, [handle]
	mov cx, [size]
	mov ds, [seg_dst]
	mov dx, [data_dst]
	mov ax, DOS_READ_FILE
	int 21h
	jnc .eof

	xor ax, ax
.eof:
	mpop bx, ds
endproc

proc seek_file
	%arg handle:word, offset_low:word, offset_hi:word

	push bx

	mov bx, [handle]
	mov ax, DOS_SEEK_FILE
	mov cx, [offset_hi]
	mov dx, [offset_low]
	int 21h
	jnc .eof

	mov ax, -1

.eof:
	pop bx
endproc
