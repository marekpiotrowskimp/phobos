#include "game.h"
#include "fastmath.h"
#include "../assets/generated/assets.h"

/* Stałe z balance.gd przeliczone na Q10 i klatki 50 Hz. */
#define PLAYER_SPEED 225L               /* 11 j/s */
#define PLAYER_DIAGONAL 159L            /* 11 j/s · √½ */
#define ACCEL_Q10 218                   /* 1 - exp(-12/50) */
#define AIM_Q10 403                     /* 1 - exp(-25/50) */
#define TURN_Q10 218                    /* 1 - exp(-12/50) */
#define PLAYER_LIMIT_X GAME_UNIT(18.95)
#define PLAYER_LIMIT_Y GAME_UNIT(10.95)
#define WALL_X GAME_UNIT(19.5)
#define WALL_Y GAME_UNIT(11.5)
#define SPAWN_X GAME_UNIT(18.9)
#define SPAWN_Y GAME_UNIT(10.9)
#define MIN_SPAWN_DIST GAME_UNIT(9.0)
#define CONTACT_RANGE GAME_UNIT(1.15)
#define PICKUP_RANGE GAME_UNIT(1.0)
#define HIT_RADIUS GAME_UNIT(0.72)
#define MUZZLE_OFFSET GAME_UNIT(0.75)
#define AIM_DEADZONE GAME_UNIT(0.12)
#define FIRE_INTERVAL_Q8 1422           /* 50 / 9 klatek */
#define FIRE_INTERVAL_OD_Q8 948         /* 50 / 13,5 klatek */
#define CONTACT_DAMAGE 18
#define HEAL_AMOUNT 30
#define HEAL_PITY_HP 50
#define WAVE_BONUS 50
#define FIRST_BREAK 125
#define BREAK_FRAMES 250
#define REFILL_BURST 6

static const unsigned short heal_chance[3] = {140, 80, 40};
static const unsigned short overdrive_chance[3] = {90, 50, 20};
static const unsigned short pity_kills[3] = {6, 10, 14};
static const unsigned short variant_points[3] = {10, 25, 50};

/* Głośności Paula odpowiadające volume_db z oryginału. */
#define VOL_0DB 64
#define VOL_M2DB 51
#define VOL_M3DB 45
#define VOL_M4DB 40
#define VOL_M6DB 32
#define VOL_M7DB 29

static unsigned short divu(unsigned long numerator, unsigned short denominator) {
	unsigned long value = numerator;
	__asm__("divu.w %1,%0" : "+d"(value) : "d"(denominator) : "cc");
	return (unsigned short)value;
}

short game_sin(short angle) {
	return asset_sin[angle & 1023];
}

short game_cos(short angle) {
	return asset_sin[(angle + 256) & 1023];
}

short game_atan2(long dx, long dy) {
	long u = dx;
	long v = -dy;
	unsigned long au = u < 0 ? -u : u;
	unsigned long av = v < 0 ? -v : v;
	short base;
	while (au > 0xffffUL || av > 0xffffUL) {
		au >>= 1;
		av >>= 1;
	}
	if (au == 0 && av == 0) {
		return 0;
	}
	if (au <= av) {
		base = asset_atan[divu(au << 6, (unsigned short)av)];
	} else {
		base = 256 - asset_atan[divu(av << 6, (unsigned short)au)];
	}
	if (u >= 0) {
		return v >= 0 ? base : 512 - base;
	}
	return v < 0 ? 512 + base : (1024 - base) & 1023;
}

unsigned short game_random(GameState *game) {
	unsigned long x = game->rng;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	game->rng = x;
	return (unsigned short)(x >> 8);
}

static long random_range(GameState *game, long low, long high) {
	return low + (long)(mulu16(game_random(game), (unsigned short)(high - low)) >> 16);
}

static unsigned short random_pitch(GameState *game, unsigned short spread) {
	return (unsigned short)(256 - spread + (mulu16(game_random(game), (unsigned short)(spread * 2)) >> 16));
}

static void push_event(GameState *game, unsigned char sfx, unsigned short pitch, unsigned char volume) {
	if (game->event_count < GAME_MAX_EVENTS) {
		GameEvent *event = &game->events[game->event_count++];
		event->sfx = sfx;
		event->pitch = pitch;
		event->volume = volume;
	}
}

