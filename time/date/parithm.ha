// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Nominal unitary periods of the Gregorian chronology. Used for chronological
// arithmetic.
export type step = enum {
	NANOSECOND = 0b000000001,
	SECOND     = 0b000000010,
	MINUTE     = 0b000000100,
	HOUR       = 0b000001000,
	DAY        = 0b000010000,
	WEEK       = 0b000100000,
	MONTH      = 0b001000000,
	YEAR       = 0b010000000,
	ERA        = 0b100000000,

	// TODO: consider adding NONE=0, ALL=YEAR|MONTH|..., etc
	// TODO: consider adding ISOWEEKYEAR, ISOWEEK
};
