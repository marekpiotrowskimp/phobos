| Serwer przerwania VERTB.
| a1 = HwVBlank { count, pending, current, lof_list }.
| Zlecona lista Coppera jest wpinana w trakcie wygaszania pionowego i natychmiast
| restartowana (COPJMP1), więc nowy bufor jest widoczny od bieżącej ramki.
	.text
	.globl	_vblank_server
_vblank_server:
	addq.l	#1,(%a1)
	move.l	4(%a1),%d0
	beq.s	1f
	move.l	%d0,8(%a1)
	clr.l	4(%a1)
	move.l	%d0,0xdff080
	move.w	%d0,0xdff088
1:
	move.l	8(%a1),%d0
	beq.s	2f
	move.l	%d0,0xdff080
	move.l	12(%a1),%a0
	move.l	%d0,(%a0)
2:
	lea	0xdff000,%a0
	moveq	#0,%d0
	rts

| Obsługa przerwania AUD0 (SetIntVector): a0 = custom, a1 = is_Data.
	.globl	_audio_irq
_audio_irq:
	move.w	#0x0080,0x9c(%a0)
	movem.l	%d2-%d7/%a2-%a6,-(%sp)
	jsr	_audio_irq_handler
	movem.l	(%sp)+,%d2-%d7/%a2-%a6
	rts
