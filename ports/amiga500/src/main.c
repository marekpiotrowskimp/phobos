#include "assets_load.h"
#include "audio.h"
#include "debug.h"
#include "fastmath.h"
#include "game.h"
#include "hw.h"
#include "render.h"
#include "scores.h"
#include "text.h"
#include "../assets/generated/assets.h"

#include <dos/dos.h>
#include <exec/memory.h>
#include <proto/dos.h>
#include <proto/exec.h>
#include <proto/graphics.h>
#include <string.h>

#define KEY_W 0x11
#define KEY_A 0x20
#define KEY_S 0x21
#define KEY_D 0x22
#define KEY_UP 0x4c
#define KEY_DOWN 0x4d
#define KEY_RIGHT 0x4e
#define KEY_LEFT 0x4f
#define KEY_RETURN 0x44
#define KEY_ENTER 0x43
#define KEY_ESC 0x45
#define KEY_SPACE 0x40
#define KEY_M 0x37

#define SCREEN_MENU 0
#define SCREEN_GAME 1
#define SCREEN_INITIALS 2
#define SCREEN_RESULTS 3

static const char *const difficulty_labels[3] = {"ŁATWY", "NORMALNY", "TRUDNY"};

typedef struct {
	UBYTE screen;
	UBYTE menu_index;
	UBYTE results_filter;      /* 0 = wszystkie, 1..3 = łatwy..trudny */
	UBYTE results_from_run;
	UBYTE initials_cursor;
	UBYTE paused;
	UBYTE mouse_aim;
	UBYTE settings_dirty;
	UBYTE save_failed;
	UBYTE redraw;
	UBYTE running;
	UBYTE demo;
	UBYTE prev_fire;
	UBYTE prev_mouse;
	BYTE prev_joy_x;
	BYTE prev_joy_y;
	WORD crosshair_x;
	WORD crosshair_y;
	char initials[4];
	ScoreEntry pending;
	UBYTE pending_difficulty;
	UWORD fps;
} App;

typedef struct {
	UBYTE up;
	UBYTE down;
	UBYTE left;
	UBYTE right;
	UBYTE confirm;
	UBYTE back;
} MenuKeys;

static App app;
static GameState game;
static ScoresData scores;
static HwInput input;
static RenderScreen screen_text;

static const char self_test_ok[] = "PHOBOS A500 STAGE5 OK\n";
static char self_test_failed[] = "PHOBOS A500 STAGE5 FAILED: 0\n";

static void write_output(const char *text, unsigned long length) {
	BPTR stream = Output();
	if (stream != 0) {
		Write(stream, (APTR)text, length);
	}
}

/* ------------------------------------------------------------------ zapis */

static void save_scores(void) {
	if (app.demo && app.demo != 3) {
		app.settings_dirty = 0;
		return;
	}
	hw_disown_blitter();
	app.save_failed = !scores_save(&scores);
	hw_own_blitter();
	app.settings_dirty = 0;
}

/* ------------------------------------------------------------------ wejście */

static MenuKeys menu_keys(void) {
	MenuKeys keys;
	UBYTE fire = input.joy_fire;
	keys.up = hw_key_pressed(&input, KEY_UP) || (input.joy_y < 0 && app.prev_joy_y >= 0);
	keys.down = hw_key_pressed(&input, KEY_DOWN) || (input.joy_y > 0 && app.prev_joy_y <= 0);
	keys.left = hw_key_pressed(&input, KEY_LEFT) || (input.joy_x < 0 && app.prev_joy_x >= 0);
	keys.right = hw_key_pressed(&input, KEY_RIGHT) || (input.joy_x > 0 && app.prev_joy_x <= 0);
	keys.confirm = hw_key_pressed(&input, KEY_RETURN) || hw_key_pressed(&input, KEY_ENTER) ||
		(fire && !app.prev_fire) || (input.mouse_button && !app.prev_mouse);
	keys.back = hw_key_pressed(&input, KEY_ESC);
	return keys;
}

static MenuKeys menu_keys_wasd(void) {
	MenuKeys keys = menu_keys();
	keys.up |= hw_key_pressed(&input, KEY_W);
	keys.down |= hw_key_pressed(&input, KEY_S);
	keys.left |= hw_key_pressed(&input, KEY_A);
	keys.right |= hw_key_pressed(&input, KEY_D);
	return keys;
}

