#include "hw.h"
#include "fastmath.h"
#include "assets_load.h"

#include <exec/interrupts.h>
#include <exec/memory.h>
#include <graphics/gfxbase.h>
#include <graphics/view.h>
#include <hardware/custom.h>
#include <hardware/dmabits.h>
#include <hardware/intbits.h>
#include <intuition/intuition.h>
#include <proto/exec.h>
#include <proto/graphics.h>
#include <proto/intuition.h>
#include <string.h>

#define HW_CUSTOM ((volatile struct Custom *)0xdff000)
#define CIAA_PRA (*(volatile UBYTE *)0xbfe001)

struct GfxBase *GfxBase;
struct IntuitionBase *IntuitionBase;

extern void vblank_server(void);

#define CHIP __attribute__((section(".bsschip"), aligned(8)))

static UBYTE chip_arena[2][HW_ARENA_BYTES] CHIP;
static UBYTE chip_hud_top[2][HW_HUD_TOP_BYTES] CHIP;
static UBYTE chip_hud_bottom[2][HW_HUD_BOTTOM_BYTES] CHIP;
static UBYTE chip_menu[HW_MENU_BYTES] CHIP;
static UWORD chip_copper[2][512] CHIP;
static UWORD chip_sprite_player[2][4][HW_SPRITE_PLAYER_WORDS] CHIP;
static UWORD chip_sprite_cross[2][HW_SPRITE_CROSS_WORDS] CHIP;
static UWORD chip_sprite_muzzle[2][HW_SPRITE_MUZZLE_WORDS] CHIP;
static UWORD chip_sprite_empty[4] CHIP;

HwBuffer hw_buffers[2];
UBYTE *hw_menu;
UWORD *hw_sprite_empty;
UBYTE *hw_asset_chip;
HwVBlank hw_vblank;

static struct Screen *screen;
static struct Window *window;
static struct View *old_view;
static struct Interrupt vblank_interrupt;
static UBYTE vblank_installed;
static UBYTE display_taken;
static UBYTE blitter_owned;
static UWORD last_joy0;

int hw_open(void) {
	struct NewScreen new_screen;
	struct NewWindow new_window;
	unsigned short index;
	unsigned short sprite;

	GfxBase = (struct GfxBase *)OpenLibrary((STRPTR)"graphics.library", 0);
	IntuitionBase = (struct IntuitionBase *)OpenLibrary((STRPTR)"intuition.library", 0);
	if (GfxBase == 0 || IntuitionBase == 0) {
		hw_close();
		return 0;
	}
	for (index = 0; index < 2; ++index) {
		HwBuffer *buffer = &hw_buffers[index];
		buffer->arena = chip_arena[index];
		buffer->hud_top = chip_hud_top[index];
		buffer->hud_bottom = chip_hud_bottom[index];
		buffer->copper = chip_copper[index];
		for (sprite = 0; sprite < 4; ++sprite) {
			buffer->sprite_player[sprite] = chip_sprite_player[index][sprite];
		}
		buffer->sprite_cross = chip_sprite_cross[index];
		buffer->sprite_muzzle = chip_sprite_muzzle[index];
	}
	hw_menu = chip_menu;
	hw_sprite_empty = chip_sprite_empty;
	hw_asset_chip = asset_chip_data;

	memset(&new_screen, 0, sizeof(new_screen));
	new_screen.Width = 320;
	new_screen.Height = 200;
	new_screen.Depth = 1;
	new_screen.DetailPen = 0;
	new_screen.BlockPen = 1;
	new_screen.Type = CUSTOMSCREEN | SCREENQUIET;
	new_screen.DefaultTitle = (UBYTE *)"PHOBOS";
	screen = OpenScreen(&new_screen);
	if (screen == 0) {
		hw_close();
		return 0;
	}
	memset(&new_window, 0, sizeof(new_window));
	new_window.Width = 320;
	new_window.Height = 200;
	new_window.IDCMPFlags = IDCMP_RAWKEY;
	new_window.Flags = WFLG_BORDERLESS | WFLG_BACKDROP | WFLG_ACTIVATE | WFLG_RMBTRAP;
	new_window.Screen = screen;
	new_window.Type = CUSTOMSCREEN;
	window = OpenWindow(&new_window);
	if (window == 0) {
		hw_close();
		return 0;
	}

	memset(&hw_vblank, 0, sizeof(hw_vblank));
	hw_vblank.lof_list = (ULONG *)&GfxBase->LOFlist;
	memset(&vblank_interrupt, 0, sizeof(vblank_interrupt));
	vblank_interrupt.is_Node.ln_Type = NT_INTERRUPT;
	vblank_interrupt.is_Node.ln_Pri = 20;
	vblank_interrupt.is_Node.ln_Name = (char *)"PHOBOS VBlank";
	vblank_interrupt.is_Data = (APTR)&hw_vblank;
	vblank_interrupt.is_Code = vblank_server;
	AddIntServer(INTB_VERTB, &vblank_interrupt);
	vblank_installed = 1;
	last_joy0 = HW_CUSTOM->joy0dat;
	return 1;
}

