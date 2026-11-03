#include "render.h"
#include "fastmath.h"
#include "text.h"
#include "../assets/generated/assets.h"

#include <string.h>

/* Bufor areny: 336×216, środek świata w (168, 108); widoczne wiersze 8..207. */
#define ARENA_CX 168
#define ARENA_CY 108
#define ARENA_TOP 8
#define DISPLAY_TOP 0x2c
#define ARENA_FIRST_LINE (DISPLAY_TOP + HW_ARENA_LINE)
#define RECTS_MAX 160
#define BANNER_WORDS 20
#define BANNER_ROWS 44
#define BANNER_COLOR 15
#define TRACER_SEGMENT 32
#define BAR_WIDTH 84

/* Prostokąt do odtworzenia: offset bajtowy w buforze areny, szerokość w słowach, wiersze×4. */
typedef struct {
	ULONG offset;
	UWORD words;
	UWORD rows4;
} Rect;

/* Adresy słów wartości w liście Coppera, łatane w każdej klatce. */
typedef struct {
	UWORD *sprites[8];
	UWORD *hud_colors;
	UWORD *sprite_colors;
	UWORD *arena_colors;
	UWORD *arena_planes;
	UWORD *arena_scroll;
	UWORD *band;
	UWORD *bottom_colors;
	UWORD palette_version;
	UBYTE valid;
} CopperSlots;

typedef struct {
	Rect dirty[RECTS_MAX];
	UWORD dirty_count;
	UBYTE arena_valid;
	WORD player_frame;
	CopperSlots copper;
} BufferState;

typedef struct {
	UBYTE valid;
	const char *difficulty;
	UWORD wave;
	UWORD wave_second;
	UBYTE wave_mode;
	ULONG score;
	UWORD kills;
	UWORD fps;
	WORD hp;
	WORD od;
	WORD kills_x;
	WORD fps_x;
} HudState;

typedef struct {
	WORD flash;
	WORD danger;
	UBYTE overdrive;
	UBYTE paused;
} PaletteKey;

static BufferState states[2];
static HudState hud;
static PaletteKey palette_key;
static UBYTE palette_valid;
static UWORD palette_version = 1;
static UWORD palette_arena[16];
static UWORD palette_hud[16];
static UWORD palette_sprites[16];
static UWORD banner_gfx[BANNER_WORDS * BANNER_ROWS * 4] __attribute__((section(".bsschip"), aligned(8)));
static UWORD banner_mask[BANNER_WORDS * BANNER_ROWS * 4] __attribute__((section(".bsschip"), aligned(8)));
static char banner_text[48];
static UBYTE banner_paused;
static WORD banner_width;
static WORD banner_height;
static UWORD render_rng = 0x1234;

ULONG render_profile[8];
static ULONG beam(void) {
	return mulu16((UWORD)hw_vblank.count, 313) + hw_raster_line();
}

#define PROFILE(n) do { ULONG now_ = beam(); render_profile[n] += now_ - profile_mark; profile_mark = now_; } while (0)

/* ------------------------------------------------------------------ współrzędne */

WORD render_world_to_screen_x(long x) {
	return (WORD)(ARENA_CX - 8 + (x >> 7));
}

WORD render_world_to_screen_y(long y) {
	return (WORD)(ARENA_CY - ARENA_TOP + HW_ARENA_LINE + (y >> 7));
}

long render_screen_to_world_x(WORD x) {
	return (long)(x - (ARENA_CX - 8)) << 7;
}

long render_screen_to_world_y(WORD y) {
	return (long)(y - (ARENA_CY - ARENA_TOP + HW_ARENA_LINE)) << 7;
}

static WORD buffer_x(long x) {
	return (WORD)(ARENA_CX + (x >> 7));
}

static WORD buffer_y(long y) {
	return (WORD)(ARENA_CY + (y >> 7));
}

static UWORD next_random(void) {
	render_rng = (UWORD)(render_rng * 25173U + 13849U);
	return render_rng;
}

/* ------------------------------------------------------------------ paleta */

static UWORD blend(UWORD color, WORD r, WORD g, WORD b, WORD alpha) {
	WORD cr = (color >> 8) & 15;
	WORD cg = (color >> 4) & 15;
	WORD cb = color & 15;
	cr += (WORD)((muls16((short)(r - cr), alpha) + 128) >> 8);
	cg += (WORD)((muls16((short)(g - cg), alpha) + 128) >> 8);
	cb += (WORD)((muls16((short)(b - cb), alpha) + 128) >> 8);
	return (UWORD)((cr << 8) | (cg << 4) | cb);
}

static UWORD dim(UWORD color) {
	/* Pauza: czarna nakładka 60% (ColorRect alpha 0,6). */
	WORD r = (WORD)((((color >> 8) & 15) * 102) >> 8);
	WORD g = (WORD)((((color >> 4) & 15) * 102) >> 8);
	WORD b = (WORD)(((color & 15) * 102) >> 8);
	return (UWORD)((r << 8) | (g << 4) | b);
}

