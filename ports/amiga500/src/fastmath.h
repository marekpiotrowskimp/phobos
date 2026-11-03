#ifndef PHOBOS_FASTMATH_H
#define PHOBOS_FASTMATH_H

/*
 * Mnożenie i dzielenie 16-bitowe instrukcjami 68000 (muls.w/mulu.w/divs.w/divu.w).
 * GCC dla 32-bitowego int woła w tych miejscach wolne ___mulsi3/___divsi3.
 * Na hoście (testy) używane są zwykłe operatory.
 */

#if defined(__mc68000__) || defined(__m68k__)

static inline long muls16(short a, short b) {
	long result = a;
	__asm__("muls.w %1,%0" : "+d"(result) : "dmi"(b) : "cc");
	return result;
}

static inline unsigned long mulu16(unsigned short a, unsigned short b) {
	unsigned long result = a;
	__asm__("mulu.w %1,%0" : "+d"(result) : "dmi"(b) : "cc");
	return result;
}

/* Iloraz musi mieścić się w 16 bitach. */
static inline short divs16(long numerator, short denominator) {
	long value = numerator;
	__asm__("divs.w %1,%0" : "+d"(value) : "dm"(denominator) : "cc");
	return (short)value;
}

static inline unsigned short divu16(unsigned long numerator, unsigned short denominator) {
	unsigned long value = numerator;
	__asm__("divu.w %1,%0" : "+d"(value) : "dm"(denominator) : "cc");
	return (unsigned short)value;
}

/* Iloraz i reszta w jednym dzieleniu: zwraca iloraz, reszta w *remainder. */
static inline unsigned short divmodu16(unsigned long numerator, unsigned short denominator, unsigned short *remainder) {
	unsigned long value = numerator;
	__asm__("divu.w %1,%0" : "+d"(value) : "dm"(denominator) : "cc");
	*remainder = (unsigned short)(value >> 16);
	return (unsigned short)value;
}

#else

static inline long muls16(short a, short b) { return (long)a * b; }
static inline unsigned long mulu16(unsigned short a, unsigned short b) { return (unsigned long)a * b; }
static inline short divs16(long numerator, short denominator) { return (short)(numerator / denominator); }
static inline unsigned short divu16(unsigned long numerator, unsigned short denominator) {
	return (unsigned short)(numerator / denominator);
}
static inline unsigned short divmodu16(unsigned long numerator, unsigned short denominator, unsigned short *remainder) {
	*remainder = (unsigned short)(numerator % denominator);
	return (unsigned short)(numerator / denominator);
}

#endif

#endif
