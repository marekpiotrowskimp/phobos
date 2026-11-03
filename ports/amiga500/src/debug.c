#include "debug.h"

#define SERDATR (*(volatile UWORD *)0xdff018)
#define SERDAT (*(volatile UWORD *)0xdff030)
#define SERPER (*(volatile UWORD *)0xdff032)

static UBYTE enabled;

void debug_init(void) {
	SERPER = 30;
	enabled = 1;
}

static void put_byte(UBYTE value) {
	if (!enabled) {
		return;
	}
	while ((SERDATR & 0x2000) == 0) {
	}
	SERDAT = (UWORD)(0x100 | value);
}

void debug_text(const char *text) {
	while (*text) {
		put_byte((UBYTE)*text++);
	}
}

void debug_number(long value) {
	char digits[12];
	WORD count = 0;
	unsigned long magnitude = value < 0 ? (unsigned long)-value : (unsigned long)value;
	if (value < 0) {
		put_byte('-');
	}
	do {
		digits[count++] = (char)('0' + magnitude % 10);
		magnitude /= 10;
	} while (magnitude > 0);
	while (count > 0) {
		put_byte((UBYTE)digits[--count]);
	}
}

void debug_value(const char *name, long value) {
	debug_text(name);
	debug_text("=");
	debug_number(value);
	debug_text(" ");
}

static void put_long(ULONG value) {
	put_byte((UBYTE)(value >> 24));
	put_byte((UBYTE)(value >> 16));
	put_byte((UBYTE)(value >> 8));
	put_byte((UBYTE)value);
}

void debug_dump_begin(const char *name) {
	debug_text("\n@@DUMP ");
	debug_text(name);
	debug_text("\n");
}

void debug_dump_block(const void *address, ULONG length) {
	const UBYTE *bytes = (const UBYTE *)address;
	ULONG checksum = 0;
	put_byte('B');
	put_long((ULONG)address);
	put_long(length);
	while (length-- > 0) {
		checksum = checksum * 31 + *bytes;
		put_byte(*bytes++);
	}
	put_long(checksum);
}

void debug_dump_end(void) {
	put_byte('E');
	debug_text("\n@@END\n");
}