static signed char raw_key_letter(UBYTE key) {
	static const UBYTE keys[26] = {
		0x20, 0x35, 0x33, 0x22, 0x12, 0x23, 0x24, 0x25, 0x17, 0x26, 0x27, 0x28,
		0x37, 0x36, 0x18, 0x19, 0x10, 0x13, 0x21, 0x14, 0x16, 0x34, 0x11, 0x32,
		0x15, 0x31
	};
	UWORD index;
	for (index = 0; index < 26; ++index) {
		if (keys[index] == key) {
			return (signed char)('A' + index);
		}
	}
	return -1;
}

static void build_game_input(GameInput *game_input) {
	BYTE ax = (BYTE)(input.keys[KEY_RIGHT] - input.keys[KEY_LEFT]);
	BYTE ay = (BYTE)(input.keys[KEY_DOWN] - input.keys[KEY_UP]);
	memset(game_input, 0, sizeof(*game_input));
	game_input->move_x = (signed char)((input.keys[KEY_D] || input.joy_x > 0) - (input.keys[KEY_A] || input.joy_x < 0));
	game_input->move_y = (signed char)((input.keys[KEY_S] || input.joy_y > 0) - (input.keys[KEY_W] || input.joy_y < 0));
	if (input.mouse_moved) {
		app.mouse_aim = 1;
	}
	app.crosshair_x += input.mouse_dx;
	app.crosshair_y += input.mouse_dy;
	if (app.crosshair_x < 0) {
		app.crosshair_x = 0;
	} else if (app.crosshair_x > 319) {
		app.crosshair_x = 319;
	}
	if (app.crosshair_y < HW_ARENA_LINE) {
		app.crosshair_y = HW_ARENA_LINE;
	} else if (app.crosshair_y > HW_ARENA_LINE + HW_ARENA_VISIBLE - 1) {
		app.crosshair_y = HW_ARENA_LINE + HW_ARENA_VISIBLE - 1;
	}
	if (ax != 0 || ay != 0) {
		/* Celowanie kursorami (tryb joysticka): kierunek + ciągły ogień. */
		app.mouse_aim = 0;
		game_input->aim_valid = 1;
		game_input->aim_x = ax * 1024L;
		game_input->aim_y = ay * 1024L;
		game_input->fire = 1;
	} else if (app.mouse_aim) {
		game_input->aim_valid = 1;
		game_input->aim_x = render_screen_to_world_x(app.crosshair_x) - game.player_x;
		game_input->aim_y = render_screen_to_world_y(app.crosshair_y) - game.player_y;
	}
	game_input->fire |= input.mouse_button || input.keys[KEY_SPACE] || input.joy_fire;
}

/* ------------------------------------------------------------------ ekrany */

static void show_menu(void) {
	app.screen = SCREEN_MENU;
	app.redraw = 1;
}

static void start_run(void) {
	ULONG seed = app.demo ? 31337UL : (hw_vblank.count * 2654435761UL) ^ ((ULONG)hw_raster_line() << 16) ^ 0x9e3779b9UL;
	if (app.settings_dirty) {
		save_scores();
	}
	assets_music_finish();
	game_init(&game, scores.selected_difficulty, seed);
	game.debug_invulnerable = app.demo;
	app.screen = SCREEN_GAME;
	app.paused = 0;
	app.crosshair_x = 160 + 40;
	app.crosshair_y = HW_ARENA_LINE + 100;
	render_reset_game();
	audio_set_music(0);
	audio_duck_music(0);
}

static void show_results(UBYTE from_run) {
	app.screen = SCREEN_RESULTS;
	app.results_from_run = from_run;
	app.redraw = 1;
}

static void player_died(void) {
	memcpy(app.pending.initials, scores.last_initials, 4);
	app.pending.score = game.score;
	app.pending.wave = game.wave;
	app.pending.kills = game.kills;
	app.pending.seconds = (UWORD)(game.run_frames / GAME_FPS);
	app.pending_difficulty = game.difficulty;
	if (scores_qualifies(&scores, game.difficulty, &app.pending)) {
		memcpy(app.initials, scores.last_initials, 4);
		app.initials_cursor = 0;
		app.screen = SCREEN_INITIALS;
		app.redraw = 1;
	} else {
		show_results(1);
	}
}

