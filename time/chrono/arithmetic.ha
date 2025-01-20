// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;

// Compares two [[moment]]s. Returns -1 if a precedes b, 0 if a and b are
// simultaneous, or +1 if b precedes a.
//
// [[tscmismatch]] is returned if the [[timescale]]s of the two moments are
// different.
export fn compare(a: *moment, b: *moment) (i8 | tscmismatch) = {
	check_timescales(a.tsc, b.tsc)?;
	return time::compare(to_instant(*a), to_instant(*b));
};

// Returns the [[time::duration]] between two [[moment]]s, from a to b.
//
// [[tscmismatch]] is returned if the [[timescale]]s of the two moments are
// different.
export fn diff(a: *moment, b: *moment) (time::duration | tscmismatch) = {
	check_timescales(a.tsc, b.tsc)?;
	return time::diff(to_instant(*a), to_instant(*b));
};

// Adds a [[time::duration]] to a [[moment]] with [[time::add]].
export fn add(m: *moment, x: time::duration) moment = {
	return new(m.tsc, time::add(to_instant(*m), x));
};