static char *append_text(char *out, const char *text) {
	while (*text) {
		*out++ = *text++;
	}
	*out = 0;
	return out;
}

static char *append_number(char *out, unsigned long value) {
	char digits[12];
	short count = 0;
	do {
		digits[count++] = (char)('0' + value % 10);
		value /= 10;
	} while (value > 0);
	while (count > 0) {
		*out++ = digits[--count];
	}
	*out = 0;
	return out;
}

static void show_banner(GameState *game, unsigned short bonus) {
	char *out = append_text(game->banner, "FALA ");
	out = append_number(out, game->wave);
	if (bonus) {
		out = append_text(out, " UDANA  +");
		append_number(out, bonus);
	}
	game->banner_frames = GAME_BANNER_FRAMES;
}

static unsigned short wave_music(const GameState *game) {
	unsigned short level = 1 + (game->wave - 1) / 2;
	return level > 2 ? 2 : level;
}

unsigned short game_wave_seconds(const GameState *game) {
	return divu16((unsigned long)game->wave_frames + GAME_FPS - 1, GAME_FPS);
}

void game_init(GameState *game, unsigned char difficulty, unsigned long seed) {
	unsigned char *bytes = (unsigned char *)game;
	unsigned long index;
	for (index = 0; index < sizeof(*game); ++index) {
		bytes[index] = 0;
	}
	game->difficulty = difficulty <= GAME_DIFFICULTY_HARD ? difficulty : GAME_DIFFICULTY_NORMAL;
	game->rng = seed ? seed : 0x2545f491UL;
	game->hp = GAME_HP_MAX;
	game->aim = 0;
	game->state = GAME_STATE_BREAK;
	game->break_timer = FIRST_BREAK;
}

/* ------------------------------------------------------------------ efekty */

static void spawn_explosion(GameState *game, long x, long y) {
	GameExplosion *explosion = &game->explosions[game->explosion_next];
	if (++game->explosion_next >= GAME_MAX_EXPLOSIONS) {
		game->explosion_next = 0;
	}
	explosion->x = x;
	explosion->y = y;
	explosion->age = 0;
	explosion->active = 1;
	explosion->variant = game_random(game) & 1;
}

static void spawn_tracer(GameState *game, long x0, long y0, long x1, long y1) {
	unsigned short index;
	GameTracer *tracer = &game->tracers[0];
	for (index = 0; index < GAME_MAX_TRACERS; ++index) {
		if (!game->tracers[index].active) {
			tracer = &game->tracers[index];
			break;
		}
		if (game->tracers[index].age > tracer->age) {
			tracer = &game->tracers[index];
		}
	}
	tracer->x0 = x0;
	tracer->y0 = y0;
	tracer->x1 = x1;
	tracer->y1 = y1;
	tracer->age = 0;
	tracer->active = 1;
}

/* ------------------------------------------------------------------ dropy */

static int should_force_heal(const GameState *game) {
	return game->hp <= HEAL_PITY_HP && game->kills_since_heal >= pity_kills[game->difficulty];
}

static void try_drop(GameState *game, long x, long y) {
	unsigned char kind;
	unsigned short index;
	int forced = should_force_heal(game);
	if (forced) {
		kind = GAME_PICKUP_HEAL;
	} else {
		unsigned short roll = (unsigned short)(mulu16(game_random(game), 1000) >> 16);
		if (roll < overdrive_chance[game->difficulty]) {
			kind = GAME_PICKUP_OVERDRIVE;
		} else if (roll < overdrive_chance[game->difficulty] + heal_chance[game->difficulty]) {
			kind = GAME_PICKUP_HEAL;
		} else {
			return;
		}
	}
	GamePickup *pickup = game->pickups;
	for (index = 0; index < GAME_MAX_PICKUPS; ++index, ++pickup) {
		if (pickup->active) {
			continue;
		}
		pickup->x = x;
		pickup->y = y;
		pickup->kind = kind;
		pickup->life = GAME_PICKUP_FRAMES;
		pickup->age = 0;
		pickup->active = 1;
		if (kind == GAME_PICKUP_HEAL) {
			game->kills_since_heal = 0;
			++game->heal_drops;
			if (forced) {
				++game->forced_heals;
			}
		} else {
			++game->overdrive_drops;
		}
		return;
	}
}

