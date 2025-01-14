// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;

// Invalid [[moment]].
export type invalid = !void;

// A moment in time within a [[locality]]. Create one with [[new]]. This type
// extends the [[time::instant]] type and couples it with a [[timescale]] via
// its [[locality]] field.
//
// This object should be treated as private and immutable. Directly mutating its
// fields causes undefined behavour when used with module functions. Likewise,
// interrogating the fields' type and value (e.g. using match statements) is
// also improper.
//
// Moments observe a daydate, time-of-day, and [[zone]], which are evaluated,
// cached and obtained with the observer functions [[daydate]], [[daytime]], and
// [[ozone]]. These values are derived from the embedded instant and locality
// information, and thus are guaranteed to be valid.
export type moment = struct {
	time::instant,
	tsc: *timescale,
};

// Creates a new [[moment]]. Uses a given [[time::instant]] with a [[timescale]]
// associated with a given [[locality]].
export fn new(tsc: *timescale, i: time::instant) moment = {
	return moment {
		sec = i.sec,
		nsec = i.nsec,
		tsc = tsc,
	};
};

// Extracts the [[time::instant]] of the given [[moment]].
export fn to_instant(m: moment) time::instant = *(&m: *time::instant);