static UWORD apply_fx(UWORD color, const PaletteKey *fx, UBYTE dark) {
	if (fx->overdrive && dark) {
		color = blend(color, 2, 4, 9, 40);
	}
	if (fx->danger && dark) {
		color = blend(color, 9, 1, 1, fx->danger);
	}
	if (fx->flash) {
		color = blend(color, 15, 1, 1, fx->flash);
	}
	if (fx->paused) {
		color = dim(color);
	}
	return color;
}

static void update_palettes(const PaletteKey *key) {
	WORD index;
	if (palette_valid && memcmp(key, &palette_key, sizeof(*key)) == 0) {
		return;
	}
	palette_key = *key;
	palette_valid = 1;
	if (++palette_version == 0) {
		palette_version = 1;
	}
	for (index = 0; index < 16; ++index) {
		UWORD sprite = asset_sprite_palette[index];
		palette_arena[index] = apply_fx(asset_arena_palette[index], key, index <= 5);
		palette_hud[index] = apply_fx(asset_hud_palette[index], key, index == 0);
		if (key->overdrive && index != 9 && index != 10 && index != 11) {
			sprite = blend(sprite, 3, 14, 15, 70);
		}
		palette_sprites[index] = apply_fx(sprite, key, 0);
	}
}

/* ------------------------------------------------------------------ brudne prostokąty i boby */

static void add_dirty(BufferState *state, WORD x, WORD y, WORD w, WORD h) {
	Rect *rect;
	WORD first;
	if (state->dirty_count >= RECTS_MAX) {
		return;
	}
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
	rect = &state->dirty[state->dirty_count++];
	rect->offset = (ULONG)muls16(y, HW_STRIDE) + (first << 1);
	rect->words = (UWORD)(((x + w - 1) >> 4) - first + 1);
	rect->rows4 = (UWORD)(h << 2);
}

/* Bob 16×16 (lub 32×32): x, y muszą mieścić się w buforze. */
static void draw_bob(BufferState *state, UBYTE *arena, ULONG offset, WORD x, WORD y, UWORD size) {
	const UWORD *gfx = (const UWORD *)(hw_asset_chip + offset);
	UWORD words = size >> 4;
	ULONG target;
	UWORD shift;
	Rect *rect;
	if (x < 0) {
		x = 0;
	} else if (x > HW_ROW_BYTES * 8 - (WORD)size) {
		x = HW_ROW_BYTES * 8 - (WORD)size;
	}
	if (y < 0) {
		y = 0;
	} else if (y > HW_ARENA_ROWS - (WORD)size) {
		y = HW_ARENA_ROWS - (WORD)size;
	}
	shift = (UWORD)(x & 15);
	target = (ULONG)muls16(y, HW_STRIDE) + ((x >> 4) << 1);
	hw_bob_at(arena + target, gfx, gfx + (size == 16 ? 64 : 256), shift, words, (UWORD)(size << 2), (WORD)words);
	if (state->dirty_count < RECTS_MAX) {
		rect = &state->dirty[state->dirty_count++];
		rect->offset = target;
		rect->words = shift ? words + 1 : words;
		rect->rows4 = (UWORD)(size << 2);
	}
}

#define draw_bob16(state, arena, offset, x, y) draw_bob(state, arena, offset, x, y, 16)
#define draw_bob32(state, arena, offset, x, y) draw_bob(state, arena, offset, x, y, 32)

static void draw_tracer(BufferState *state, UBYTE *arena, const GameTracer *tracer) {
	WORD x0 = buffer_x(tracer->x0);
	WORD y0 = buffer_y(tracer->y0);
	WORD x1 = buffer_x(tracer->x1);
	WORD y1 = buffer_y(tracer->y1);
	WORD dx = x1 - x0;
	WORD dy = y1 - y0;
	WORD adx = dx < 0 ? -dx : dx;
	WORD ady = dy < 0 ? -dy : dy;
	WORD major = adx > ady ? adx : ady;
	WORD pieces = (major + TRACER_SEGMENT - 1) / TRACER_SEGMENT;
	WORD piece;
	WORD ax = x0;
	WORD ay = y0;
	if (x0 < 1 || x0 > 334 || x1 < 1 || x1 > 334 || y0 < 1 || y0 > 214 || y1 < 1 || y1 > 214) {
		return;
	}
	hw_blit_line(arena, x0, y0, x1, y1, tracer->age < 2 ? 15 : 14);
	if (pieces < 1) {
		pieces = 1;
	}
	for (piece = 1; piece <= pieces; ++piece) {
		WORD bx = x0 + divs16(muls16(dx, piece), pieces);
		WORD by = y0 + divs16(muls16(dy, piece), pieces);
		WORD left = ax < bx ? ax : bx;
		WORD top = ay < by ? ay : by;
		WORD w = (ax < bx ? bx - ax : ax - bx) + 3;
		WORD h = (ay < by ? by - ay : ay - by) + 3;
		add_dirty(state, left - 1, top - 1, w, h);
		ax = bx;
		ay = by;
	}
}

/* ------------------------------------------------------------------ baner */