static void submit_initials(void) {
	memcpy(app.pending.initials, app.initials, 3);
	app.pending.initials[3] = 0;
	scores_submit(&scores, app.pending_difficulty, &app.pending);
	save_scores();
	app.results_filter = app.pending_difficulty + 1;
	show_results(1);
}

static void set_line(UBYTE index, const char *text, UBYTE color) {
	strcpy(screen_text.lines[index], text);
	screen_text.colors[index] = color;
}

static void build_menu_screen(void) {
	static const char *const items[4] = {"GRAJ", 0, "WYNIKI", "WYJŚCIE"};
	UBYTE index;
	memset(&screen_text, 0, sizeof(screen_text));
	strcpy(screen_text.title, "PHOBOS");
	screen_text.big_line = 0xff;
	for (index = 0; index < 4; ++index) {
		char label[RENDER_LINE_MAX];
		char line[RENDER_LINE_MAX];
		char *out;
		if (index == 1) {
			out = str_append(label, "TRUDNOŚĆ: < ");
			out = str_append(out, difficulty_labels[scores.selected_difficulty]);
			str_append(out, " >");
		} else {
			strcpy(label, items[index]);
		}
		out = str_append(line, index == app.menu_index ? ">  " : "   ");
		out = str_append(out, label);
		str_append(out, index == app.menu_index ? "  <" : "   ");
		set_line(index * 2, line, index == app.menu_index ? 4 : 2);
		if (index < 3) {
			set_line(index * 2 + 1, "", 2);
		}
	}
	screen_text.count = 7;
	if (app.save_failed) {
		set_line(7, "", 2);
		set_line(8, "BRAK ZAPISU: DYSK ZABEZPIECZONY LUB BŁĄD", 6);
		screen_text.count = 9;
	}
	strcpy(screen_text.hint[0], "STRZAŁKI / JOYSTICK  •  ENTER / FIRE");
	strcpy(screen_text.hint[1], "GRA: WSAD/JOY RUCH  •  MYSZ/STRZAŁKI CEL  •  LPM/SPACJA OGIEŃ");
}

static void build_initials_screen(void) {
	char line[RENDER_LINE_MAX];
	char *out;
	UBYTE index;
	memset(&screen_text, 0, sizeof(screen_text));
	strcpy(screen_text.title, "WPISZ INICJAŁY");
	out = str_append(line, "NOWY WYNIK: ");
	str_number(out, app.pending.score, 1);
	set_line(0, line, 4);
	out = str_append(line, "POZIOM: ");
	out = str_append(out, difficulty_labels[app.pending_difficulty]);
	out = str_append(out, "  •  FALA: ");
	out = str_number(out, app.pending.wave, 1);
	out = str_append(out, "  •  ZABICIA: ");
	str_number(out, app.pending.kills, 1);
	set_line(1, line, 2);
	set_line(2, "", 2);
	out = line;
	for (index = 0; index < 3; ++index) {
		if (index > 0) {
			out = str_append(out, "   ");
		}
		*out++ = index == app.initials_cursor ? '[' : ' ';
		*out++ = app.initials[index];
		*out++ = index == app.initials_cursor ? ']' : ' ';
		*out = 0;
	}
	set_line(3, line, 4);
	screen_text.big_line = 3;
	screen_text.count = 4;
	strcpy(screen_text.hint[0], "GÓRA/DÓŁ: LITERA  •  LEWO/PRAWO: POZYCJA");
	strcpy(screen_text.hint[1], "LITERY Z KLAWIATURY  •  ENTER / FIRE: DALEJ");
}

