// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use fmt;
use fs;
use io;

// All possible errors returned from this module.
export type error = !(invalid | tscmismatch);

// Converts an [[error]] into a human-friendly string. The result may be
// statically allocated.
export fn strerror(e: error) const str = {
	static let buf: [92]u8 = [0...];
	match (e) {
	case invalid =>
		return "Invalid moment";
	case let e: tscmismatch =>
		return fmt::bsprintf(buf,
			"Timescale mismatch: {}, {}",
			e.0.abbr,
			e.1.abbr,
		);
	};
};
