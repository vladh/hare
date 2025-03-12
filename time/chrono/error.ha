// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use encoding::utf8;
use fmt;
use fs;
use io;

// All possible errors returned from this module.
export type error = !(tscmismatch | utciniterror);

// Converts an [[error]] into a human-friendly string. The result may be
// statically allocated.
export fn strerror(e: error) const str = {
	static let buf: [92]u8 = [0...];
	match (e) {
	case let e: tscmismatch =>
		return fmt::bsprintf(buf,
			"Timescale mismatch: {}, {}",
			e.0.abbr,
			e.1.abbr,
		)!;
	case let e: utciniterror =>
		return fmt::bsprintf(buf,
			"UTC initialization: {}",
			match (e) {
			case let e: fs::error =>
				yield fs::strerror(e);
			case let e: io::error =>
				yield io::strerror(e);
			case let e: utf8::invalid =>
				yield utf8::strerror(e);
			},
		)!;
	};
};
