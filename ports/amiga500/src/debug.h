#ifndef PHOBOS_DEBUG_H
#define PHOBOS_DEBUG_H

#include <exec/types.h>

/* Kanał diagnostyczny przez port szeregowy (tryb --demo; FS-UAE: serial_port=plik). */
void debug_init(void);
void debug_text(const char *text);
void debug_number(long value);
void debug_value(const char *name, long value);
void debug_dump_begin(const char *name);
void debug_dump_block(const void *address, ULONG length);
void debug_dump_end(void);

#endif
