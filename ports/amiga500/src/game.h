#ifndef PHOBOS_GAME_H
#define PHOBOS_GAME_H

/*
 * Logika rundy PHOBOS — port project/scripts/{main,player,enemy,pickup}.gd
 * oraz autoloads/balance.gd. Krok logiki = 1/50 s (PAL), pozycje w Q10
 * (1 jednostka świata Godot = 1024), kąty 0..1023 (0 = w górę, zgodnie z zegarem).
 */

#define GAME_FP 1024L
#define GAME_UNIT(value) ((long)((value) * 1024.0))
#define GAME_FPS 50
#define GAME_ANGLE_FULL 1024

#define GAME_MAX_ENEMIES 30
#define GAME_MAX_PICKUPS 12
#define GAME_MAX_EXPLOSIONS 10
#define GAME_MAX_TRACERS 4
#define GAME_MAX_EVENTS 16

#define GAME_DIFFICULTY_EASY 0
#define GAME_DIFFICULTY_NORMAL 1
#define GAME_DIFFICULTY_HARD 2

#define GAME_PICKUP_HEAL 0
#define GAME_PICKUP_OVERDRIVE 1

#define GAME_STATE_BREAK 0
#define GAME_STATE_WAVE 1
#define GAME_STATE_OVER 2

#define GAME_HP_MAX 100
#define GAME_SPAWN_FRAMES 28
#define GAME_INVULN_FRAMES 28
#define GAME_OVERDRIVE_FRAMES 750
#define GAME_PICKUP_FRAMES 400
#define GAME_EXPLOSION_FRAMES 30
#define GAME_TRACER_FRAMES 4
#define GAME_MUZZLE_FRAMES 3
#define GAME_FLASH_FRAMES 20
#define GAME_BANNER_FRAMES 90

typedef struct {
	signed char move_x;
	signed char move_y;
	unsigned char aim_valid;
	long aim_x;
	long aim_y;
	unsigned char fire;
} GameInput;

typedef struct {
	long x;
	long y;
	short rotation;
	short target_rotation;
	unsigned char active;
	unsigned char variant;
	unsigned char spawn;
	unsigned char anim;
	unsigned char speed;
	unsigned char spawn_fresh;
	unsigned short points;
} GameEnemy;

typedef struct {
	long x;
	long y;
	unsigned short life;
	unsigned short age;
	unsigned char active;
	unsigned char kind;
} GamePickup;

typedef struct {
	long x;
	long y;
	unsigned char age;
	unsigned char active;
	unsigned char variant;
} GameExplosion;

typedef struct {
	long x0;
	long y0;
	long x1;
	long y1;
	unsigned char age;
	unsigned char active;
} GameTracer;

typedef struct {
	unsigned char sfx;
	unsigned char volume;
	unsigned short pitch;
} GameEvent;

typedef struct {
	/* gracz */
	long player_x;
	long player_y;
	long velocity_x;
	long velocity_y;
	short aim;
	short hp;
	short fire_timer;
	unsigned short invulnerability;
	unsigned short blink;
	unsigned short overdrive;
	unsigned short anim;
	unsigned char moving;
	unsigned char dead;
	unsigned char debug_invulnerable;
	unsigned char muzzle;

	/* director */
	unsigned char state;
	unsigned char difficulty;
	unsigned char wave_warned;
	unsigned char refill_first_side;
	unsigned short wave;
	unsigned short alive;
	unsigned short target_alive;
	unsigned short spawn_group_size;
	unsigned short wave_frames;
	unsigned short wave_second;
	short spawn_timer;
	short refill_burst_timer;
	unsigned short refill_remaining;
	unsigned short refill_group_index;
	short break_timer;
	unsigned short kills_since_heal;
	unsigned short completed_waves;
	unsigned short max_alive_seen;
	unsigned char director_violation;

	/* wynik */
	unsigned long score;
	unsigned short kills;
	unsigned long run_frames;
	unsigned long frame;
	unsigned long rng;
	unsigned short heal_drops;
	unsigned short overdrive_drops;
	unsigned short forced_heals;

	/* prezentacja */
	unsigned short shake;
	unsigned short flash;
	unsigned short banner_frames;
	char banner[32];
	unsigned char music_level;
	unsigned char explosion_next;
	unsigned char event_count;
	GameEvent events[GAME_MAX_EVENTS];

	GameEnemy enemies[GAME_MAX_ENEMIES];
	GamePickup pickups[GAME_MAX_PICKUPS];
	GameExplosion explosions[GAME_MAX_EXPLOSIONS];
	GameTracer tracers[GAME_MAX_TRACERS];
} GameState;

void game_init(GameState *game, unsigned char difficulty, unsigned long seed);
void game_step(GameState *game, const GameInput *input);
short game_atan2(long dx, long dy);
short game_sin(short angle);
short game_cos(short angle);
unsigned short game_random(GameState *game);
unsigned short game_wave_seconds(const GameState *game);
void game_autopilot(GameState *game, GameInput *input);
int game_self_test(void);

#endif
