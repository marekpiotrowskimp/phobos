#ifndef PHOBOS_RENDER_H
#define PHOBOS_RENDER_H

#include "game.h"
#include "hw.h"

#define RENDER_LINE_MAX 64

typedef struct {
	const char *difficulty;
	UWORD fps;
	UBYTE paused;
	UBYTE crosshair_visible;
	WORD crosshair_x;   /* współrzędne ekranu 0..319 / 0..255 */
	WORD crosshair_y;
} RenderView;

typedef struct {
	char title[RENDER_LINE_MAX];
	char lines[16][RENDER_LINE_MAX];
	UBYTE colors[16];
	UBYTE count;
	UBYTE big_line;     /* indeks linii rysowanej większym fontem albo 0xff */
	char hint[2][RENDER_LINE_MAX];
	UBYTE table;        /* 1 = linie [table_first, table_end) to tabela wyników */
	UBYTE table_first;
	UBYTE table_end;
} RenderScreen;

void render_init(void);
void render_reset_game(void);
UWORD *render_game(UWORD index, const GameState *game, const RenderView *view);
UWORD *render_menu(UWORD index, const RenderScreen *screen, UBYTE redraw);

/* Konwersje współrzędnych świat ↔ ekran (bez wstrząsu). */
WORD render_world_to_screen_x(long x);
WORD render_world_to_screen_y(long y);
long render_screen_to_world_x(WORD x);
long render_screen_to_world_y(WORD y);

#endif