static void build_results_screen(void) {
	static ScoreEntry entries[10];
	static UBYTE entry_difficulty[10];
	char line[RENDER_LINE_MAX];
	char *out;
	UBYTE count;
	UBYTE index;
	UBYTE row = 0;
	memset(&screen_text, 0, sizeof(screen_text));
	strcpy(screen_text.title, "WYNIKI");
	screen_text.big_line = 0xff;
	if (app.results_from_run) {
		out = str_append(line, "OSTATNI WYNIK: ");
		out = str_number(out, app.pending.score, 1);
		out = str_append(out, "  •  ");
		out = str_append(out, difficulty_labels[app.pending_difficulty]);
		out = str_append(out, "  •  FALA ");
		out = str_number(out, app.pending.wave, 1);
		out = str_append(out, "  •  ");
		out = str_number(out, app.pending.seconds / 60, 2);
		out = str_append(out, ":");
		str_number(out, app.pending.seconds % 60, 2);
		set_line(row++, line, 4);
		set_line(row++, "", 2);
	}
	out = str_append(line, "TOP 10  •  < ");
	out = str_append(out, app.results_filter == 0 ? "WSZYSTKIE" : difficulty_labels[app.results_filter - 1]);
	str_append(out, " >");
	set_line(row++, line, 1);
	screen_text.table = 1;
	screen_text.table_first = row;
	set_line(row++, "LP\tGRACZ\tWYNIK\tPOZIOM\tFALA\tCZAS", 3);
	count = scores_collect(&scores, app.results_filter == 0 ? SCORES_ALL : app.results_filter - 1,
		entries, entry_difficulty, 10);
	for (index = 0; index < count; ++index) {
		out = str_number(line, index + 1, 1);
		out = str_append(out, "\t");
		out = str_append(out, entries[index].initials);
		out = str_append(out, "\t");
		out = str_number(out, entries[index].score, 1);
		out = str_append(out, "\t");
		out = str_append(out, difficulty_labels[entry_difficulty[index]]);
		out = str_append(out, "\t");
		out = str_number(out, entries[index].wave, 1);
		out = str_append(out, "\t");
		out = str_number(out, entries[index].seconds / 60, 2);
		out = str_append(out, ":");
		str_number(out, entries[index].seconds % 60, 2);
		set_line(row++, line, 2);
	}
	screen_text.table_end = row;
	if (count == 0) {
		set_line(row++, "", 2);
		set_line(row++, "BRAK ZAPISANYCH WYNIKÓW", 5);
	}
	if (app.save_failed && row < 15) {
		set_line(row++, "", 2);
		set_line(row++, "BRAK ZAPISU: DYSK ZABEZPIECZONY LUB BŁĄD", 6);
	}
	screen_text.count = row;
	strcpy(screen_text.hint[0], "LEWO/PRAWO: FILTR");
	strcpy(screen_text.hint[1], app.results_from_run ? "ENTER / FIRE: JESZCZE RAZ  •  ESC: MENU" : "ENTER / ESC: MENU");
}

static void update_menu(void) {
	MenuKeys keys = menu_keys_wasd();
	if (keys.up) {
		app.menu_index = (UBYTE)((app.menu_index + 3) & 3);
		app.redraw = 1;
	} else if (keys.down) {
		app.menu_index = (UBYTE)((app.menu_index + 1) & 3);
		app.redraw = 1;
	} else if ((keys.left || keys.right) && app.menu_index == 1) {
		scores.selected_difficulty = (UBYTE)((scores.selected_difficulty + (keys.left ? 2 : 1)) % 3);
		app.settings_dirty = 1;
		app.redraw = 1;
	} else if (keys.confirm) {
		if (app.menu_index == 0) {
			start_run();
		} else if (app.menu_index == 1) {
			scores.selected_difficulty = (UBYTE)((scores.selected_difficulty + 1) % 3);
			app.settings_dirty = 1;
			app.redraw = 1;
		} else if (app.menu_index == 2) {
			if (app.settings_dirty) {
				save_scores();
			}
			app.results_filter = 0;
			show_results(0);
		} else {
			if (app.settings_dirty) {
				save_scores();
			}
			app.running = 0;
		}
	}
}

static void update_initials(void) {
	MenuKeys keys = menu_keys();
	UBYTE index;
	for (index = 0; index < input.pressed_count; ++index) {
		signed char letter = raw_key_letter(input.pressed[index]);
		if (letter > 0) {
			app.initials[app.initials_cursor] = letter;
			if (app.initials_cursor < 2) {
				++app.initials_cursor;
			}
			app.redraw = 1;
			return;
		}
	}
	if (keys.left) {
		app.initials_cursor = (UBYTE)((app.initials_cursor + 2) % 3);
	} else if (keys.right) {
		app.initials_cursor = (UBYTE)((app.initials_cursor + 1) % 3);
	} else if (keys.up) {
		app.initials[app.initials_cursor] = app.initials[app.initials_cursor] == 'Z' ? 'A' : app.initials[app.initials_cursor] + 1;
	} else if (keys.down) {
		app.initials[app.initials_cursor] = app.initials[app.initials_cursor] == 'A' ? 'Z' : app.initials[app.initials_cursor] - 1;
	} else if (keys.confirm) {
		if (app.initials_cursor < 2) {
			++app.initials_cursor;
		} else {
			submit_initials();
			return;
		}
	} else {
		return;
	}
	app.redraw = 1;
}

