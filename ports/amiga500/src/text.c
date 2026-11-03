#include "text.h"
#include "fastmath.h"

static UWORD next_code(const char **text) {
	const UBYTE *p = (const UBYTE *)*text;
	UWORD code = *p++;
	if (code >= 0xe0 && p[0] && p[1]) {
		code = ((code & 0x0f) << 12) | ((p[0] & 0x3f) << 6) | (p[1] & 0x3f);
		p += 2;
	} else if (code >= 0xc0 && p[0]) {
		code = ((code & 0x1f) << 6) | (p[0] & 0x3f);
		p += 1;
	}
	*text = (const char *)p;
	return code;
}

/* Szybka tablica ASCII 32..127 dla każdego fontu (budowana przy pierwszym użyciu). */
typedef struct {
	const AssetFont *font;
	const AssetGlyph *ascii[96];
} GlyphCache;

static GlyphCache caches[4];

static const AssetGlyph *search_glyph(const AssetFont *font, UWORD code) {
	const AssetGlyph *glyph = font->glyphs;
	WORD count = font->count;
	while (count-- > 0) {
		if (glyph->code == code) {
			return glyph;
		}
		++glyph;
	}
	return 0;
}

static const AssetGlyph *find_glyph(const AssetFont *font, UWORD code) {
	GlyphCache *cache = caches;
	const AssetGlyph *glyph;
	while (cache->font != font && cache->font != 0) {
		++cache;
	}
	if (cache->font == 0) {
		WORD index;
		cache->font = font;
		for (index = 0; index < 96; ++index) {
			cache->ascii[index] = search_glyph(font, (UWORD)(index + 32));
		}
	}
	if (code >= 32 && code < 128) {
		glyph = cache->ascii[code - 32];
	} else {
		glyph = search_glyph(font, code);
	}
	return glyph ? glyph : cache->ascii['?' - 32];
}

WORD text_width(const AssetFont *font, const char *text) {
	WORD width = 0;
	while (*text) {
		const AssetGlyph *glyph = find_glyph(font, next_code(&text));
		if (glyph) {
			width += glyph->advance;
		}
	}
	return width;
}

static void or_rows(UBYTE *target, WORD stride, const unsigned long *bits, WORD rows, WORD shift, WORD words) {
	while (rows-- > 0) {
		ULONG value = *bits++;
		if (value != 0) {
			ULONG high = value >> shift;
			UWORD *word = (UWORD *)target;
			word[0] |= (UWORD)(high >> 16);
			if (words > 1) {
				word[1] |= (UWORD)high;
				if (words > 2) {
					word[2] |= (UWORD)(value << (16 - shift));
				}
			}
		}
		target += stride;
	}
}

/* Tekst jest nakładany (OR) tylko na bitplany ustawione w `color`; tło musi być wyczyszczone. */
static void draw_glyph(const Canvas *canvas, const AssetFont *font, const AssetGlyph *glyph,
	WORD x, WORD y, UWORD color) {
	WORD stride = canvas->row_bytes * canvas->depth;
	WORD shift = x & 15;
	WORD word = x >> 4;
	WORD words = (canvas->row_bytes >> 1) - word;
	const unsigned long *bits = font->bits + glyph->rows;
	WORD rows = font->height;
	UBYTE *line;
	WORD plane;
	if (x < 0 || words <= 0) {
		return;
	}
	if (words > 3) {
		words = shift ? 3 : 2;
	} else if (words == 3 && !shift) {
		words = 2;
	}
	if (y < 0) {
		bits -= y;
		rows += y;
		y = 0;
	}
	if (y + rows > canvas->rows) {
		rows = canvas->rows - y;
	}
	if (rows <= 0) {
		return;
	}
	line = canvas->base + muls16(y, stride) + word * 2;
	for (plane = 0; plane < canvas->depth; ++plane, line += canvas->row_bytes) {
		if (color & (1 << plane)) {
			or_rows(line, stride, bits, rows, shift, words);
		}
	}
}