void hw_close(void) {
	hw_release_display();
	hw_disown_blitter();
	if (vblank_installed) {
		RemIntServer(INTB_VERTB, &vblank_interrupt);
		vblank_installed = 0;
	}
	if (window != 0) {
		struct IntuiMessage *message;
		while ((message = (struct IntuiMessage *)GetMsg(window->UserPort)) != 0) {
			ReplyMsg((struct Message *)message);
		}
		CloseWindow(window);
		window = 0;
	}
	if (screen != 0) {
		CloseScreen(screen);
		screen = 0;
	}
	if (IntuitionBase != 0) {
		CloseLibrary((struct Library *)IntuitionBase);
		IntuitionBase = 0;
	}
	if (GfxBase != 0) {
		CloseLibrary((struct Library *)GfxBase);
		GfxBase = 0;
	}
}

void hw_take_display(void) {
	if (display_taken) {
		return;
	}
	old_view = GfxBase->ActiView;
	LoadView(0);
	WaitTOF();
	WaitTOF();
	HW_CUSTOM->dmacon = DMAF_SETCLR | DMAF_MASTER | DMAF_RASTER | DMAF_COPPER | DMAF_SPRITE | DMAF_BLITTER;
	display_taken = 1;
}

void hw_release_display(void) {
	if (!display_taken) {
		return;
	}
	Disable();
	hw_vblank.pending = 0;
	hw_vblank.current = 0;
	Enable();
	LoadView(old_view);
	WaitTOF();
	WaitTOF();
	HW_CUSTOM->cop1lc = (ULONG)GfxBase->copinit;
	RethinkDisplay();
	display_taken = 0;
}

void hw_own_blitter(void) {
	if (!blitter_owned) {
		OwnBlitter();
		WaitBlit();
		blitter_owned = 1;
	}
}

void hw_disown_blitter(void) {
	if (blitter_owned) {
		hw_blit_wait();
		DisownBlitter();
		blitter_owned = 0;
	}
}

void hw_flip(UWORD *copper) {
	hw_vblank.pending = (ULONG)copper;
}

void hw_wait_flip(void) {
	while (hw_vblank.pending != 0) {
		WaitTOF();
	}
}

UWORD hw_raster_line(void) {
	ULONG position = *(volatile ULONG *)0xdff004;
	return (UWORD)((position >> 8) & 0x1ff);
}