static void update_results(void) {
	MenuKeys keys = menu_keys_wasd();
	if (keys.left) {
		app.results_filter = (UBYTE)((app.results_filter + 3) & 3);
		app.redraw = 1;
	} else if (keys.right) {
		app.results_filter = (UBYTE)((app.results_filter + 1) & 3);
		app.redraw = 1;
	} else if (keys.confirm) {
		if (app.results_from_run) {
			start_run();
		} else {
			show_menu();
		}
	} else if (keys.back) {
		show_menu();
	}
}

static void play_events(void) {
	UBYTE index;
	for (index = 0; index < game.event_count; ++index) {
		audio_play(game.events[index].sfx, game.events[index].pitch, game.events[index].volume);
	}
	game.event_count = 0;
	audio_set_music(game.music_level);
	audio_duck_music(game.hp * 10 < GAME_HP_MAX * 3);
}

static void update_game(UWORD steps) {
	GameInput game_input;
	if (hw_key_pressed(&input, KEY_ESC) && game.state != GAME_STATE_OVER) {
		app.paused = !app.paused;
	}
	if (app.paused) {
		return;
	}
	build_game_input(&game_input);
	while (steps-- > 0) {
		if (app.demo) {
			game_autopilot(&game, &game_input);
		}
		game_step(&game, &game_input);
		if (game.state == GAME_STATE_OVER) {
			break;
		}
	}
	play_events();
	if (game.state == GAME_STATE_OVER) {
		player_died();
	}
}

/* ------------------------------------------------------------------ tryb demo (diagnostyka) */

typedef struct {
	ULONG frames;
	UWORD max_lines;
	UWORD min_fps;
	ULONG fps_sum;
	UWORD fps_samples;
	UWORD max_alive;
	ULONG phase[4];
	ULONG phase_frames;
} DemoStats;

static DemoStats demo;
extern ULONG render_profile[8];
extern volatile ULONG audio_irq_count;
extern unsigned long (*game_clock)(void);
extern unsigned long game_profile[5];
static ULONG beam_now(void);

static ULONG beam_now(void) {
	return mulu16((UWORD)hw_vblank.count, 313) + hw_raster_line();
}

static void demo_dump(const char *name, UWORD front) {
	HwBuffer *buffer = &hw_buffers[front];
	WORD index;
	hw_blit_wait();
	debug_dump_begin(name);
	debug_value("asset", (long)hw_asset_chip);
	debug_text("\n");
	debug_dump_block(hw_asset_chip, 0);
	debug_dump_block(buffer->copper, 1024);
	if (app.screen == SCREEN_GAME) {
		debug_dump_block(buffer->arena, HW_ARENA_BYTES);
		debug_dump_block(buffer->hud_top, HW_HUD_TOP_BYTES);
		debug_dump_block(buffer->hud_bottom, HW_HUD_BOTTOM_BYTES);
		for (index = 0; index < 4; ++index) {
			debug_dump_block(buffer->sprite_player[index], HW_SPRITE_PLAYER_WORDS * 2);
		}
		debug_dump_block(buffer->sprite_cross, HW_SPRITE_CROSS_WORDS * 2);
		debug_dump_block(buffer->sprite_muzzle, HW_SPRITE_MUZZLE_WORDS * 2);
	} else {
		debug_dump_block(hw_menu, HW_MENU_BYTES);
	}
	debug_dump_block(hw_sprite_empty, 8);
	debug_dump_end();
}

