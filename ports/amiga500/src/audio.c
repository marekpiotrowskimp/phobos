#include "audio.h"
#include "hw.h"
#include "assets_load.h"
#include "../assets/generated/assets.h"

#include <devices/audio.h>
#include <exec/interrupts.h>
#include <exec/memory.h>
#include <hardware/custom.h>
#include <hardware/dmabits.h>
#include <hardware/intbits.h>
#include <proto/alib.h>
#include <proto/exec.h>
#include <string.h>

#define HW_CUSTOM ((volatile struct Custom *)0xdff000)
#define MUSIC_VOLUME 32
#define MUSIC_DUCKED 14
#define FADE_STEP 32

extern void audio_irq(void);

typedef struct {
	UWORD frames_left;
	UBYTE priority;
	UBYTE latch_pending;
} SfxChannel;

static BYTE music_buffers[2][ASSET_MUSIC_BUFFER] __attribute__((section(".bsschip"), aligned(8)));
static struct MsgPort *audio_port;
static struct IOAudio *audio_request;
static UBYTE audio_open;
static struct Interrupt music_interrupt;
static struct Interrupt *old_interrupt;
static UBYTE music_running;
static volatile UWORD music_level;
static volatile UWORD music_target;
static volatile UWORD music_from;
static volatile UWORD music_fade = 256;
static volatile ULONG music_pos;
static volatile UBYTE music_next;
static UBYTE muted;
static UBYTE ducked;
static SfxChannel channels[4];

static const UBYTE sfx_priority[ASSET_SFX_COUNT] = {0, 0, 1, 3, 4, 4, 3, 5, 5, 6};

static void fill_music(BYTE *target) {
	const BYTE *layer = asset_music_data + (ULONG)music_level * ASSET_MUSIC_LAYER_LENGTH;
	ULONG pos = music_pos;
	UWORD index;
	if (music_fade >= 256) {
		for (index = 0; index < ASSET_MUSIC_BUFFER; ++index) {
			target[index] = layer[pos];
			if (++pos >= ASSET_MUSIC_LAYER_LENGTH) {
				pos = 0;
			}
		}
	} else {
		const BYTE *from = asset_music_data + (ULONG)music_from * ASSET_MUSIC_LAYER_LENGTH;
		WORD weight = music_fade;
		for (index = 0; index < ASSET_MUSIC_BUFFER; ++index) {
			target[index] = (BYTE)((layer[pos] * weight + from[pos] * (256 - weight)) >> 8);
			if (++pos >= ASSET_MUSIC_LAYER_LENGTH) {
				pos = 0;
			}
		}
		music_fade += FADE_STEP;
	}
	music_pos = pos;
}

volatile ULONG audio_irq_count;

void audio_irq_handler(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	++audio_irq_count;
	BYTE *target = music_buffers[music_next];
	if (music_target != music_level) {
		music_from = music_level;
		music_level = music_target;
		music_fade = 0;
	}
	fill_music(target);
	custom->aud[0].ac_ptr = (UWORD *)target;
	custom->aud[1].ac_ptr = (UWORD *)target;
	music_next ^= 1;
}

static void wait_lines(UWORD count) {
	while (count-- > 0) {
		UWORD line = hw_raster_line();
		while (hw_raster_line() == line) {
		}
	}
}

int audio_init(void) {
	static UBYTE allocation = 0x0f;
	volatile struct Custom *custom = HW_CUSTOM;
	memset(channels, 0, sizeof(channels));
	audio_port = CreatePort(0, 0);
	if (audio_port == 0) {
		return 0;
	}
	audio_request = (struct IOAudio *)CreateExtIO(audio_port, sizeof(struct IOAudio));
	if (audio_request == 0) {
		audio_shutdown();
		return 0;
	}
	audio_request->ioa_Request.io_Message.mn_Node.ln_Pri = 127;
	audio_request->ioa_Data = &allocation;
	audio_request->ioa_Length = 1;
	if (OpenDevice((STRPTR)AUDIONAME, 0, (struct IORequest *)audio_request, 0) != 0) {
		audio_shutdown();
		return 0;
	}
	audio_open = 1;

	custom->dmacon = DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;
	custom->intena = INTF_AUD0 | INTF_AUD1 | INTF_AUD2 | INTF_AUD3;
	custom->intreq = INTF_AUD0 | INTF_AUD1 | INTF_AUD2 | INTF_AUD3;
	memset(&music_interrupt, 0, sizeof(music_interrupt));
	music_interrupt.is_Node.ln_Type = NT_INTERRUPT;
	music_interrupt.is_Node.ln_Name = (char *)"PHOBOS music";
	music_interrupt.is_Code = audio_irq;
	old_interrupt = SetIntVector(INTB_AUD0, &music_interrupt);

	music_level = 0;
	music_target = 0;
	music_fade = 256;
	music_pos = 0;
	fill_music(music_buffers[0]);
	music_next = 1;
	custom->aud[0].ac_ptr = (UWORD *)music_buffers[0];
	custom->aud[1].ac_ptr = (UWORD *)music_buffers[0];
	custom->aud[0].ac_len = ASSET_MUSIC_BUFFER / 2;
	custom->aud[1].ac_len = ASSET_MUSIC_BUFFER / 2;
	custom->aud[0].ac_per = ASSET_MUSIC_PERIOD;
	custom->aud[1].ac_per = ASSET_MUSIC_PERIOD;
	custom->aud[0].ac_vol = MUSIC_VOLUME;
	custom->aud[1].ac_vol = MUSIC_VOLUME;
	custom->aud[2].ac_vol = 0;
	custom->aud[3].ac_vol = 0;
	custom->intena = INTF_SETCLR | INTF_AUD0;
	custom->dmacon = DMAF_SETCLR | DMAF_MASTER | DMAF_AUD0 | DMAF_AUD1;
	music_running = 1;
	return 1;
}

