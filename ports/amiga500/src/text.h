#ifndef PHOBOS_TEXT_H
#define PHOBOS_TEXT_H

#include <exec/types.h>
#include "../assets/generated/assets.h"

/* Bufor przeplatany: wiersz = `depth` planów po `row_bytes` bajtów. */
typedef struct {
	UBYTE *base;
	WORD row_bytes;
	WORD depth;
	WORD rows;
} Canvas;

#define TEXT_LEFT 0
#define TEXT_CENTER 1
#define TEXT_RIGHT 2

WORD text_width(const AssetFont *font, const char *text);
void text_draw(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text, UWORD color);
void text_draw_aligned(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text,
	UWORD color, UWORD align);
void text_draw_shadowed(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text,
	UWORD color, UWORD shadow, UWORD align);
void canvas_fill(const Canvas *canvas, WORD x, WORD y, WORD w, WORD h, UWORD color);
void canvas_clear(const Canvas *canvas);

/* Pomocnicze formatowanie tekstu bez stdio. */
char *str_append(char *out, const char *text);
char *str_number(char *out, unsigned long value, WORD min_digits);

#endif