static void demo_script(ULONG frame, UWORD front) {
	ULONG second = frame / 50;
	if (frame == 40) {
		demo_dump("menu", front);
		app.menu_index = 0;
		start_run();
		return;
	}
	if (app.screen == SCREEN_GAME) {
		if (frame % 50 == 0) {
			debug_text("T");
			debug_number((long)second);
			debug_text(" ");
			debug_value("wave", game.wave);
			debug_value("alive", game.alive);
			debug_value("fps", app.fps);
			debug_value("lines", demo.max_lines);
			debug_value("kills", game.kills);
			debug_value("score", (long)game.score);
			debug_value("hp", game.hp);
			debug_value("upd", (long)(demo.phase[0] / (demo.phase_frames ? demo.phase_frames : 1)));
			debug_value("rnd", (long)(demo.phase[1] / (demo.phase_frames ? demo.phase_frames : 1)));
			debug_value("wait", (long)(demo.phase[2] / (demo.phase_frames ? demo.phase_frames : 1)));
			{
				WORD p;
				debug_text("prof:");
				for (p = 0; p < 8; ++p) {
					debug_number((long)(render_profile[p] / (demo.phase_frames ? demo.phase_frames : 1)));
					debug_text(",");
					render_profile[p] = 0;
				}
				debug_text(" game:");
				for (p = 0; p < 4; ++p) {
					debug_number((long)(game_profile[p] / (demo.phase_frames ? demo.phase_frames : 1)));
					debug_text(",");
					game_profile[p] = 0;
				}
			}
			debug_text("\n");
			demo.phase[0] = demo.phase[1] = demo.phase[2] = 0;
			demo.phase_frames = 0;
			if (second > 6) {
				if (app.fps < demo.min_fps) {
					demo.min_fps = app.fps;
				}
				demo.fps_sum += app.fps;
				++demo.fps_samples;
			}
			demo.max_lines = 0;
		}
		if (game.alive > demo.max_alive) {
			demo.max_alive = game.alive;
		}
		if (frame == 50 * 5) {
			demo_dump("game_spawn", front);
		} else if (frame == 50 * 24) {
			demo_dump("game_wave", front);
		} else if (frame == 50 * 26) {
			app.paused = 1;
		} else if (frame == 50 * 27) {
			demo_dump("game_pause", front);
			app.paused = 0;
		} else if (second >= 120 && game.debug_invulnerable) {
			game.debug_invulnerable = 0;
		}
	} else if (app.screen == SCREEN_INITIALS && app.demo != 2) {
		demo_dump("initials", front);
		app.demo = 2;
		strcpy(app.initials, "DMO");
		app.initials_cursor = 2;
		submit_initials();
	} else if (app.screen == SCREEN_RESULTS && app.demo == 2) {
		demo_dump("results", front);
		app.demo = 3;
		save_scores();
		app.demo = 2;
		debug_value("save_ok", !app.save_failed);
		debug_value("RESULT min_fps", demo.min_fps);
		debug_value("avg_fps", demo.fps_samples ? (long)(demo.fps_sum / demo.fps_samples) : 0);
		debug_value("max_alive", demo.max_alive);
		debug_value("chip_free", (long)AvailMem(MEMF_CHIP));
		debug_value("chip_largest", (long)AvailMem(MEMF_CHIP | MEMF_LARGEST));
		debug_value("any_free", (long)AvailMem(MEMF_ANY));
		debug_text("\n@@DONE\n");
		app.running = 0;
	} else if (app.screen == SCREEN_RESULTS) {
		app.demo = 2;
	}
}

/* ------------------------------------------------------------------ pętla */

