; bmp_util.inc
%ifndef BMP_UTIL_INC
%define BMP_UTIL_INC

struc BmpInfo
	.width:		resw 1
	.height:	resw 1
	.data_ptr:	resw 2	; includes segment at +2
	.stride:	resw 1
endstruc

%endif