/* ------------------------------------------------------------------ director */

static void begin_break(GameState *game, short frames) {
	game->state = GAME_STATE_BREAK;
	game->break_timer = frames;
	game->wave_warned = 0;
	game->music_level = 0;
}

static void begin_wave(GameState *game) {
	unsigned short seconds;
	unsigned short target;
	unsigned short group;
	++game->wave;
	game->state = GAME_STATE_WAVE;
	seconds = 35 + (game->wave - 1) * 5;
	game->wave_frames = (seconds > 65 ? 65 : seconds) * GAME_FPS;
	target = 8 + (game->wave - 1) * 3;
	if (target > 45) {
		target = 45;
	}
	game->target_alive = target > GAME_MAX_ENEMIES ? GAME_MAX_ENEMIES : target;
	group = 2 + (game->wave - 1) / 3;
	game->spawn_group_size = group > 5 ? 5 : group;
	game->spawn_timer = 20;
	game->refill_remaining = 0;
	game->wave_second = game_wave_seconds(game);
	show_banner(game, 0);
	if (!game->wave_warned) {
		push_event(game, SFX_ID_WAVE_START, 256, VOL_M2DB);
	}
	game->music_level = (unsigned char)wave_music(game);
}

static void wave_cleared(GameState *game) {
	unsigned short bonus = game->wave * WAVE_BONUS;
	++game->completed_waves;
	game->score += bonus;
	show_banner(game, bonus);
	push_event(game, SFX_ID_WAVE_CLEAR, 256, VOL_0DB);
	begin_break(game, BREAK_FRAMES);
}

static void random_edge_position(GameState *game, unsigned short side, long *out_x, long *out_y) {
	long best_x = 0;
	long best_y = 0;
	long best_distance = -1;
	unsigned short attempt;
	for (attempt = 0; attempt < 8; ++attempt) {
		long x;
		long y;
		short dx;
		short dy;
		long distance;
		if (side == 0) {
			x = -SPAWN_X;
			y = random_range(game, -SPAWN_Y, SPAWN_Y);
		} else if (side == 1) {
			x = SPAWN_X;
			y = random_range(game, -SPAWN_Y, SPAWN_Y);
		} else if (side == 2) {
			x = random_range(game, -SPAWN_X, SPAWN_X);
			y = -SPAWN_Y;
		} else {
			x = random_range(game, -SPAWN_X, SPAWN_X);
			y = SPAWN_Y;
		}
		dx = (short)((x - game->player_x) >> 2);
		dy = (short)((y - game->player_y) >> 2);
		distance = muls16(dx, dx) + muls16(dy, dy);
		if (distance >= (MIN_SPAWN_DIST >> 2) * (MIN_SPAWN_DIST >> 2)) {
			*out_x = x;
			*out_y = y;
			return;
		}
		if (distance > best_distance) {
			best_distance = distance;
			best_x = x;
			best_y = y;
		}
	}
	*out_x = best_x;
	*out_y = best_y;
}

static int spawn_enemy(GameState *game, unsigned short side) {
	unsigned short index;
	GameEnemy *enemy = game->enemies;
	for (index = 0; index < GAME_MAX_ENEMIES; ++index, ++enemy) {
		unsigned short roll;
		unsigned long speed;
		if (enemy->active) {
			continue;
		}
		random_edge_position(game, side, &enemy->x, &enemy->y);
		speed = 4800UL + 230UL * (game->wave - 1);
		if (speed > 8000UL) {
			speed = 8000UL;
		}
		enemy->speed = (unsigned char)((speed * 1024UL + 25000UL) / 50000UL);
		roll = (unsigned short)(mulu16(game_random(game), 10000) >> 16);
		enemy->variant = roll < 7000 ? 0 : (roll < 9200 ? 1 : 2);
		enemy->points = variant_points[enemy->variant];
		enemy->anim = game_random(game) & 3;
		enemy->rotation = game_atan2(game->player_x - enemy->x, game->player_y - enemy->y);
		enemy->target_rotation = enemy->rotation;
		enemy->spawn = GAME_SPAWN_FRAMES;
		enemy->spawn_fresh = 1;
		enemy->active = 1;
		++game->alive;
		if (game->alive > game->max_alive_seen) {
			game->max_alive_seen = game->alive;
		}
		if (game->alive > game->target_alive || game->alive > GAME_MAX_ENEMIES) {
			game->director_violation = 1;
		}
		return 1;
	}
	return 0;
}

