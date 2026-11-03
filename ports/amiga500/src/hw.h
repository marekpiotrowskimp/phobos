#ifndef PHOBOS_HW_H
#define PHOBOS_HW_H

#include <exec/types.h>

/* Układ ekranu PAL 320×256: pasek HUD, arena, pasek HUD. */
#define HW_ROW_BYTES 42                     /* 336 px: 8 px marginesu z obu stron */
#define HW_STRIDE (HW_ROW_BYTES * 4)        /* przeplatane 4 bitplany */
#define HW_ARENA_ROWS 216                   /* 200 widocznych + 2×8 marginesu */
#define HW_ARENA_VISIBLE 200
#define HW_HUD_TOP_ROWS 30
#define HW_HUD_BOTTOM_ROWS 22
#define HW_ARENA_LINE 32                    /* pierwsza linia areny na ekranie */
#define HW_BOTTOM_LINE 234                  /* pierwsza linia dolnego paska */
#define HW_MENU_ROWS 256
#define HW_MENU_STRIDE (HW_ROW_BYTES * 3)   /* menu: 3 bitplany */

#define HW_ARENA_BYTES (HW_STRIDE * HW_ARENA_ROWS)
#define HW_HUD_TOP_BYTES (HW_STRIDE * HW_HUD_TOP_ROWS)
#define HW_HUD_BOTTOM_BYTES (HW_STRIDE * HW_HUD_BOTTOM_ROWS)
#define HW_MENU_BYTES (HW_MENU_STRIDE * HW_MENU_ROWS)

#define HW_SPRITE_PLAYER_WORDS (2 + 32 * 2 + 2)
#define HW_SPRITE_CROSS_WORDS (2 + 16 * 2 + 2)
#define HW_SPRITE_MUZZLE_WORDS (2 + 8 * 2 + 2)

typedef struct {
	UBYTE *arena;
	UBYTE *hud_top;
	UBYTE *hud_bottom;
	UWORD *copper;
	UWORD *sprite_player[4];
	UWORD *sprite_cross;
	UWORD *sprite_muzzle;
} HwBuffer;

typedef struct {
	UBYTE keys[128];
	UBYTE pressed[16];
	UBYTE pressed_count;
	BYTE mouse_dx;
	BYTE mouse_dy;
	UBYTE mouse_moved;
	UBYTE mouse_button;
	BYTE joy_x;
	BYTE joy_y;
	UBYTE joy_fire;
} HwInput;

typedef struct {
	volatile ULONG count;
	volatile ULONG pending;
	volatile ULONG current;
	ULONG *lof_list;
} HwVBlank;

extern HwBuffer hw_buffers[2];
extern UBYTE *hw_menu;
extern UWORD *hw_sprite_empty;
extern UBYTE *hw_asset_chip;
extern HwVBlank hw_vblank;

int hw_open(void);
void hw_close(void);
void hw_take_display(void);
void hw_release_display(void);
void hw_own_blitter(void);
void hw_disown_blitter(void);
void hw_read_input(HwInput *input);
int hw_key_pressed(const HwInput *input, UBYTE key);
void hw_flip(UWORD *copper);
void hw_wait_flip(void);
UWORD hw_raster_line(void);

/* Blitter: bufory przeplatane, `row_bytes` bajtów na wiersz planu, `depth` planów. */
void hw_blit_wait(void);
void hw_blit_copy(const UBYTE *src, UBYTE *dst, WORD x, WORD y, WORD w, WORD h);
void hw_blit_clear(UBYTE *dst, WORD row_bytes, WORD depth, WORD x, WORD y, WORD w, WORD h);
void hw_blit_bob(UBYTE *dst, const UWORD *gfx, const UWORD *mask, WORD x, WORD y, WORD words, WORD rows,
	WORD source_words);
void hw_blit_line(UBYTE *dst, WORD x0, WORD y0, WORD x1, WORD y1, UWORD color);

/* Szybkie blity inline (bufory przeplatane areny, 4 plany, HW_ROW_BYTES na wiersz planu). */
#define HW_CUSTOM_BASE ((volatile UWORD *)0xdff000)

