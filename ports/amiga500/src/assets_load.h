#ifndef PHOBOS_ASSETS_LOAD_H
#define PHOBOS_ASSETS_LOAD_H

#include <exec/types.h>

/* Rozpakowuje grafikę (LZSS) i kopiuje próbki SFX do Chip RAM; muzyka (IMA ADPCM) trafia do dowolnej RAM. */
extern UBYTE *asset_chip_data;
extern BYTE *asset_music_data;

int assets_load(void);
void assets_free(void);
/* Dekodowanie kolejnych warstw muzyki: zwraca 1, gdy całość gotowa. */
int assets_music_step(void);
void assets_music_finish(void);

#endif