static unsigned short spawn_group(GameState *game, unsigned short count, unsigned short first_side) {
	unsigned short spawned = 0;
	unsigned short index;
	for (index = 0; index < count; ++index) {
		spawned += (unsigned short)spawn_enemy(game, (first_side + index) & 3);
	}
	return spawned;
}

static void spawn_refill_group(GameState *game) {
	unsigned short count = game->spawn_group_size < game->refill_remaining ? game->spawn_group_size : game->refill_remaining;
	unsigned short spawned = spawn_group(game, count, (game->refill_first_side + game->refill_group_index) & 3);
	game->refill_remaining = game->refill_remaining > spawned ? game->refill_remaining - spawned : 0;
	++game->refill_group_index;
	game->refill_burst_timer = REFILL_BURST;
}

static void start_refill(GameState *game) {
	game->refill_remaining = game->target_alive - game->alive;
	game->refill_first_side = game_random(game) & 3;
	game->refill_group_index = 0;
	spawn_refill_group(game);
}

static void update_director(GameState *game) {
	if (game->state == GAME_STATE_BREAK) {
		--game->break_timer;
		if (game->wave >= 4 && !game->wave_warned && game->break_timer <= 150) {
			push_event(game, SFX_ID_WAVE_START, 256, VOL_M2DB);
			game->wave_warned = 1;
		}
		if (game->break_timer <= 0) {
			begin_wave(game);
		}
	} else if (game->state == GAME_STATE_WAVE) {
		if (game->wave_frames > 0) {
			--game->wave_frames;
		}
		game->wave_second = game_wave_seconds(game);
		if (game->wave_frames > 0) {
			if (game->refill_remaining > 0) {
				if (--game->refill_burst_timer <= 0) {
					spawn_refill_group(game);
				}
			}
			--game->spawn_timer;
			if (game->refill_remaining == 0 && game->alive < game->target_alive && game->spawn_timer <= 0) {
				short interval = (short)(850 - (short)(game->wave - 1) * 40);
				start_refill(game);
				game->spawn_timer = (interval < 300 ? 300 : interval) / 20;
			}
		} else {
			game->refill_remaining = 0;
			if (game->alive == 0) {
				wave_cleared(game);
			}
		}
	}
}

/* ------------------------------------------------------------------ gracz i przeciwnicy */

static void player_died(GameState *game) {
	unsigned short index;
	game->state = GAME_STATE_OVER;
	for (index = 0; index < GAME_MAX_PICKUPS; ++index) {
		game->pickups[index].active = 0;
	}
	push_event(game, SFX_ID_GAME_OVER, 256, VOL_0DB);
	game->music_level = 0;
	game->shake = 25;
}

static int player_damage(GameState *game, short amount) {
	if (game->debug_invulnerable || game->dead || game->invulnerability > 0) {
		return 0;
	}
	game->hp = game->hp > amount ? game->hp - amount : 0;
	game->invulnerability = GAME_INVULN_FRAMES;
	game->blink = 0;
	game->flash = GAME_FLASH_FRAMES;
	push_event(game, SFX_ID_PLAYER_DAMAGE, 256, VOL_M3DB);
	if (game->hp == 0) {
		game->dead = 1;
		game->velocity_x = 0;
		game->velocity_y = 0;
		player_died(game);
	}
	return 1;
}

static void enemy_died(GameState *game, GameEnemy *enemy, int by_contact) {
	enemy->active = 0;
	game->alive = game->alive > 0 ? game->alive - 1 : 0;
	if (game->state == GAME_STATE_WAVE && game->wave_frames > 0 && game->alive < game->target_alive) {
		if (game->refill_remaining > 0) {
			game->refill_remaining = game->target_alive - game->alive;
		} else if (game->spawn_timer > REFILL_BURST) {
			game->spawn_timer = REFILL_BURST;
		}
	}
	spawn_explosion(game, enemy->x, enemy->y);
	if (by_contact) {
		push_event(game, SFX_ID_ENEMY_DIE, 205, VOL_M6DB);
		return;
	}
	game->score += (unsigned long)game->wave * enemy->points;
	++game->kills;
	++game->kills_since_heal;
	push_event(game, SFX_ID_ENEMY_DIE, random_pitch(game, 38), VOL_M2DB);
	if (game->shake < 6) {
		game->shake = 6;
	}
	try_drop(game, enemy->x, enemy->y);
}

