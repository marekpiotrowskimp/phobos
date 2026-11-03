#include "assets_load.h"
#include "../assets/generated/assets.h"

#include <exec/memory.h>
#include <proto/exec.h>

extern const UBYTE asset_gfx_lz[];
extern const UBYTE asset_sfx_raw[];
extern const UBYTE asset_music_ima[];

UBYTE *asset_chip_data;
BYTE *asset_music_data;

static const UWORD ima_steps[89] = {
	7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66,
	73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408,
	449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066,
	2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630,
	9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767
};
static const BYTE ima_index[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};

static void lzss_decode(const UBYTE *source, UBYTE *target, ULONG size) {
	UBYTE *end = target + size;
	while (target < end) {
		UBYTE flags = *source++;
		WORD bit;
		for (bit = 0; bit < 8 && target < end; ++bit, flags <<= 1) {
			if (flags & 0x80) {
				*target++ = *source++;
			} else {
				UWORD value = (UWORD)((source[0] << 8) | source[1]);
				const UBYTE *from = target - (value >> 4);
				WORD length = (WORD)(value & 15) + 3;
				source += 2;
				while (length-- > 0) {
					*target++ = *from++;
				}
			}
		}
	}
}

/* Dekoder tablicowy: dla każdego stanu (indeks kroku) i kodu przechowuje deltę i następny stan. */
static WORD ima_delta[89 * 16];
static UWORD ima_next[89 * 16];

static void ima_tables(void) {
	WORD index;
	for (index = 0; index < 89; ++index) {
		WORD code;
		for (code = 0; code < 16; ++code) {
			WORD step = (WORD)ima_steps[index];
			WORD delta = step >> 3;
			WORD next = index + ima_index[code];
			if (code & 4) {
				delta += step;
			}
			if (code & 2) {
				delta += step >> 1;
			}
			if (code & 1) {
				delta += step >> 2;
			}
			if (next < 0) {
				next = 0;
			} else if (next > 88) {
				next = 88;
			}
			ima_delta[index * 16 + code] = (code & 8) ? (WORD)-delta : delta;
			ima_next[index * 16 + code] = (UWORD)(next * 16);
		}
	}
}

typedef struct {
	const UBYTE *source;
	BYTE *target;
	LONG predicted;
	UWORD row;
} ImaState;

static ImaState music_state;
static ULONG music_decoded;

static void ima_begin(ImaState *state, const UBYTE *source, BYTE *target) {
	state->source = source;
	state->target = target;
	state->predicted = 0;
	state->row = 0;
}

/* Dekoduje `pairs` bajtów (2 próbki na bajt). */
static void ima_run(ImaState *state, ULONG pairs) {
	const UBYTE *source = state->source;
	BYTE *target = state->target;
	LONG predicted = state->predicted;
	UWORD row = state->row;
	while (pairs-- > 0) {
		UBYTE packed = *source++;
		UWORD slot = row + (packed >> 4);
		predicted += ima_delta[slot];
		if (predicted > 32767) {
			predicted = 32767;
		} else if (predicted < -32768) {
			predicted = -32768;
		}
		row = ima_next[slot];
		*target++ = (BYTE)(predicted >> 8);
		slot = row + (packed & 15);
		predicted += ima_delta[slot];
		if (predicted > 32767) {
			predicted = 32767;
		} else if (predicted < -32768) {
			predicted = -32768;
		}
		row = ima_next[slot];
		*target++ = (BYTE)(predicted >> 8);
	}
	state->source = source;
	state->target = target;
	state->predicted = predicted;
	state->row = row;
}

int assets_music_step(void) {
	ULONG remaining = ASSET_MUSIC_SIZE - music_decoded;
	ULONG chunk = remaining > 4096 ? 4096 : remaining;
	if (chunk == 0) {
		return 1;
	}
	ima_run(&music_state, chunk >> 1);
	music_decoded += chunk;
	return music_decoded >= ASSET_MUSIC_SIZE;
}

void assets_music_finish(void) {
	while (!assets_music_step()) {
	}
}

int assets_load(void) {
	asset_chip_data = (UBYTE *)AllocMem(ASSET_CHIP_SIZE, MEMF_CHIP);
	asset_music_data = (BYTE *)AllocMem(ASSET_MUSIC_SIZE, MEMF_PUBLIC);
	if (asset_chip_data == 0 || asset_music_data == 0) {
		assets_free();
		return 0;
	}
	ima_tables();
	lzss_decode(asset_gfx_lz, asset_chip_data, ASSET_GFX_SIZE);
	CopyMem((APTR)asset_sfx_raw, asset_chip_data + ASSET_GFX_SIZE, ASSET_SFX_SAMPLES);
	/* Muzyka: od razu tylko warstwa 0 (menu), reszta dekodowana w tle. */
	ima_begin(&music_state, asset_music_ima, asset_music_data);
	music_decoded = 0;
	while (music_decoded < ASSET_MUSIC_LAYER_LENGTH) {
		assets_music_step();
	}
	return 1;
}

void assets_free(void) {
	if (asset_chip_data != 0) {
		FreeMem(asset_chip_data, ASSET_CHIP_SIZE);
		asset_chip_data = 0;
	}
	if (asset_music_data != 0) {
		FreeMem(asset_music_data, ASSET_MUSIC_SIZE);
		asset_music_data = 0;
	}
}
