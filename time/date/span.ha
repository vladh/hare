// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use fmt;
use io;

// Represents a span of time in the Gregorian chronology, using nominal units of
// time. Used for chronological arithmetic.
export type span = struct {
	years: i64,
	months: i64,
	weeks: i64,
	days: i64,
	hours: i64,
	minutes: i64,
	seconds: i64,
	nanoseconds: i64,
};

// Returns true if two [[span]]s are numerically equal, false otherwise.
export fn equalspan(x: span, y: span) bool = {
	return (
		x.years          == y.years
		&& x.months      == y.months
		&& x.weeks       == y.weeks
		&& x.days        == y.days
		&& x.hours       == y.hours
		&& x.minutes     == y.minutes
		&& x.seconds     == y.seconds
		&& x.nanoseconds == y.nanoseconds
	);
};

// Returns the sum [[span]] of a set of spans.
export fn sum(spans: span...) span = {
	let x = span { ... };
	for (let y &.. spans) {
		x.years       += y.years;
		x.months      += y.months;
		x.weeks       += y.weeks;
		x.days        += y.days;
		x.hours       += y.hours;
		x.minutes     += y.minutes;
		x.seconds     += y.seconds;
		x.nanoseconds += y.nanoseconds;
	};
	return x;
};

// Returns a [[span]] with its fields negated.
export fn neg(x: span) span = span {
	years       = -x.years,
	months      = -x.months,
	weeks       = -x.weeks,
	days        = -x.days,
	hours       = -x.hours,
	minutes     = -x.minutes,
	seconds     = -x.seconds,
	nanoseconds = -x.nanoseconds,
};

// Returns a [[span]] with its fields made absolute and positive.
export fn abs(x: span) span = span {
	years       = if (x.years < 0)       -x.years       else x.years,
	months      = if (x.months < 0)      -x.months      else x.months,
	weeks       = if (x.weeks < 0)       -x.weeks       else x.weeks,
	days        = if (x.days < 0)        -x.days        else x.days,
	hours       = if (x.hours < 0)       -x.hours       else x.hours,
	minutes     = if (x.minutes < 0)     -x.minutes     else x.minutes,
	seconds     = if (x.seconds < 0)     -x.seconds     else x.seconds,
	nanoseconds = if (x.nanoseconds < 0) -x.nanoseconds else x.nanoseconds,
};

// Formats a [[span]] and writes it into an internal static buffer. The returned
// string is borrowed from this buffer. The following layout is used:
//
//     "?Y ?M ?W ?D ?h ?m ?s ?n"
//
// where each '?' is replaced with the appopriate span field values in order of
// decreasing significance, and the inbetween spaces are replaced with the given
// sep parameter.
export fn formatspan(s: span, sep: rune = ' ') str = {
	static let buf: [128]u8 = [0...];
	return fmt::bsprintf(buf, "{}Y{}{}M{}{}W{}{}D{}{}h{}{}m{}{}s{}{}n",
		s.years, sep,
		s.months, sep,
		s.weeks, sep,
		s.days, sep,
		s.hours, sep,
		s.minutes, sep,
		s.seconds, sep,
		s.nanoseconds,
	);
};