static unsigned long isqrt(unsigned long value) {
	unsigned long result = 0;
	unsigned long bit = 1UL << 30;
	while (bit > value) {
		bit >>= 2;
	}
	while (bit != 0) {
		if (value >= result + bit) {
			value -= result + bit;
			result = (result >> 1) + bit;
		} else {
			result >>= 1;
		}
		bit >>= 2;
	}
	return result;
}

static void fire_weapon(GameState *game) {
	short dir_x = game_sin(game->aim);
	short dir_y = (short)-game_cos(game->aim);
	long best = 0x7fffffffL;
	GameEnemy *target = 0;
	long end_x;
	long end_y;
	long wall_t = 0x7fffffffL;
	unsigned short index;

	GameEnemy *enemy = game->enemies;
	for (index = 0; index < GAME_MAX_ENEMIES; ++index, ++enemy) {
		short rx;
		short ry;
		long along;
		long side;
		long hit;
		if (!enemy->active || enemy->spawn > 0) {
			continue;
		}
		rx = (short)((enemy->x - game->player_x) >> 2);
		ry = (short)((enemy->y - game->player_y) >> 2);
		along = (muls16(rx, dir_x) + muls16(ry, dir_y)) >> 12;
		if (along <= 0) {
			continue;
		}
		side = (muls16(rx, dir_y) - muls16(ry, dir_x)) >> 12;
		if (side < 0) {
			side = -side;
		}
		if (side >= HIT_RADIUS) {
			continue;
		}
		if (muls16(rx >> 2, rx >> 2) + muls16(ry >> 2, ry >> 2) < (HIT_RADIUS >> 4) * (HIT_RADIUS >> 4)) {
			continue;
		}
		hit = along - (long)isqrt((unsigned long)(HIT_RADIUS * HIT_RADIUS - side * side));
		if (hit < best) {
			best = hit;
			target = enemy;
		}
	}
	if (dir_x > 0) {
		wall_t = ((WALL_X - game->player_x) << 14) / dir_x;
	} else if (dir_x < 0) {
		wall_t = ((-WALL_X - game->player_x) << 14) / dir_x;
	}
	if (dir_y > 0) {
		long t = ((WALL_Y - game->player_y) << 14) / dir_y;
		if (t < wall_t) {
			wall_t = t;
		}
	} else if (dir_y < 0) {
		long t = ((-WALL_Y - game->player_y) << 14) / dir_y;
		if (t < wall_t) {
			wall_t = t;
		}
	}
	if (target == 0 || wall_t < best) {
		best = wall_t;
		target = 0;
	}
	end_x = game->player_x + (muls16((short)(best >> 2), dir_x) >> 12);
	end_y = game->player_y + (muls16((short)(best >> 2), dir_y) >> 12);
	spawn_tracer(game,
		game->player_x + (muls16(MUZZLE_OFFSET, dir_x) >> 14),
		game->player_y + (muls16(MUZZLE_OFFSET, dir_y) >> 14),
		end_x, end_y);
	game->muzzle = GAME_MUZZLE_FRAMES;
	if (game->shake < 1) {
		game->shake = 1;
	}
	push_event(game, SFX_ID_SHOT, random_pitch(game, 20), VOL_M4DB);
	if (target != 0) {
		push_event(game, SFX_ID_HIT, random_pitch(game, 26), VOL_M7DB);
		enemy_died(game, target, 0);
	}
}

static void set_overdrive_off(GameState *game) {
	push_event(game, SFX_ID_OVERDRIVE_OFF, 256, VOL_M4DB);
	game->music_level = game->state == GAME_STATE_WAVE ? (unsigned char)wave_music(game) : 0;
}