static inline void hw_wait_inline(void) {
	volatile UWORD *dmaconr = (volatile UWORD *)0xdff002;
	(void)*dmaconr;
	while (*dmaconr & 0x4000) {
	}
}

/* Ustawia stałe rejestry dla serii kopii A→D (odtwarzanie tła). */
static inline void hw_copy_begin(void) {
	volatile UWORD *custom = HW_CUSTOM_BASE;
	hw_wait_inline();
	custom[0x040 / 2] = 0x09f0;
	custom[0x042 / 2] = 0;
	custom[0x044 / 2] = 0xffff;
	custom[0x046 / 2] = 0xffff;
}

static inline void hw_copy_rect(const UBYTE *src, UBYTE *dst, UWORD words, UWORD rows4) {
	volatile UWORD *custom = HW_CUSTOM_BASE;
	WORD modulo = HW_ROW_BYTES - (WORD)(words << 1);
	hw_wait_inline();
	*(volatile const UBYTE **)(custom + 0x050 / 2) = src;
	*(volatile UBYTE **)(custom + 0x054 / 2) = dst;
	custom[0x064 / 2] = (UWORD)modulo;
	custom[0x066 / 2] = (UWORD)modulo;
	custom[0x058 / 2] = (UWORD)((rows4 << 6) | words);
}

/* Bob z maską (cookie-cut): target wskazuje słowo docelowe, shift = x & 15. */
static inline void hw_bob_at(UBYTE *target, const UWORD *gfx, const UWORD *mask, UWORD shift,
	UWORD words, UWORD rows4, WORD source_words) {
	volatile UWORD *custom = HW_CUSTOM_BASE;
	UWORD width = shift ? words + 1 : words;
	WORD source_mod = (WORD)((source_words - words) << 1) - (shift ? 2 : 0);
	WORD dest_mod = HW_ROW_BYTES - (WORD)(width << 1);
	UWORD con1 = (UWORD)(shift << 12);
	hw_wait_inline();
	custom[0x040 / 2] = (UWORD)(con1 | 0x0fca);
	custom[0x042 / 2] = con1;
	custom[0x044 / 2] = 0xffff;
	custom[0x046 / 2] = shift ? 0x0000 : 0xffff;
	*(volatile const UWORD **)(custom + 0x050 / 2) = mask;
	*(volatile const UWORD **)(custom + 0x04c / 2) = gfx;
	*(volatile UBYTE **)(custom + 0x048 / 2) = target;
	*(volatile UBYTE **)(custom + 0x054 / 2) = target;
	custom[0x064 / 2] = (UWORD)source_mod;
	custom[0x062 / 2] = (UWORD)source_mod;
	custom[0x060 / 2] = (UWORD)dest_mod;
	custom[0x066 / 2] = (UWORD)dest_mod;
	custom[0x058 / 2] = (UWORD)((rows4 << 6) | width);
}

/* Lista Coppera. */
typedef struct {
	UWORD *start;
	UWORD *pos;
	UWORD line;
} CopperList;

void cop_begin(CopperList *list, UWORD *memory);
/* cop_move/cop_pointer/cop_wait zwracają adres słowa wartości (do późniejszego łatania). */
UWORD *cop_move(CopperList *list, UWORD reg, UWORD value);
UWORD *cop_pointer(CopperList *list, UWORD reg, const void *address);
UWORD *cop_wait(CopperList *list, UWORD line);
void cop_set_pointer(UWORD *slot, const void *address);
void cop_end(CopperList *list);

/* Rejestry Custom (offsety). */
#define REG_DIWSTRT 0x08e
#define REG_DIWSTOP 0x090
#define REG_DDFSTRT 0x092
#define REG_DDFSTOP 0x094
#define REG_BPL1PTH 0x0e0
#define REG_BPLCON0 0x100
#define REG_BPLCON1 0x102
#define REG_BPLCON2 0x104
#define REG_BPL1MOD 0x108
#define REG_BPL2MOD 0x10a
#define REG_SPR0PTH 0x120
#define REG_COLOR00 0x180

#endif