void hw_read_input(HwInput *input) {
	struct IntuiMessage *message;
	UWORD joy0;
	UWORD joy1;
	UBYTE cia;
	input->pressed_count = 0;
	while ((message = (struct IntuiMessage *)GetMsg(window->UserPort)) != 0) {
		if (message->Class == IDCMP_RAWKEY) {
			UBYTE key = message->Code & 0x7f;
			if (message->Code & 0x80) {
				input->keys[key] = 0;
			} else {
				if (!input->keys[key] && input->pressed_count < sizeof(input->pressed)) {
					input->pressed[input->pressed_count++] = key;
				}
				input->keys[key] = 1;
			}
		}
		ReplyMsg((struct Message *)message);
	}
	joy0 = HW_CUSTOM->joy0dat;
	input->mouse_dx = (BYTE)((joy0 & 0xff) - (last_joy0 & 0xff));
	input->mouse_dy = (BYTE)((joy0 >> 8) - (last_joy0 >> 8));
	input->mouse_moved = input->mouse_dx != 0 || input->mouse_dy != 0;
	last_joy0 = joy0;
	joy1 = HW_CUSTOM->joy1dat;
	input->joy_x = ((joy1 & 0x0002) ? 1 : 0) - ((joy1 & 0x0200) ? 1 : 0);
	input->joy_y = (((joy1 >> 1) ^ joy1) & 0x0001 ? 1 : 0) - (((joy1 >> 1) ^ joy1) & 0x0100 ? 1 : 0);
	cia = CIAA_PRA;
	input->mouse_button = (cia & 0x40) == 0;
	input->joy_fire = (cia & 0x80) == 0;
}

int hw_key_pressed(const HwInput *input, UBYTE key) {
	UBYTE index;
	for (index = 0; index < input->pressed_count; ++index) {
		if (input->pressed[index] == key) {
			return 1;
		}
	}
	return 0;
}

/* ------------------------------------------------------------------ blitter */

void hw_blit_wait(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	(void)custom->dmaconr;
	while (custom->dmaconr & DMAF_BLTDONE) {
	}
}

void hw_blit_copy(const UBYTE *src, UBYTE *dst, WORD x, WORD y, WORD w, WORD h) {
	volatile struct Custom *custom = HW_CUSTOM;
	WORD first;
	WORD words;
	LONG offset;
	if (x < 0) {
		w += x;
		x = 0;
	}
	if (y < 0) {
		h += y;
		y = 0;
	}
	if (x + w > HW_ROW_BYTES * 8) {
		w = HW_ROW_BYTES * 8 - x;
	}
	if (y + h > HW_ARENA_ROWS) {
		h = HW_ARENA_ROWS - y;
	}
	if (w <= 0 || h <= 0) {
		return;
	}
	first = x >> 4;
	words = ((x + w - 1) >> 4) - first + 1;
	offset = muls16(y, HW_STRIDE) + first * 2;
	hw_blit_wait();
	custom->bltcon0 = 0x09f0;
	custom->bltcon1 = 0;
	custom->bltafwm = 0xffff;
	custom->bltalwm = 0xffff;
	custom->bltapt = (APTR)(src + offset);
	custom->bltdpt = (APTR)(dst + offset);
	custom->bltamod = HW_ROW_BYTES - words * 2;
	custom->bltdmod = HW_ROW_BYTES - words * 2;
	custom->bltsize = (UWORD)(((h * 4) << 6) | words);
}

void hw_blit_clear(UBYTE *dst, WORD row_bytes, WORD depth, WORD x, WORD y, WORD w, WORD h) {
	volatile struct Custom *custom = HW_CUSTOM;
	WORD first = x >> 4;
	WORD words = ((x + w - 1) >> 4) - first + 1;
	hw_blit_wait();
	custom->bltcon0 = 0x0100;
	custom->bltcon1 = 0;
	custom->bltdpt = (APTR)(dst + muls16(y, (short)(row_bytes * depth)) + first * 2);
	custom->bltdmod = row_bytes - words * 2;
	custom->bltsize = (UWORD)(((h * depth) << 6) | words);
}