static void update_player(GameState *game, const GameInput *input) {
	long target_x;
	long target_y;
	if (game->dead) {
		return;
	}
	game->fire_timer -= 256;
	if (game->fire_timer < -4096) {
		game->fire_timer = -4096;
	}
	if (game->invulnerability > 0) {
		--game->invulnerability;
		++game->blink;
	}
	if (game->overdrive > 0 && --game->overdrive == 0) {
		set_overdrive_off(game);
	}

	if (input->move_x != 0 && input->move_y != 0) {
		target_x = input->move_x * PLAYER_DIAGONAL;
		target_y = input->move_y * PLAYER_DIAGONAL;
	} else {
		target_x = input->move_x * PLAYER_SPEED;
		target_y = input->move_y * PLAYER_SPEED;
	}
	game->velocity_x += muls16((short)(target_x - game->velocity_x), ACCEL_Q10) >> 10;
	game->velocity_y += muls16((short)(target_y - game->velocity_y), ACCEL_Q10) >> 10;
	if (game->velocity_x - target_x > -5 && game->velocity_x - target_x < 5) {
		game->velocity_x = target_x;
	}
	if (game->velocity_y - target_y > -5 && game->velocity_y - target_y < 5) {
		game->velocity_y = target_y;
	}
	game->player_x += game->velocity_x;
	game->player_y += game->velocity_y;
	if (game->player_x < -PLAYER_LIMIT_X || game->player_x > PLAYER_LIMIT_X) {
		game->player_x = game->player_x < 0 ? -PLAYER_LIMIT_X : PLAYER_LIMIT_X;
		game->velocity_x = 0;
	}
	if (game->player_y < -PLAYER_LIMIT_Y || game->player_y > PLAYER_LIMIT_Y) {
		game->player_y = game->player_y < 0 ? -PLAYER_LIMIT_Y : PLAYER_LIMIT_Y;
		game->velocity_y = 0;
	}
	game->moving = input->move_x != 0 || input->move_y != 0;
	game->anim = game->moving ? game->anim + 1 : 0;

	if (input->aim_valid) {
		long ax = input->aim_x < 0 ? -input->aim_x : input->aim_x;
		long ay = input->aim_y < 0 ? -input->aim_y : input->aim_y;
		if (ax > AIM_DEADZONE || ay > AIM_DEADZONE) {
			short target = game_atan2(input->aim_x, input->aim_y);
			short delta = (short)(((target - game->aim + 512) & 1023) - 512);
			short step = (short)(muls16(delta, AIM_Q10) >> 10);
			if (step == 0) {
				step = delta;
			}
			game->aim = (short)((game->aim + step) & 1023);
		}
	}

	if (input->fire && game->fire_timer <= 0) {
		game->fire_timer = game->overdrive > 0 ? FIRE_INTERVAL_OD_Q8 : FIRE_INTERVAL_Q8;
		fire_weapon(game);
	}
}

static void update_enemies(GameState *game) {
	unsigned short index;
	GameEnemy *enemy = game->enemies;
	for (index = 0; index < GAME_MAX_ENEMIES; ++index, ++enemy) {
		long dx;
		long dy;
		short delta;
		short step;
		if (!enemy->active) {
			continue;
		}
		if (enemy->spawn > 0) {
			--enemy->spawn;
			continue;
		}
		dx = game->player_x - enemy->x;
		dy = game->player_y - enemy->y;
		if (dx != 0 || dy != 0) {
			short angle;
			/* Kierunek do gracza przeliczany co czwarty krok (rozłożone na wrogów: 12,5 razy/s). */
			if (((index + (unsigned short)game->frame) & 3) == 0 || enemy->spawn_fresh) {
				enemy->target_rotation = game_atan2(dx, dy);
				enemy->spawn_fresh = 0;
			}
			angle = enemy->target_rotation;
			enemy->x += muls16(game_sin(angle), enemy->speed) >> 14;
			enemy->y -= muls16(game_cos(angle), enemy->speed) >> 14;
			delta = (short)(((angle - enemy->rotation + 512) & 1023) - 512);
			step = (short)(muls16(delta, TURN_Q10) >> 10);
			if (step == 0) {
				step = delta;
			}
			enemy->rotation = (short)((enemy->rotation + step) & 1023);
		}
		dx = game->player_x - enemy->x;
		dy = game->player_y - enemy->y;
		if (dx > -CONTACT_RANGE && dx < CONTACT_RANGE && dy > -CONTACT_RANGE && dy < CONTACT_RANGE) {
			short sx = (short)dx;
			short sy = (short)dy;
			if (muls16(sx, sx) + muls16(sy, sy) < CONTACT_RANGE * CONTACT_RANGE) {
				if (player_damage(game, CONTACT_DAMAGE)) {
					enemy_died(game, enemy, 1);
				}
				if (game->state == GAME_STATE_OVER) {
					return;
				}
			}
		}
	}
}

