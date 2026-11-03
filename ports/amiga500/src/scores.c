#include "scores.h"

#include <dos/dos.h>
#include <proto/dos.h>
#include <stddef.h>
#include <string.h>

#define SCORES_MAGIC 0x50484253UL
#define SCORES_VERSION 1

static unsigned long calculate_checksum(const ScoresData *data) {
	const unsigned char *bytes = (const unsigned char *)data;
	unsigned long value = 2166136261UL;
	unsigned long index;
	for (index = 0; index < offsetof(ScoresData, checksum); ++index) {
		value ^= bytes[index];
		value *= 16777619UL;
	}
	return value;
}

void scores_init(ScoresData *data) {
	memset(data, 0, sizeof(*data));
	data->magic = SCORES_MAGIC;
	data->version = SCORES_VERSION;
	data->selected_difficulty = 1;
	memcpy(data->last_initials, "AAA", 4);
	data->checksum = calculate_checksum(data);
}

static int scores_valid(const ScoresData *data) {
	unsigned short difficulty;
	if (data->magic != SCORES_MAGIC || data->version != SCORES_VERSION ||
		data->selected_difficulty >= SCORES_DIFFICULTIES) {
		return 0;
	}
	for (difficulty = 0; difficulty < SCORES_DIFFICULTIES; ++difficulty) {
		if (data->counts[difficulty] > SCORES_MAX_ENTRIES) {
			return 0;
		}
	}
	return data->checksum == calculate_checksum(data);
}

static int load_file(const char *path, ScoresData *data) {
	BPTR file = Open((STRPTR)path, MODE_OLDFILE);
	LONG bytes;
	if (file == 0) {
		return 0;
	}
	bytes = Read(file, data, sizeof(*data));
	Close(file);
	return bytes == sizeof(*data) && scores_valid(data);
}

int scores_load(ScoresData *data) {
	if (load_file("PHOBOS.SCORES", data)) {
		return 1;
	}
	if (load_file("PHOBOS.BAK", data)) {
		return 1;
	}
	scores_init(data);
	return 0;
}

int scores_save(ScoresData *data) {
	BPTR file;
	LONG bytes;
	data->checksum = calculate_checksum(data);
	DeleteFile((STRPTR)"PHOBOS.NEW");
	file = Open((STRPTR)"PHOBOS.NEW", MODE_NEWFILE);
	if (file == 0) {
		return 0;
	}
	bytes = Write(file, data, sizeof(*data));
	Close(file);
	if (bytes != sizeof(*data)) {
		DeleteFile((STRPTR)"PHOBOS.NEW");
		return 0;
	}
	DeleteFile((STRPTR)"PHOBOS.BAK");
	Rename((STRPTR)"PHOBOS.SCORES", (STRPTR)"PHOBOS.BAK");
	if (!Rename((STRPTR)"PHOBOS.NEW", (STRPTR)"PHOBOS.SCORES")) {
		Rename((STRPTR)"PHOBOS.BAK", (STRPTR)"PHOBOS.SCORES");
		DeleteFile((STRPTR)"PHOBOS.NEW");
		return 0;
	}
	return 1;
}

static int entry_before(const ScoreEntry *left, const ScoreEntry *right) {
	if (left->score != right->score) {
		return left->score > right->score;
	}
	if (left->wave != right->wave) {
		return left->wave > right->wave;
	}
	if (left->kills != right->kills) {
		return left->kills > right->kills;
	}
	if (left->seconds != right->seconds) {
		return left->seconds > right->seconds;
	}
	return strcmp(left->initials, right->initials) < 0;
}

int scores_qualifies(const ScoresData *data, unsigned char difficulty, const ScoreEntry *entry) {
	unsigned char count;
	if (difficulty >= SCORES_DIFFICULTIES || entry->score == 0) {
		return 0;
	}
	count = data->counts[difficulty];
	return count < SCORES_MAX_ENTRIES || entry_before(entry, &data->entries[difficulty][count - 1]);
}

void scores_submit(ScoresData *data, unsigned char difficulty, const ScoreEntry *entry) {
	unsigned char count;
	unsigned char position;
	unsigned char index;
	if (!scores_qualifies(data, difficulty, entry)) {
		return;
	}
	count = data->counts[difficulty];
	position = count;
	for (index = 0; index < count; ++index) {
		if (entry_before(entry, &data->entries[difficulty][index])) {
			position = index;
			break;
		}
	}
	if (count < SCORES_MAX_ENTRIES) {
		++count;
		data->counts[difficulty] = count;
	}
	for (index = count - 1; index > position; --index) {
		data->entries[difficulty][index] = data->entries[difficulty][index - 1];
	}
	data->entries[difficulty][position] = *entry;
	memcpy(data->last_initials, entry->initials, 4);
	data->checksum = calculate_checksum(data);
}

unsigned char scores_collect(const ScoresData *data, unsigned char filter, ScoreEntry *out,
	unsigned char *out_difficulty, unsigned char max) {
	unsigned char count = 0;
	unsigned char difficulty;
	for (difficulty = 0; difficulty < SCORES_DIFFICULTIES; ++difficulty) {
		unsigned char index;
		if (filter != SCORES_ALL && filter != difficulty) {
			continue;
		}
		for (index = 0; index < data->counts[difficulty]; ++index) {
			const ScoreEntry *entry = &data->entries[difficulty][index];
			unsigned char position = count;
			unsigned char move;
			while (position > 0 && entry_before(entry, &out[position - 1])) {
				--position;
			}
			if (position >= max) {
				continue;
			}
			move = count < max ? count : max - 1;
			for (; move > position; --move) {
				out[move] = out[move - 1];
				out_difficulty[move] = out_difficulty[move - 1];
			}
			out[position] = *entry;
			out_difficulty[position] = difficulty;
			if (count < max) {
				++count;
			}
		}
	}
	return count;
}

int scores_self_test(void) {
	ScoresData data;
	ScoreEntry entry;
	unsigned short index;
	scores_init(&data);
	memcpy(entry.initials, "AAA", 4);
	entry.wave = 2;
	entry.kills = 10;
	entry.seconds = 60;
	for (index = 0; index < 12; ++index) {
		entry.score = 100 + index * 10;
		scores_submit(&data, 1, &entry);
	}
	if (data.counts[1] != 10 || data.entries[1][0].score != 210 ||
		data.entries[1][9].score != 120) {
		return 1;
	}
	if (!scores_valid(&data) || scores_qualifies(&data, 1, &data.entries[1][9])) {
		return 2;
	}
	data.checksum ^= 1;
	if (scores_valid(&data)) {
		return 3;
	}
	return 0;
}
