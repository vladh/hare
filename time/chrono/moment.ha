// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;

// A precise moment in time, in reference to a specific timescale.
// An extension of [[time::instant]] coupled with a [[timescale]].
export type moment = struct {
	time::instant,
	tsc: *timescale,
};

// Creates a new [[moment]].
export fn new(tsc: *timescale, t: time::instant) moment = {
	return moment {
		sec = t.sec,
		nsec = t.nsec,
		tsc = tsc,
	};
};

// Extracts the [[time::instant]] of the given [[moment]].
export fn to_instant(m: moment) time::instant = *(&m: *time::instant);