static void update_pickups(GameState *game) {
	unsigned short index;
	GamePickup *pickup = game->pickups;
	for (index = 0; index < GAME_MAX_PICKUPS; ++index, ++pickup) {
		long dx;
		long dy;
		if (!pickup->active) {
			continue;
		}
		++pickup->age;
		if (pickup->life == 0 || --pickup->life == 0) {
			pickup->active = 0;
			continue;
		}
		dx = game->player_x - pickup->x;
		dy = game->player_y - pickup->y;
		if (game->state == GAME_STATE_OVER || dx <= -PICKUP_RANGE || dx >= PICKUP_RANGE ||
			dy <= -PICKUP_RANGE || dy >= PICKUP_RANGE) {
			continue;
		}
		if (muls16((short)dx, (short)dx) + muls16((short)dy, (short)dy) >= PICKUP_RANGE * PICKUP_RANGE) {
			continue;
		}
		pickup->active = 0;
		if (pickup->kind == GAME_PICKUP_HEAL) {
			game->hp = game->hp + HEAL_AMOUNT > GAME_HP_MAX ? GAME_HP_MAX : game->hp + HEAL_AMOUNT;
			push_event(game, SFX_ID_PICKUP_HEAL, 256, VOL_M2DB);
		} else {
			game->overdrive = GAME_OVERDRIVE_FRAMES;
			game->music_level = 3;
			push_event(game, SFX_ID_PICKUP_OVERDRIVE, 256, VOL_M2DB);
		}
	}
}

static void update_effects(GameState *game) {
	unsigned short index;
	GameExplosion *explosion = game->explosions;
	GameTracer *tracer = game->tracers;
	for (index = 0; index < GAME_MAX_EXPLOSIONS; ++index, ++explosion) {
		if (explosion->active && ++explosion->age >= GAME_EXPLOSION_FRAMES) {
			explosion->active = 0;
		}
	}
	for (index = 0; index < GAME_MAX_TRACERS; ++index, ++tracer) {
		if (tracer->active && ++tracer->age >= GAME_TRACER_FRAMES) {
			tracer->active = 0;
		}
	}
	if (game->muzzle > 0) {
		--game->muzzle;
	}
	if (game->shake > 0) {
		--game->shake;
	}
	if (game->flash > 0) {
		--game->flash;
	}
	if (game->banner_frames > 0) {
		--game->banner_frames;
	}
}

unsigned long (*game_clock)(void);
unsigned long game_profile[5];

#define GAME_PROFILE(n) do { if (game_clock) { unsigned long now_ = game_clock(); game_profile[n] += now_ - mark_; mark_ = now_; } } while (0)

void game_step(GameState *game, const GameInput *input) {
	unsigned long mark_ = game_clock ? game_clock() : 0;
	++game->frame;
	if (game->state == GAME_STATE_OVER) {
		update_effects(game);
		return;
	}
	++game->run_frames;
	update_director(game);
	GAME_PROFILE(0);
	update_player(game, input);
	GAME_PROFILE(1);
	if (game->state != GAME_STATE_OVER) {
		update_enemies(game);
	}
	GAME_PROFILE(2);
	update_pickups(game);
	update_effects(game);
	GAME_PROFILE(3);
}

/* ------------------------------------------------------------------ autotest */

static void debug_control(GameState *game, GameInput *input, unsigned long frame) {
	static const signed char moves[4][2] = {{1, 0}, {0, -1}, {-1, 0}, {0, 1}};
	unsigned short phase = (unsigned short)((frame / 150) & 3);
	unsigned short index;
	input->move_x = moves[phase][0];
	input->move_y = moves[phase][1];
	input->fire = 0;
	input->aim_valid = 0;
	const GameEnemy *enemy = game->enemies;
	for (index = 0; index < GAME_MAX_ENEMIES; ++index, ++enemy) {
		if (enemy->active) {
			input->aim_x = enemy->x - game->player_x;
			input->aim_y = enemy->y - game->player_y;
			input->aim_valid = 1;
			input->fire = 1;
			break;
		}
	}
}

