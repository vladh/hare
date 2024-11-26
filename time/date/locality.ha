// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Creates an equivalent [[date]] with a different [[locality]].
//
// If the date's associated [[timescale]] and the target locality's timescale
// are different, a conversion from one to the other via the TAI timescale will
// be attempted. Any [[discontinuity]] occurrence will be returned. If a
// discontinuity against TAI amongst the two timescales exist, consider
// converting such instants manually.
export fn in(loc: locality, d: date) (date | chrono::tscmismatch) = {
	return from_moment(loc, to_moment(d));
};