static void prepare_banner(const char *text, UBYTE paused) {
	Canvas gfx = {(UBYTE *)banner_gfx, BANNER_WORDS * 2, 4, BANNER_ROWS};
	Canvas mask = {(UBYTE *)banner_mask, BANNER_WORDS * 2, 4, BANNER_ROWS};
	hw_blit_clear((UBYTE *)banner_gfx, BANNER_WORDS * 2, 4, 0, 0, BANNER_WORDS * 16, BANNER_ROWS);
	hw_blit_clear((UBYTE *)banner_mask, BANNER_WORDS * 2, 4, 0, 0, BANNER_WORDS * 16, BANNER_ROWS);
	hw_blit_wait();
	if (paused) {
		WORD a = text_width(&asset_font_xl, "PAUZA");
		WORD b = text_width(&asset_font_l, "ESC — wznów");
		banner_width = (a > b ? a : b) + 4;
		text_draw_shadowed(&gfx, &asset_font_xl, banner_width / 2, 1, "PAUZA", BANNER_COLOR, 0, TEXT_CENTER);
		text_draw_shadowed(&mask, &asset_font_xl, banner_width / 2, 1, "PAUZA", 15, 15, TEXT_CENTER);
		text_draw_shadowed(&gfx, &asset_font_l, banner_width / 2, 26, "ESC — wznów", BANNER_COLOR, 0, TEXT_CENTER);
		text_draw_shadowed(&mask, &asset_font_l, banner_width / 2, 26, "ESC — wznów", 15, 15, TEXT_CENTER);
		banner_height = 26 + asset_font_l.height + 2;
	} else {
		banner_width = text_width(&asset_font_xl, text) + 4;
		if (banner_width > BANNER_WORDS * 16 - 2) {
			banner_width = BANNER_WORDS * 16 - 2;
		}
		text_draw_shadowed(&gfx, &asset_font_xl, 2, 1, text, BANNER_COLOR, 0, TEXT_LEFT);
		text_draw_shadowed(&mask, &asset_font_xl, 2, 1, text, 15, 15, TEXT_LEFT);
		banner_height = asset_font_xl.height + 3;
	}
	strcpy(banner_text, text);
	banner_paused = paused;
}

static WORD draw_banner(BufferState *state, UBYTE *arena, WORD center_y) {
	WORD words = (banner_width + 15) >> 4;
	WORD x = ARENA_CX - (banner_width >> 1);
	WORD y = center_y - (banner_height >> 1);
	hw_bob_at(arena + muls16(y, HW_STRIDE) + ((x >> 4) << 1), banner_gfx, banner_mask, (UWORD)(x & 15),
		(UWORD)words, (UWORD)(banner_height << 2), BANNER_WORDS);
	add_dirty(state, x, y, words * 16 + 16, banner_height);
	return y;
}

/* ------------------------------------------------------------------ HUD (jeden bufor dla obu list Coppera) */

static void hud_number(const Canvas *canvas, WORD x, WORD y, ULONG value, UWORD color) {
	char text[12];
	str_number(text, value, 1);
	text_draw(canvas, &asset_font_s, x, y, text, color);
}