static int run(UBYTE demo_mode) {
	UWORD back = 0;
	ULONG last_logic;
	ULONG fps_mark;
	UWORD fps_frames = 0;
	ULONG frame = 0;
	ULONG last_flip = 0;

	if (!assets_load()) {
		return 20;
	}

	if (!hw_open()) {
		assets_free();
		return 20;
	}
	memset(&app, 0, sizeof(app));
	app.demo = demo_mode;
	app.running = 1;
	app.redraw = 1;
	app.menu_index = 0;
	demo.min_fps = 0xffff;
	if (demo_mode) {
		debug_init();
		debug_text("\nPHOBOS DEMO START\n");

		game_clock = (unsigned long (*)(void))beam_now;
		scores_init(&scores);
	} else {
		scores_load(&scores);
	}
	audio_init();
	hw_take_display();
	hw_own_blitter();
	render_init();
	show_menu();
	last_logic = hw_vblank.count;
	fps_mark = hw_vblank.count;

	while (app.running) {
		ULONG now;
		UWORD steps;
		UWORD *copper;
		UWORD render_start_line;
		ULONG render_start_count;

		hw_read_input(&input);
		now = hw_vblank.count;
		steps = (UWORD)(now - last_logic);
		if (steps < 1) {
			steps = 1;
		} else if (steps > 4) {
			steps = 4;
		}
		last_logic = now;
		if (hw_key_pressed(&input, KEY_M)) {
			audio_toggle_mute();
		}
		{
			UWORD tick;
			for (tick = 0; tick < steps; ++tick) {
				audio_update();
			}
		}
		{
			ULONG elapsed = now - fps_mark;
			if (elapsed >= 25) {
				app.fps = (UWORD)((fps_frames * 50UL + elapsed / 2) / elapsed);
				fps_mark = now;
				fps_frames = 0;
			}
		}

		render_start_count = hw_vblank.count;
		render_start_line = hw_raster_line();
		demo.phase[0] -= beam_now();
		if (app.screen == SCREEN_MENU) {
			assets_music_step();
			update_menu();
		} else if (app.screen == SCREEN_GAME) {
			update_game(steps);
		} else if (app.screen == SCREEN_INITIALS) {
			update_initials();
		} else {
			update_results();
		}
		app.prev_fire = input.joy_fire;
		app.prev_mouse = input.mouse_button;
		app.prev_joy_x = input.joy_x;
		app.prev_joy_y = input.joy_y;
		if (!app.running) {
			break;
		}
		demo.phase[0] += beam_now();
		demo.phase[1] -= beam_now();

		if (app.screen == SCREEN_GAME) {
			RenderView view;
			view.difficulty = difficulty_labels[game.difficulty];
			view.fps = app.fps;
			view.paused = app.paused;
			view.crosshair_visible = app.mouse_aim;
			view.crosshair_x = app.crosshair_x;
			view.crosshair_y = app.crosshair_y;
			copper = render_game(back, &game, &view);
		} else {
			UBYTE redraw = app.redraw;
			if (redraw) {
				if (app.screen == SCREEN_MENU) {
					build_menu_screen();
				} else if (app.screen == SCREEN_INITIALS) {
					build_initials_screen();
				} else {
					build_results_screen();
				}
				app.redraw = 0;
			}
			copper = render_menu(back, &screen_text, redraw);
		}
		if (app.demo) {
			ULONG lines = (hw_vblank.count - render_start_count) * 313UL + hw_raster_line();
			lines = lines > render_start_line ? lines - render_start_line : 0;
			if (lines > demo.max_lines) {
				demo.max_lines = (UWORD)(lines > 0xffff ? 0xffff : lines);
			}
		}
		demo.phase[1] += beam_now();
		if (app.screen == SCREEN_GAME) {
			/* Stałe 25 kl./s w grze: obraz zmienia się co drugi VBlank, logika 2 × 50 Hz. */
			while (hw_vblank.count - last_flip < 1) {
				WaitTOF();
			}
		}
		hw_flip(copper);
		demo.phase[2] -= beam_now();
		hw_wait_flip();
		last_flip = hw_vblank.count;
		demo.phase[2] += beam_now();
		++demo.phase_frames;
		++fps_frames;
		if (app.demo) {
			demo_script(frame, back);
		}
		back ^= 1;
		++frame;
	}

	audio_shutdown();
	hw_disown_blitter();
	hw_release_display();
	hw_close();
	assets_free();
	return 0;
}

int main(int argc, char **argv) {
	int result;
	if (argc == 2 && strcmp(argv[1], "--self-test") == 0) {
		result = game_self_test();
		if (result == 0) {
			result = scores_self_test();
			if (result != 0) {
				result += 10;
			}
		}
		if (result == 0) {
			write_output(self_test_ok, sizeof(self_test_ok) - 1);
		} else {
			self_test_failed[27] = (char)('0' + result % 10);
			self_test_failed[26] = (char)('0' + result / 10);
			write_output(self_test_failed, sizeof(self_test_failed) - 1);
		}
		return result;
	}
	return run(argc == 2 && strcmp(argv[1], "--demo") == 0);
}
