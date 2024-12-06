// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Creates an equivalent [[date]] with a different [[locality]].
//
// [[time::chrono::tscmismatch]] is returned if the [[time::chrono::timescale]]s
// of the given moment and the target [[locality]] are different.
export fn in(loc: locality, d: date) (date | chrono::tscmismatch) = {
	return from_moment(loc, to_moment(d));
};