static void draw_hud(const GameState *game, const RenderView *view) {
	UBYTE *top = hw_buffers[0].hud_top;
	UBYTE *bottom = hw_buffers[0].hud_bottom;
	Canvas top_canvas = {top, HW_ROW_BYTES, 4, HW_HUD_TOP_ROWS};
	Canvas bottom_canvas = {bottom, HW_ROW_BYTES, 4, HW_HUD_BOTTOM_ROWS};
	UBYTE full = !hud.valid;
	UBYTE wave_mode = game->wave == 0 ? 0 : (game->state == GAME_STATE_WAVE && game->wave_frames > 0 ? 1 : 2);
	UWORD wave_second = wave_mode == 1 ? game->wave_second : 0;
	WORD hp = (WORD)divu16(mulu16(BAR_WIDTH - 4, (UWORD)game->hp), GAME_HP_MAX);
	WORD od = game->overdrive > 0 ? (WORD)divu16(mulu16(BAR_WIDTH - 2, game->overdrive), GAME_OVERDRIVE_FRAMES) : -1;

	if (full) {
		hw_blit_clear(top, HW_ROW_BYTES, 4, 0, 0, HW_ROW_BYTES * 8, HW_HUD_TOP_ROWS);
		hw_blit_clear(bottom, HW_ROW_BYTES, 4, 0, 0, HW_ROW_BYTES * 8, HW_HUD_BOTTOM_ROWS);
		hw_blit_wait();
		text_draw(&top_canvas, &asset_font_s, 256, 4, "Zabicia:", 2);
		text_draw(&top_canvas, &asset_font_s, 256, 15, "FPS:", 3);
		hud.kills_x = 256 + text_width(&asset_font_s, "Zabicia: ");
		hud.fps_x = 256 + text_width(&asset_font_s, "FPS: ");
	}
	if (full || hud.difficulty != view->difficulty) {
		hw_blit_clear(top, HW_ROW_BYTES, 4, 0, 0, 80, HW_HUD_TOP_ROWS);
		hw_blit_wait();
		text_draw(&top_canvas, &asset_font_s, 14, 4, "POZIOM:", 3);
		text_draw(&top_canvas, &asset_font_s, 14, 15, view->difficulty, 2);
		hud.difficulty = view->difficulty;
	}
	if (full || hud.wave != game->wave || hud.wave_mode != wave_mode || hud.wave_second != wave_second) {
		char text[48];
		char *out;
		const AssetFont *font = &asset_font_l;
		text[0] = 0;
		if (wave_mode) {
			out = str_append(text, "FALA ");
			out = str_number(out, game->wave, 1);
			if (wave_mode == 1) {
				out = str_append(out, "  ·  ");
				out = str_number(out, wave_second, 2);
				str_append(out, " s");
			} else {
				str_append(out, "  ·  OCZYŚĆ ARENĘ");
			}
		}
		if (text_width(font, text) > 176) {
			font = &asset_font_s;
		}
		hw_blit_clear(top, HW_ROW_BYTES, 4, 80, 0, 176, 18);
		hw_blit_wait();
		text_draw_aligned(&top_canvas, font, ARENA_CX, font == &asset_font_l ? 0 : 3, text, 1, TEXT_CENTER);
		hud.wave = game->wave;
		hud.wave_mode = wave_mode;
		hud.wave_second = wave_second;
	}
	{
		/* Liczby (wynik, zabicia, FPS) odświeżane najwyżej po jednej na klatkę. */
		UBYTE score_dirty = hud.score != game->score;
		UBYTE kills_dirty = hud.kills != game->kills;
		UBYTE fps_dirty = hud.fps != view->fps;
		if (!full) {
			if (score_dirty) {
				kills_dirty = 0;
				fps_dirty = 0;
			} else if (kills_dirty) {
				fps_dirty = 0;
			}
		}
	if (full || score_dirty) {
		char text[12];
		str_number(text, game->score, 1);
		hw_blit_clear(top, HW_ROW_BYTES, 4, 80, 18, 176, HW_HUD_TOP_ROWS - 18);
		hw_blit_wait();
		text_draw_aligned(&top_canvas, &asset_font_s, ARENA_CX, 19, text, 1, TEXT_CENTER);
		hud.score = game->score;
	}
	if (full || kills_dirty) {
		hw_blit_wait();
		canvas_fill(&top_canvas, hud.kills_x, 4, 336 - hud.kills_x, asset_font_s.height, 0);
		hud_number(&top_canvas, hud.kills_x, 4, game->kills, 2);
		hud.kills = game->kills;
	}
	if (full || fps_dirty) {
		hw_blit_wait();
		canvas_fill(&top_canvas, hud.fps_x, 15, 336 - hud.fps_x, asset_font_s.height, 0);
		hud_number(&top_canvas, hud.fps_x, 15, view->fps, 3);
		hud.fps = view->fps;
	}
	}
	if (full || hud.hp != hp) {
		WORD x = 8 + 8;
		WORD y = 9;
		hw_blit_wait();
		canvas_fill(&bottom_canvas, x, y, BAR_WIDTH, 7, 7);
		canvas_fill(&bottom_canvas, x + 1, y + 1, BAR_WIDTH - 2, 5, 6);
		canvas_fill(&bottom_canvas, x + 2, y + 2, hp, 3, 4);
		hud.hp = hp;
	}
	if (full || hud.od != od) {
		WORD x = 8 + 320 - 8 - BAR_WIDTH;
		WORD y = 11;
		hw_blit_wait();
		if (od < 0) {
			canvas_fill(&bottom_canvas, x, y, BAR_WIDTH, 5, 0);
		} else if (hud.od < 0 || full) {
			canvas_fill(&bottom_canvas, x, y, BAR_WIDTH, 5, 7);
			canvas_fill(&bottom_canvas, x + 1, y + 1, BAR_WIDTH - 2, 3, 6);
			canvas_fill(&bottom_canvas, x + 1, y + 1, od, 3, 5);
		} else if (od < hud.od) {
			canvas_fill(&bottom_canvas, x + 1 + od, y + 1, hud.od - od, 3, 6);
		} else {
			canvas_fill(&bottom_canvas, x + 1, y + 1, od, 3, 5);
		}
		hud.od = od;
	}
	hud.valid = 1;
}

/* ------------------------------------------------------------------ sprite'y */

static void sprite_header(UWORD *sprite, WORD x, WORD y, WORD height, UBYTE attach) {
	WORD hstart = x + 128;
	WORD vstart = y + DISPLAY_TOP;
	WORD vstop = vstart + height;
	sprite[0] = (UWORD)(((vstart & 0xff) << 8) | ((hstart >> 1) & 0xff));
	sprite[1] = (UWORD)(((vstop & 0xff) << 8) | (attach ? 0x80 : 0) | ((vstart >> 8) & 1) << 2 |
		((vstop >> 8) & 1) << 1 | (hstart & 1));
}

static void init_sprites(HwBuffer *buffer) {
	const UWORD *cross = (const UWORD *)(hw_asset_chip + ASSET_CROSSHAIR);
	const UWORD *muzzle = (const UWORD *)(hw_asset_chip + ASSET_MUZZLE);
	WORD index;
	for (index = 0; index < 32; ++index) {
		buffer->sprite_cross[2 + index] = cross[index];
	}
	buffer->sprite_cross[34] = 0;
	buffer->sprite_cross[35] = 0;
	for (index = 0; index < 16; ++index) {
		buffer->sprite_muzzle[2 + index] = muzzle[index];
	}
	buffer->sprite_muzzle[18] = 0;
	buffer->sprite_muzzle[19] = 0;
	for (index = 0; index < 4; ++index) {
		buffer->sprite_player[index][66] = 0;
		buffer->sprite_player[index][67] = 0;
	}
}

