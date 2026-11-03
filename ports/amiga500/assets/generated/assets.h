#ifndef PHOBOS_ASSETS_H
#define PHOBOS_ASSETS_H

/* Wygenerowano przez tools/convert_assets.py — nie edytować ręcznie. */

#define ASSET_CHIP_SIZE 210898UL
#define ASSET_GFX_SIZE 153120UL
#define ASSET_SFX_SAMPLES 57778UL
#define ASSET_MUSIC_SIZE 128000UL
#define ASSET_ARENA 0UL
#define ASSET_ENEMIES 36288UL
#define ASSET_SPAWN 85440UL
#define ASSET_TELEGRAPH 97728UL
#define ASSET_PICKUPS 99776UL
#define ASSET_EXPLOSIONS 103872UL
#define ASSET_PLAYER 120256UL
#define ASSET_CROSSHAIR 153024UL
#define ASSET_MUZZLE 153088UL
#define SFX_SHOT 153120UL
#define SFX_HIT 154112UL
#define SFX_ENEMY_DIE 154664UL
#define SFX_PLAYER_DAMAGE 159074UL
#define SFX_PICKUP_HEAL 162382UL
#define SFX_PICKUP_OVERDRIVE 165690UL
#define SFX_OVERDRIVE_OFF 171202UL
#define SFX_WAVE_START 175612UL
#define SFX_WAVE_CLEAR 186638UL
#define SFX_GAME_OVER 193254UL
#define SFX_SILENCE 210894UL

#define ASSET_ARENA_WIDTH 336
#define ASSET_ARENA_HEIGHT 216
#define ASSET_ENEMY_DIRS 16
#define ASSET_PLAYER_DIRS 16
#define ASSET_BOB16_SIZE 256
#define ASSET_BOB32_SIZE 1024
#define ASSET_PLAYER_FRAME_SIZE 512
#define ASSET_SFX_PERIOD 322
#define ASSET_MUSIC_PERIOD 443
#define ASSET_MUSIC_LAYER_LENGTH 32000UL
#define ASSET_MUSIC_BUFFER 320
#define ASSET_SFX_COUNT 10

extern const short asset_sin[1024];
extern const unsigned char asset_atan[65];
extern const unsigned short asset_arena_palette[16];
extern const unsigned short asset_hud_palette[16];
extern const unsigned short asset_menu_palette[8];
extern const unsigned short asset_sprite_palette[16];

typedef struct { unsigned long offset; unsigned short length; } AssetSample;
extern const AssetSample asset_sfx[ASSET_SFX_COUNT];
enum {
	SFX_ID_SHOT,
	SFX_ID_HIT,
	SFX_ID_ENEMY_DIE,
	SFX_ID_PLAYER_DAMAGE,
	SFX_ID_PICKUP_HEAL,
	SFX_ID_PICKUP_OVERDRIVE,
	SFX_ID_OVERDRIVE_OFF,
	SFX_ID_WAVE_START,
	SFX_ID_WAVE_CLEAR,
	SFX_ID_GAME_OVER,
};

typedef struct {
	unsigned short code;
	unsigned char advance;
	unsigned char pad;
	unsigned short rows;
} AssetGlyph;
typedef struct {
	unsigned short height;
	unsigned short count;
	const AssetGlyph *glyphs;
	const unsigned long *bits;
} AssetFont;
extern const AssetFont asset_font_xl;

extern const AssetFont asset_font_l;

extern const AssetFont asset_font_s;

#endif
