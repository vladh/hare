// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// The elapsed time between two instants, in nanoseconds. The largest
// representable duration is about 290 years.
export type duration = i64;

// [[duration]] representing a single nanosecond.
export def NANOSECOND: duration = 1;

// [[duration]] representing a single microsecond.
export def MICROSECOND: duration = 1000 * NANOSECOND;

// [[duration]] representing a single millisecond.
export def MILLISECOND: duration = 1000 * MICROSECOND;

// [[duration]] representing a second.
export def SECOND: duration = 1000 * MILLISECOND;

// [[duration]] representing a minute.
export def MINUTE: duration = 60 * SECOND;

// [[duration]] representing an hour.
export def HOUR: duration = 60 * MINUTE;