void hw_blit_bob(UBYTE *dst, const UWORD *gfx, const UWORD *mask, WORD x, WORD y, WORD words, WORD rows,
	WORD source_words) {
	volatile struct Custom *custom = HW_CUSTOM;
	UWORD shift = x & 15;
	WORD width = shift ? words + 1 : words;
	WORD source_mod = (source_words - words) * 2 - (shift ? 2 : 0);
	UBYTE *target = dst + muls16(y, HW_STRIDE) + (x >> 4) * 2;
	hw_blit_wait();
	custom->bltcon0 = (UWORD)((shift << 12) | 0x0fca);
	custom->bltcon1 = (UWORD)(shift << 12);
	custom->bltafwm = 0xffff;
	custom->bltalwm = shift ? 0x0000 : 0xffff;
	custom->bltapt = (APTR)mask;
	custom->bltbpt = (APTR)gfx;
	custom->bltcpt = (APTR)target;
	custom->bltdpt = (APTR)target;
	custom->bltamod = source_mod;
	custom->bltbmod = source_mod;
	custom->bltcmod = HW_ROW_BYTES - width * 2;
	custom->bltdmod = HW_ROW_BYTES - width * 2;
	custom->bltsize = (UWORD)(((rows * 4) << 6) | width);
}

void hw_blit_line(UBYTE *dst, WORD x0, WORD y0, WORD x1, WORD y1, UWORD color) {
	volatile struct Custom *custom = HW_CUSTOM;
	WORD dx = x1 - x0;
	WORD dy = y1 - y0;
	WORD adx = dx < 0 ? -dx : dx;
	WORD ady = dy < 0 ? -dy : dy;
	WORD dl;
	WORD ds;
	UWORD code;
	WORD error;
	UWORD plane;
	UBYTE *start = dst + muls16(y0, HW_STRIDE) + (x0 >> 4) * 2;
	if (adx >= ady) {
		dl = adx;
		ds = ady;
		code = 0x0010 | (dx < 0 ? 0x0004 : 0) | (dy < 0 ? 0x0008 : 0);
	} else {
		dl = ady;
		ds = adx;
		code = (dy < 0 ? 0x0004 : 0) | (dx < 0 ? 0x0008 : 0);
	}
	error = 4 * ds - 2 * dl;
	if (error < 0) {
		code |= 0x0040;
	}
	for (plane = 0; plane < 4; ++plane) {
		hw_blit_wait();
		custom->bltcon0 = (UWORD)(((x0 & 15) << 12) | 0x0bca);
		custom->bltcon1 = (UWORD)(code | 0x0001);
		custom->bltafwm = 0xffff;
		custom->bltalwm = 0xffff;
		custom->bltadat = 0x8000;
		custom->bltbdat = (color & (1 << plane)) ? 0xffff : 0x0000;
		custom->bltamod = 4 * (ds - dl);
		custom->bltbmod = 4 * ds;
		custom->bltcmod = HW_STRIDE;
		custom->bltdmod = HW_STRIDE;
		custom->bltapt = (APTR)(LONG)error;
		custom->bltcpt = (APTR)(start + plane * HW_ROW_BYTES);
		custom->bltdpt = (APTR)(start + plane * HW_ROW_BYTES);
		custom->bltsize = (UWORD)(((dl + 1) << 6) | 2);
	}
}

/* ------------------------------------------------------------------ copper */

void cop_begin(CopperList *list, UWORD *memory) {
	list->start = memory;
	list->pos = memory;
	list->line = 0;
}

UWORD *cop_move(CopperList *list, UWORD reg, UWORD value) {
	*list->pos++ = reg;
	*list->pos++ = value;
	return list->pos - 1;
}

UWORD *cop_pointer(CopperList *list, UWORD reg, const void *address) {
	ULONG value = (ULONG)address;
	UWORD *slot = cop_move(list, reg, (UWORD)(value >> 16));
	cop_move(list, reg + 2, (UWORD)value);
	return slot;
}

void cop_set_pointer(UWORD *slot, const void *address) {
	ULONG value = (ULONG)address;
	slot[0] = (UWORD)(value >> 16);
	slot[2] = (UWORD)value;
}

UWORD *cop_wait(CopperList *list, UWORD line) {
	if (line >= 256 && list->line < 256) {
		*list->pos++ = 0xffdf;
		*list->pos++ = 0xfffe;
	}
	*list->pos++ = (UWORD)(((line & 0xff) << 8) | 0x07);
	*list->pos++ = 0xfffe;
	list->line = line;
	return list->pos - 2;
}

void cop_end(CopperList *list) {
	*list->pos++ = 0xffff;
	*list->pos++ = 0xfffe;
}