static void start_channel(UWORD channel, UWORD sfx, UWORD period, UWORD volume) {
	volatile struct Custom *custom = HW_CUSTOM;
	UWORD bit = 1 << channel;
	custom->dmacon = bit;
	wait_lines(2);
	custom->aud[channel].ac_ptr = (UWORD *)(hw_asset_chip + asset_sfx[sfx].offset);
	custom->aud[channel].ac_len = asset_sfx[sfx].length / 2;
	custom->aud[channel].ac_per = period;
	custom->aud[channel].ac_vol = volume;
	custom->dmacon = DMAF_SETCLR | bit;
	channels[channel].latch_pending = 1;
	channels[channel].frames_left = (UWORD)((ULONG)asset_sfx[sfx].length * period / 70938UL + 1);
	channels[channel].priority = sfx_priority[sfx];
}

void audio_play(unsigned short sfx, unsigned short pitch_q8, unsigned short volume) {
	UWORD period;
	UBYTE priority;
	if (!audio_open || muted || sfx >= ASSET_SFX_COUNT) {
		return;
	}
	period = (UWORD)((ULONG)ASSET_SFX_PERIOD * 256 / (pitch_q8 ? pitch_q8 : 256));
	if (period < 124) {
		period = 124;
	}
	if (volume > 64) {
		volume = 64;
	}
	priority = sfx_priority[sfx];
	if (sfx == SFX_ID_SHOT) {
		if (channels[2].frames_left == 0 || channels[2].priority == 0) {
			start_channel(2, sfx, period, volume);
		}
		return;
	}
	if (channels[3].frames_left == 0 || priority >= channels[3].priority) {
		start_channel(3, sfx, period, volume);
	} else if (channels[2].frames_left == 0 || channels[2].priority <= priority) {
		start_channel(2, sfx, period, volume);
	}
}

void audio_set_music(unsigned short level) {
	music_target = level > 3 ? 3 : level;
}

static void apply_music_volume(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	UWORD volume = muted ? 0 : (ducked ? MUSIC_DUCKED : MUSIC_VOLUME);
	custom->aud[0].ac_vol = volume;
	custom->aud[1].ac_vol = volume;
}

void audio_duck_music(unsigned char on) {
	if (ducked != on) {
		ducked = on;
		if (music_running) {
			apply_music_volume();
		}
	}
}

void audio_update(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	UWORD channel;
	if (!audio_open) {
		return;
	}
	for (channel = 2; channel < 4; ++channel) {
		SfxChannel *state = &channels[channel];
		if (state->latch_pending) {
			custom->aud[channel].ac_ptr = (UWORD *)(hw_asset_chip + SFX_SILENCE);
			custom->aud[channel].ac_len = 1;
			state->latch_pending = 0;
		}
		if (state->frames_left > 0) {
			--state->frames_left;
		}
	}
}

void audio_toggle_mute(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	muted = !muted;
	if (muted) {
		custom->aud[2].ac_vol = 0;
		custom->aud[3].ac_vol = 0;
	}
	if (music_running) {
		apply_music_volume();
	}
}

unsigned char audio_muted(void) {
	return muted;
}

void audio_shutdown(void) {
	volatile struct Custom *custom = HW_CUSTOM;
	if (music_running) {
		custom->intena = INTF_AUD0;
		custom->dmacon = DMAF_AUD0 | DMAF_AUD1 | DMAF_AUD2 | DMAF_AUD3;
		custom->intreq = INTF_AUD0;
		SetIntVector(INTB_AUD0, old_interrupt);
		music_running = 0;
	}
	if (audio_open) {
		CloseDevice((struct IORequest *)audio_request);
		audio_open = 0;
	}
	if (audio_request != 0) {
		DeleteExtIO((struct IORequest *)audio_request);
		audio_request = 0;
	}
	if (audio_port != 0) {
		DeletePort(audio_port);
		audio_port = 0;
	}
}