void game_autopilot(GameState *game, GameInput *input) {
	debug_control(game, input, game->frame);
}

int game_self_test(void) {
	static GameState game;
	GameInput input;
	unsigned short index;
	unsigned short counts[3] = {0, 0, 0};
	unsigned short difficulty;
	unsigned short first_wave_peak = 0;
	unsigned long frame;

	/* Obrażenia i niewrażliwość (balance self-test). */
	game_init(&game, GAME_DIFFICULTY_NORMAL, 31337);
	if (!player_damage(&game, CONTACT_DAMAGE) || game.hp != 82) {
		return 1;
	}
	if (player_damage(&game, CONTACT_DAMAGE) || game.hp != 82) {
		return 1;
	}
	game.invulnerability = 0;
	for (index = 0; index < 5; ++index) {
		game.invulnerability = 0;
		player_damage(&game, CONTACT_DAMAGE);
	}
	if (game.hp != 0 || !game.dead || game.state != GAME_STATE_OVER) {
		return 2;
	}

	/* Rozkład dropów dla trzech profili trudności. */
	for (difficulty = 0; difficulty < 3; ++difficulty) {
		unsigned short heals = 0;
		unsigned short overdrives = 0;
		game_init(&game, (unsigned char)difficulty, 8505 + difficulty);
		game.hp = 100;
		for (index = 0; index < 10000; ++index) {
			game.pickups[0].active = 0;
			game.heal_drops = 0;
			game.overdrive_drops = 0;
			try_drop(&game, 0, 0);
			heals += game.heal_drops;
			overdrives += game.overdrive_drops;
		}
		if (heals < heal_chance[difficulty] * 10 - 100 || heals > heal_chance[difficulty] * 10 + 100) {
			return 3;
		}
		if (overdrives < overdrive_chance[difficulty] * 10 - 100 || overdrives > overdrive_chance[difficulty] * 10 + 100) {
			return 3;
		}
		game.hp = HEAL_PITY_HP;
		game.kills_since_heal = pity_kills[difficulty] - 1;
		if (should_force_heal(&game)) {
			return 4;
		}
		game.kills_since_heal = pity_kills[difficulty];
		if (!should_force_heal(&game)) {
			return 4;
		}
	}

	/* Rozkład wariantów 70/22/8. */
	game_init(&game, GAME_DIFFICULTY_NORMAL, 9505);
	game.wave = 1;
	game.target_alive = GAME_MAX_ENEMIES;
	for (index = 0; index < 10000; ++index) {
		game.enemies[0].active = 0;
		game.alive = 0;
		spawn_enemy(&game, index & 3);
		++counts[game.enemies[0].variant];
	}
	if (counts[0] < 6900 || counts[0] > 7100 || counts[1] < 2100 || counts[1] > 2300 ||
		counts[2] < 700 || counts[2] > 900) {
		return 5;
	}

	/* Kąty: atan2 zgodny z tablicą sinusów. */
	if (game_atan2(0, -100) != 0 || game_atan2(100, 0) != 256 || game_atan2(0, 100) != 512 ||
		game_atan2(-100, 0) != 768) {
		return 6;
	}

	/* 50 s autotestu jak w main.gd. */
	game_init(&game, GAME_DIFFICULTY_NORMAL, 31337);
	game.debug_invulnerable = 1;
	for (frame = 0; frame < 50UL * GAME_FPS; ++frame) {
		debug_control(&game, &input, frame);
		game.event_count = 0;
		game_step(&game, &input);
		if (game.wave == 1 && game.alive > first_wave_peak) {
			first_wave_peak = game.alive;
		}
	}
	{
		unsigned short active = 0;
		for (index = 0; index < GAME_MAX_ENEMIES; ++index) {
			active += game.enemies[index].active;
		}
		if (game.wave < 2 || game.completed_waves < 1 || first_wave_peak != 8 || game.director_violation ||
			game.kills == 0 || active != game.alive || game.alive > game.target_alive) {
			return 7;
		}
		if (game.heal_drops + game.overdrive_drops == 0 || game.heal_drops + game.overdrive_drops > game.kills) {
			return 8;
		}
	}
	return 0;
}
