// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;

// Compares two [[moment]]s. Returns -1 if a precedes b, 0 if a and b are
// simultaneous, or +1 if b precedes a.
//
// The moments are compared as [[time::instant]]s; their observed chronological
// values are ignored.
//
// If the moments' associated [[timescale]]s are different, they will be
// converted to [[tai]] instants first. Any [[discontinuity]] occurence will be
// returned. If a discontinuity against TAI amongst the two timescales exist,
// consider converting such instants manually.
export fn compare(a: *moment, b: *moment) (i8 | tscmismatch) = {
	check_timescales(a.tsc, b.tsc)?;
	return time::compare(to_instant(*a), to_instant(*b));
};

// Returns the [[time::duration]] between two [[moment]]s, from a to b.
//
// The moments are compared as [[time::instant]]s; their observed chronological
// values are ignored.
//
// If the moments' associated [[timescale]]s are different, they will be
// converted to [[tai]] instants first. Any [[discontinuity]] occurence will be
// returned. If a discontinuity against TAI amongst the two timescales exist,
// consider converting such instants manually.
export fn diff(a: *moment, b: *moment) (time::duration | tscmismatch) = {
	check_timescales(a.tsc, b.tsc)?;
	return time::diff(to_instant(*a), to_instant(*b));
};

// Adds a [[time::duration]] to a [[moment]] with [[time::add]].
export fn add(m: *moment, x: time::duration) moment = {
	return new(m.tsc, time::add(to_instant(*m), x));
};