static void update_player_sprites(BufferState *state, HwBuffer *buffer, const GameState *game, WORD sx, WORD sy) {
	WORD direction = ((game->aim + 32) >> 6) & 15;
	WORD anim = game->moving ? (WORD)((mulu16(game->anim, 41) >> 8) & 3) : 0;
	WORD frame = direction * 4 + anim;
	WORD sprite;
	if (frame != state->player_frame) {
		const ULONG *source = (const ULONG *)(hw_asset_chip + ASSET_PLAYER + mulu16((UWORD)frame, ASSET_PLAYER_FRAME_SIZE));
		for (sprite = 0; sprite < 4; ++sprite) {
			ULONG *target = (ULONG *)(buffer->sprite_player[sprite] + 2);
			WORD row;
			for (row = 0; row < 32; ++row) {
				*target++ = *source++;
			}
		}
		state->player_frame = frame;
	}
	sprite_header(buffer->sprite_player[0], sx - 16, sy - 16, 32, 0);
	sprite_header(buffer->sprite_player[1], sx - 16, sy - 16, 32, 1);
	sprite_header(buffer->sprite_player[2], sx, sy - 16, 32, 0);
	sprite_header(buffer->sprite_player[3], sx, sy - 16, 32, 1);
}

/* ------------------------------------------------------------------ copper */

static void copper_sprites(CopperList *list, UWORD **slots) {
	WORD index;
	for (index = 0; index < 8; ++index) {
		UWORD *slot = cop_pointer(list, REG_SPR0PTH + index * 4, hw_sprite_empty);
		if (slots) {
			slots[index] = slot;
		}
	}
}

static UWORD *copper_planes(CopperList *list, const UBYTE *base, WORD depth, WORD row_bytes) {
	WORD plane;
	UWORD *first = 0;
	for (plane = 0; plane < depth; ++plane) {
		UWORD *slot = cop_pointer(list, REG_BPL1PTH + plane * 4, base + plane * row_bytes);
		if (plane == 0) {
			first = slot;
		}
	}
	return first;
}

static UWORD *copper_palette(CopperList *list, WORD first, const UWORD *colors, WORD count) {
	WORD index;
	UWORD *slot = 0;
	for (index = 0; index < count; ++index) {
		UWORD *value = cop_move(list, REG_COLOR00 + (first + index) * 2, colors[index]);
		if (index == 0) {
			slot = value;
		}
	}
	return slot;
}

static void copper_display(CopperList *list, UWORD modulo) {
	cop_move(list, REG_DIWSTRT, 0x2c81);
	cop_move(list, REG_DIWSTOP, 0x2cc1);
	cop_move(list, REG_DDFSTRT, 0x0030);
	cop_move(list, REG_DDFSTOP, 0x00d0);
	cop_move(list, REG_BPL1MOD, modulo);
	cop_move(list, REG_BPL2MOD, modulo);
	cop_move(list, REG_BPLCON2, 0x0024);
}

static void build_game_copper(UWORD index) {
	BufferState *state = index ? &states[1] : &states[0];
	HwBuffer *buffer = index ? &hw_buffers[1] : &hw_buffers[0];
	CopperSlots *slots = &state->copper;
	CopperList list;
	cop_begin(&list, buffer->copper);
	copper_sprites(&list, slots->sprites);
	copper_display(&list, HW_STRIDE - HW_ROW_BYTES);
	cop_move(&list, REG_BPLCON0, 0x4200);
	cop_move(&list, REG_BPLCON1, 0x0088);
	slots->hud_colors = copper_palette(&list, 0, asset_hud_palette, 16);
	slots->sprite_colors = copper_palette(&list, 16, asset_sprite_palette, 16);
	copper_planes(&list, hw_buffers[0].hud_top, 4, HW_ROW_BYTES);
	cop_wait(&list, DISPLAY_TOP + HW_HUD_TOP_ROWS);
	cop_move(&list, REG_BPLCON0, 0x0200);
	slots->arena_colors = copper_palette(&list, 0, asset_arena_palette, 16);
	slots->arena_planes = copper_planes(&list, buffer->arena + ARENA_TOP * HW_STRIDE, 4, HW_ROW_BYTES);
	slots->arena_scroll = cop_move(&list, REG_BPLCON1, 0x0088);
	cop_wait(&list, ARENA_FIRST_LINE);
	cop_move(&list, REG_BPLCON0, 0x4200);
	/* Pasmo banera: dwa WAIT + zmiana COLOR15 (wygaszanie napisu). */
	slots->band = cop_wait(&list, ARENA_FIRST_LINE + 1);
	cop_move(&list, REG_COLOR00 + BANNER_COLOR * 2, asset_arena_palette[BANNER_COLOR]);
	cop_wait(&list, ARENA_FIRST_LINE + 2);
	cop_move(&list, REG_COLOR00 + BANNER_COLOR * 2, asset_arena_palette[BANNER_COLOR]);
	cop_wait(&list, DISPLAY_TOP + HW_BOTTOM_LINE - 2);
	cop_move(&list, REG_BPLCON0, 0x0200);
	slots->bottom_colors = copper_palette(&list, 0, asset_hud_palette, 16);
	copper_planes(&list, hw_buffers[0].hud_bottom, 4, HW_ROW_BYTES);
	cop_move(&list, REG_BPLCON1, 0x0088);
	cop_wait(&list, DISPLAY_TOP + HW_BOTTOM_LINE);
	cop_move(&list, REG_BPLCON0, 0x4200);
	cop_end(&list);
	slots->palette_version = 0;
	slots->valid = 1;
}