void text_draw(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text, UWORD color) {
	while (*text) {
		const AssetGlyph *glyph = find_glyph(font, next_code(&text));
		if (glyph) {
			draw_glyph(canvas, font, glyph, x, y, color);
			x += glyph->advance;
		}
	}
}

void text_draw_aligned(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text,
	UWORD color, UWORD align) {
	if (align == TEXT_CENTER) {
		x -= text_width(font, text) >> 1;
	} else if (align == TEXT_RIGHT) {
		x -= text_width(font, text);
	}
	text_draw(canvas, font, x, y, text, color);
}

void text_draw_shadowed(const Canvas *canvas, const AssetFont *font, WORD x, WORD y, const char *text,
	UWORD color, UWORD shadow, UWORD align) {
	if (align == TEXT_CENTER) {
		x -= text_width(font, text) >> 1;
	} else if (align == TEXT_RIGHT) {
		x -= text_width(font, text);
	}
	text_draw(canvas, font, x - 1, y, text, shadow);
	text_draw(canvas, font, x + 1, y, text, shadow);
	text_draw(canvas, font, x, y - 1, text, shadow);
	text_draw(canvas, font, x, y + 1, text, shadow);
	text_draw(canvas, font, x + 1, y + 1, text, shadow);
	text_draw(canvas, font, x, y, text, color);
}

void canvas_fill(const Canvas *canvas, WORD x, WORD y, WORD w, WORD h, UWORD color) {
	WORD stride = canvas->row_bytes * canvas->depth;
	WORD first = x >> 4;
	WORD last = (x + w - 1) >> 4;
	UWORD first_mask = (UWORD)(0xffff >> (x & 15));
	UWORD last_mask = (UWORD)(0xffff << (15 - ((x + w - 1) & 15)));
	WORD middle = last - first - 1;
	WORD plane;
	UBYTE *plane_base;
	if (w <= 0 || h <= 0 || y < 0 || y + h > canvas->rows) {
		return;
	}
	if (first == last) {
		first_mask &= last_mask;
	}
	plane_base = canvas->base + muls16(y, stride) + first * 2;
	for (plane = 0; plane < canvas->depth; ++plane, plane_base += canvas->row_bytes) {
		UWORD set = (color & (1 << plane)) ? 0xffff : 0;
		UBYTE *row = plane_base;
		WORD line;
		for (line = 0; line < h; ++line, row += stride) {
			UWORD *target = (UWORD *)row;
			WORD count = middle;
			*target = (*target & ~first_mask) | (set & first_mask);
			if (last > first) {
				while (count-- > 0) {
					*++target = set;
				}
				++target;
				*target = (*target & ~last_mask) | (set & last_mask);
			}
		}
	}
}

void canvas_clear(const Canvas *canvas) {
	ULONG *target = (ULONG *)canvas->base;
	ULONG count = mulu16((UWORD)(canvas->row_bytes * canvas->depth), (UWORD)canvas->rows) >> 2;
	while (count-- > 0) {
		*target++ = 0;
	}
}

char *str_append(char *out, const char *text) {
	while (*text) {
		*out++ = *text++;
	}
	*out = 0;
	return out;
}

char *str_number(char *out, unsigned long value, WORD min_digits) {
	char digits[12];
	WORD count = 0;
	do {
		UWORD high = (UWORD)(value >> 16);
		UWORD remainder;
		UWORD quotient_high = divmodu16(high, 10, &remainder);
		UWORD quotient_low = divmodu16(((ULONG)remainder << 16) | (UWORD)value, 10, &remainder);
		value = ((ULONG)quotient_high << 16) | quotient_low;
		digits[count++] = (char)('0' + remainder);
	} while (value > 0 || count < min_digits);
	while (count > 0) {
		*out++ = digits[--count];
	}
	*out = 0;
	return out;
}
