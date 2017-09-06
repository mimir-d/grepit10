; sprite_util.inc
%ifndef SPRITE_UTIL_INC
%define SPRITE_UTIL_INC

%define SPRITE_MAX_ANIMS	10

struc Sprite
	; SPRITE DATA
	.bmp_info:		resb BmpInfo_size
	.mask_info:		resb BmpInfo_size
	.frame_width:	resw 1
	.frame_height:	resw 1
	; number of animations in bmp
	.num_anims:		resw 1
	; number of sprite frames in each animation
	.num_frames:	resw SPRITE_MAX_ANIMS
	; uniform speed; no of screen frames between sprite frames
	.anim_fps:		resw SPRITE_MAX_ANIMS

	; SPRITE STATE
	; animations are on y axis
	.anim_index:	resw 1
	; current frame in animation
	; resets to 0 when no more animation frames
	.anim_frame:	resw 1
	; current screen frame for current sprite frame
	; resets to 0 on each sprite frame advance
	.anim_state:	resw 1
endstruc

%endif