static void patch_colors(UWORD *slot, const UWORD *colors) {
	WORD index;
	for (index = 0; index < 16; ++index) {
		slot[index * 2] = colors[index];
	}
}

/* ------------------------------------------------------------------ API */

void render_init(void) {
	memset(states, 0, sizeof(states));
	memset(&hud, 0, sizeof(hud));
	states[0].player_frame = -1;
	states[1].player_frame = -1;
	init_sprites(&hw_buffers[0]);
	init_sprites(&hw_buffers[1]);
	hw_sprite_empty[0] = 0;
	hw_sprite_empty[1] = 0;
	banner_text[0] = 0;
	palette_valid = 0;
}

void render_reset_game(void) {
	states[0].arena_valid = 0;
	states[1].arena_valid = 0;
	states[0].copper.valid = 0;
	states[1].copper.valid = 0;
	hud.valid = 0;
}

UWORD *render_game(UWORD index, const GameState *game, const RenderView *view) {
	BufferState *state = index ? &states[1] : &states[0];
	HwBuffer *buffer = index ? &hw_buffers[1] : &hw_buffers[0];
	CopperSlots *slots = &state->copper;
	UBYTE *arena = buffer->arena;
	const UBYTE *background = hw_asset_chip + ASSET_ARENA;
	UWORD *sprites[8] = {0, 0, 0, 0, 0, 0, 0, 0};
	PaletteKey key;
	WORD shake_x = 0;
	WORD shake_y = 0;
	WORD banner_y = -1;
	WORD item;
	WORD player_sx;
	WORD player_sy;
	UWORD frame = (UWORD)game->frame;
	ULONG profile_mark = beam();

	/* 1. Przywrócenie tła pod obiektami z poprzedniej ramki tego bufora. */
	if (!state->arena_valid) {
		hw_blit_copy(background, arena, 0, 0, HW_ROW_BYTES * 8, HW_ARENA_ROWS);
		state->arena_valid = 1;
	} else {
		const Rect *rect = state->dirty;
		hw_copy_begin();
		for (item = 0; item < (WORD)state->dirty_count; ++item, ++rect) {
			hw_copy_rect(background + rect->offset, arena + rect->offset, rect->words, rect->rows4);
		}
	}
	state->dirty_count = 0;
	PROFILE(0);

	/* 2. Pickupy (wirują jak rotation.y += 2 rad/s). */
	{
	const GamePickup *pickup = game->pickups;
	for (item = 0; item < GAME_MAX_PICKUPS; ++item, ++pickup) {
		if (pickup->active) {
			WORD rotation = (WORD)(mulu16(pickup->age, 13) >> 7) & 7;
			draw_bob16(state, arena, ASSET_PICKUPS + ((ULONG)(pickup->kind * 8 + rotation) << 8),
				buffer_x(pickup->x) - 8, buffer_y(pickup->y) - 8);
		}
	}
	}

	/* 3. Przeciwnicy: telegraph + skalowanie przy spawnie, potem 16 kierunków × 4 klatki. */
	{
	const GameEnemy *enemy = game->enemies;
	WORD anim_step = (WORD)divu16(frame, 5);
	for (item = 0; item < GAME_MAX_ENEMIES; ++item, ++enemy) {
		WORD x;
		WORD y;
		if (!enemy->active) {
			continue;
		}
		x = buffer_x(enemy->x) - 8;
		y = buffer_y(enemy->y) - 8;
		if (enemy->spawn > 0) {
			WORD elapsed = GAME_SPAWN_FRAMES - enemy->spawn;
			WORD k = (WORD)(mulu16((UWORD)elapsed, 9362) >> 10);                       /* 0..256 */
			WORD scale = (WORD)(13 + (mulu16((UWORD)(mulu16((UWORD)k, (UWORD)k) >> 8), 243) >> 8));   /* 0,05 + 0,95·k² */
			UBYTE bright = k > 43 && k < 213;
			WORD spin = (WORD)(((mulu16((UWORD)elapsed, 184) >> 10) + item) & 3);
			draw_bob16(state, arena, ASSET_TELEGRAPH + ((ULONG)(bright * 4 + spin) << 8), x, y);
			if (scale >= 38) {
				if (scale >= 218) {
					WORD dir = ((enemy->rotation + 32) >> 6) & 15;
					draw_bob16(state, arena, ASSET_ENEMIES + ((ULONG)((enemy->variant * 16 + dir) * 4 + enemy->anim) << 8), x, y);
				} else {
					WORD dir8 = ((enemy->rotation + 64) >> 7) & 7;
					WORD size = scale < 115 ? 0 : 1;
					draw_bob16(state, arena, ASSET_SPAWN + ((ULONG)(enemy->variant * 16 + size * 8 + dir8) << 8), x, y);
				}
			}
		} else {
			WORD dir = ((enemy->rotation + 32) >> 6) & 15;
			WORD anim = (WORD)((enemy->anim + anim_step) & 3);
			draw_bob16(state, arena, ASSET_ENEMIES + ((ULONG)((enemy->variant * 16 + dir) * 4 + anim) << 8), x, y);
		}
	}
	}
	PROFILE(1);

	/* 4. Eksplozje (8 klatek w 0,6 s). */
	{
	const GameExplosion *explosion = game->explosions;
	for (item = 0; item < GAME_MAX_EXPLOSIONS; ++item, ++explosion) {
		if (explosion->active) {
			WORD step = (WORD)(mulu16(explosion->age, 273) >> 10);
			draw_bob32(state, arena, ASSET_EXPLOSIONS + ((ULONG)(explosion->variant * 8 + step) << 10),
				buffer_x(explosion->x) - 16, buffer_y(explosion->y) - 16);
		}
	}
	}

	/* 5. Tracery hitscanu. */
	{
	const GameTracer *tracer = game->tracers;
	for (item = 0; item < GAME_MAX_TRACERS; ++item, ++tracer) {
		if (tracer->active) {
			draw_tracer(state, arena, tracer);
		}
	}
	}
	PROFILE(2);

	/* 6. Baner fali albo pauza. */
	if (view->paused) {
		if (!banner_paused) {
			prepare_banner("", 1);
		}
		banner_y = draw_banner(state, arena, ARENA_CY);
	} else if (game->banner_frames > 0) {
		if (banner_paused || strcmp(banner_text, game->banner) != 0) {
			prepare_banner(game->banner, 0);
		}
		banner_y = draw_banner(state, arena, ARENA_TOP + 54);
	}
	PROFILE(3);

	/* 7. HUD (tylko zmienione pola). */
	draw_hud(game, view);
	PROFILE(4);

	/* 8. Wstrząs kamery: ±shake_time·2 jednostki. */
	if (game->shake > 0 && !view->paused) {
		WORD amplitude = (WORD)(mulu16(game->shake, 82) >> 8);
		if (amplitude > 7) {
			amplitude = 7;
		}
		if (amplitude > 0) {
			UWORD range = (UWORD)(amplitude * 2 + 1);
			UWORD remainder;
			divmodu16(next_random(), range, &remainder);
			shake_x = (WORD)remainder - amplitude;
			divmodu16(next_random(), range, &remainder);
			shake_y = (WORD)remainder - amplitude;
		}
	}

	/* 9. Sprite'y: gracz (2 pary attached), celownik, błysk lufy. */
	player_sx = render_world_to_screen_x(game->player_x) + shake_x;
	player_sy = render_world_to_screen_y(game->player_y) + shake_y;
	if (!(game->invulnerability > 0 && ((divu16((UWORD)(game->blink * 2), 7)) & 1))) {
		update_player_sprites(state, buffer, game, player_sx, player_sy);
		sprites[0] = buffer->sprite_player[0];
		sprites[1] = buffer->sprite_player[1];
		sprites[2] = buffer->sprite_player[2];
		sprites[3] = buffer->sprite_player[3];
	}
	if (view->crosshair_visible) {
		sprite_header(buffer->sprite_cross, view->crosshair_x - 8, view->crosshair_y - 8, 16, 0);
		sprites[4] = buffer->sprite_cross;
	}
	if (game->muzzle > 0 && !game->dead) {
		WORD mx = player_sx + (WORD)(muls16(game_sin(game->aim), 9) >> 14);
		WORD my = player_sy - (WORD)(muls16(game_cos(game->aim), 9) >> 14);
		sprite_header(buffer->sprite_muzzle, mx - 8, my - 3, 8, 0);
		sprites[5] = buffer->sprite_muzzle;
	}

	/* 10. Palety z efektami (błysk, winieta, Overdrive, pauza) — przeliczane tylko po zmianie. */
	key.flash = game->flash > 0 ? (WORD)divu16(mulu16(82, game->flash), GAME_FLASH_FRAMES) : 0;
	key.danger = 0;
	if (game->hp * 10 < GAME_HP_MAX * 3 && !game->dead) {
		WORD pulse = game_sin((WORD)((frame * 13) & 1023));
		key.danger = (WORD)(70 + ((muls16(pulse, 24) >> 14) & ~3));
	}
	key.overdrive = game->overdrive > 0;
	key.paused = view->paused;
	update_palettes(&key);

	/* 11. Łatanie listy Coppera. */
	if (!slots->valid) {
		build_game_copper(index);
	}
	for (item = 0; item < 8; ++item) {
		cop_set_pointer(slots->sprites[item], sprites[item] ? sprites[item] : hw_sprite_empty);
	}
	if (slots->palette_version != palette_version) {
		patch_colors(slots->hud_colors, palette_hud);
		patch_colors(slots->sprite_colors, palette_sprites);
		patch_colors(slots->arena_colors, palette_arena);
		patch_colors(slots->bottom_colors, palette_hud);
		slots->palette_version = palette_version;
	}
	for (item = 0; item < 4; ++item) {
		cop_set_pointer(slots->arena_planes + item * 4, arena + muls16((short)(ARENA_TOP - shake_y), HW_STRIDE) + item * HW_ROW_BYTES);
	}
	*slots->arena_scroll = (UWORD)((8 + shake_x) | ((8 + shake_x) << 4));
	if (banner_y >= 0 && !view->paused && game->banner_frames < 35) {
		WORD line = ARENA_FIRST_LINE + banner_y - ARENA_TOP + shake_y;
		UWORD faded = blend(palette_arena[BANNER_COLOR], 0, 1, 2,
			(WORD)(256 - divu16(mulu16(game->banner_frames, 256), 35)));
		slots->band[0] = (UWORD)(((line & 0xff) << 8) | 0x07);
		slots->band[3] = faded;
		slots->band[4] = (UWORD)((((line + banner_height) & 0xff) << 8) | 0x07);
		slots->band[7] = palette_arena[BANNER_COLOR];
	} else {
		slots->band[0] = (UWORD)((((ARENA_FIRST_LINE + 1) & 0xff) << 8) | 0x07);
		slots->band[3] = palette_arena[BANNER_COLOR];
		slots->band[4] = (UWORD)((((ARENA_FIRST_LINE + 2) & 0xff) << 8) | 0x07);
		slots->band[7] = palette_arena[BANNER_COLOR];
	}
	hw_blit_wait();
	PROFILE(5);
	return buffer->copper;
}

