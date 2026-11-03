#ifndef PHOBOS_AUDIO_H
#define PHOBOS_AUDIO_H

/* Kanały Paula: 0+1 muzyka (środek), 2 broń, 3 zdarzenia. */
int audio_init(void);
void audio_play(unsigned short sfx, unsigned short pitch_q8, unsigned short volume);
void audio_set_music(unsigned short level);
void audio_duck_music(unsigned char on);
void audio_update(void);
void audio_toggle_mute(void);
unsigned char audio_muted(void);
void audio_shutdown(void);

#endif
