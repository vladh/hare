// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use fmt;
use fs;
use io;

// All possible errors returned from this module.
export type error = !(
	invalid
	| discontinuity
);

// Converts an [[error]] into a human-friendly string. The result may be
// statically allocated.
export fn strerror(err: error) const str = {
	match (err) {
	case invalid =>
		return "Invalid moment";
	case discontinuity =>
		return "A timescale discontinuity caused a misconversion";
	};
};