/* ------------------------------------------------------------------ ekrany menu */

static const WORD table_x[6] = {30, 40, 146, 158, 250, 266};
static const UBYTE table_align[6] = {TEXT_RIGHT, TEXT_LEFT, TEXT_RIGHT, TEXT_LEFT, TEXT_RIGHT, TEXT_LEFT};

static void draw_table_line(const Canvas *canvas, WORD y, const char *line, UWORD color) {
	char cell[RENDER_LINE_MAX];
	WORD column = 0;
	while (*line && column < 6) {
		WORD length = 0;
		while (line[length] && line[length] != '\t') {
			cell[length] = line[length];
			++length;
		}
		cell[length] = 0;
		text_draw_aligned(canvas, &asset_font_s, 8 + table_x[column], y, cell, color, table_align[column]);
		line += length;
		if (*line == '\t') {
			++line;
		}
		++column;
	}
}

UWORD *render_menu(UWORD index, const RenderScreen *screen, UBYTE redraw) {
	HwBuffer *buffer = index ? &hw_buffers[1] : &hw_buffers[0];
	CopperList list;
	(index ? &states[1] : &states[0])->copper.valid = 0;
	if (redraw) {
		Canvas canvas = {hw_menu, HW_ROW_BYTES, 3, HW_MENU_ROWS};
		WORD line_height = asset_font_s.height + 2;
		WORD body_height = 0;
		WORD y;
		WORD item;
		hw_blit_clear(hw_menu, HW_ROW_BYTES, 3, 0, 0, HW_ROW_BYTES * 8, HW_MENU_ROWS);
		hw_blit_wait();
		text_draw_aligned(&canvas, &asset_font_xl, ARENA_CX, 18, screen->title, 1, TEXT_CENTER);
		for (item = 0; item < screen->count; ++item) {
			body_height += item == screen->big_line ? asset_font_l.height + 6 : line_height;
		}
		y = 50 + ((172 - body_height) >> 1);
		if (y < 48) {
			y = 48;
		}
		for (item = 0; item < screen->count; ++item) {
			if (item == screen->big_line) {
				text_draw_aligned(&canvas, &asset_font_l, ARENA_CX, y + 3, screen->lines[item], screen->colors[item], TEXT_CENTER);
				y += asset_font_l.height + 6;
			} else {
				if (screen->table && item >= screen->table_first && item < screen->table_end) {
					draw_table_line(&canvas, y, screen->lines[item], screen->colors[item]);
				} else {
					text_draw_aligned(&canvas, &asset_font_s, ARENA_CX, y, screen->lines[item], screen->colors[item], TEXT_CENTER);
				}
				y += line_height;
			}
		}
		text_draw_aligned(&canvas, &asset_font_s, ARENA_CX, 226, screen->hint[0], 3, TEXT_CENTER);
		text_draw_aligned(&canvas, &asset_font_s, ARENA_CX, 238, screen->hint[1], 3, TEXT_CENTER);
	}
	cop_begin(&list, buffer->copper);
	copper_sprites(&list, 0);
	copper_display(&list, HW_MENU_STRIDE - HW_ROW_BYTES);
	cop_move(&list, REG_BPLCON0, 0x3200);
	cop_move(&list, REG_BPLCON1, 0x0088);
	copper_palette(&list, 0, asset_menu_palette, 8);
	copper_planes(&list, hw_menu, 3, HW_ROW_BYTES);
	cop_end(&list);
	return buffer->copper;
}
