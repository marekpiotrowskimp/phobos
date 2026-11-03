#ifndef PHOBOS_SCORES_H
#define PHOBOS_SCORES_H

#define SCORES_DIFFICULTIES 3
#define SCORES_MAX_ENTRIES 10

typedef struct {
	char initials[4];
	unsigned long score;
	unsigned short wave;
	unsigned short kills;
	unsigned short seconds;
} ScoreEntry;

typedef struct {
	unsigned long magic;
	unsigned short version;
	unsigned char selected_difficulty;
	char last_initials[4];
	unsigned char counts[SCORES_DIFFICULTIES];
	ScoreEntry entries[SCORES_DIFFICULTIES][SCORES_MAX_ENTRIES];
	unsigned long checksum;
} ScoresData;

void scores_init(ScoresData *data);
int scores_load(ScoresData *data);
int scores_save(ScoresData *data);
int scores_qualifies(const ScoresData *data, unsigned char difficulty, const ScoreEntry *entry);
void scores_submit(ScoresData *data, unsigned char difficulty, const ScoreEntry *entry);
/* Lista do wyświetlenia: filter 0..2 albo SCORES_ALL; zwraca liczbę wpisów (≤ max). */
#define SCORES_ALL 3
unsigned char scores_collect(const ScoresData *data, unsigned char filter, ScoreEntry *out,
	unsigned char *out_difficulty, unsigned char max);
int scores_self_test(void);

#endif
