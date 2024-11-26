// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use types;

// Represents a specific instant in time as seconds (+nanoseconds) since an
// arbitrary epoch. Instants may only be meaningfully compared with other
// instants sourced from the same [[clock]], or handled by the same
// [[time::chrono::timescale]]
export type instant = struct {
	sec: i64,
	nsec: i64,
};

// Represents a unique interval of time between two [[instant]]s.
export type interval = (instant, instant);

// The earliest representable [[instant]].
export def INSTANT_MIN = instant {
	sec = types::I64_MIN,
	nsec = 0,
};

// The latest representable [[instant]].
export def INSTANT_MAX = instant {
	sec = types::I64_MAX,
	nsec = SECOND - 1,
};

// Creates a new [[instant]] with seconds and nanoseconds.
export fn new(sec: i64, nsec: i64 = 0) instant = instant {
	sec = sec,
	nsec = nsec,
};
