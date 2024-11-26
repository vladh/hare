// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use fmt;
use fs;
use io;
use strings;
use time::chrono;

// All possible errors returned from this module.
export type error = !(
	invalid
	| insufficient
	| zfunresolved
	| parsefail
	| invalidtzif
	| tzdberror
	| chrono::tscmismatch
);

// Converts an [[error]] into a human-friendly string. The result may be
// statically allocated.
export fn strerror(err: error) const str = {
	static let buf: [92]u8 = [0...];
	match (err) {
	case let lack: insufficient =>
		return strings::rtrim(fmt::bsprint(buf,
			"Insufficient date information, could not calculate:",
			if (lack & insufficient::LOCALITY: u8 == 0) "" else
				"locality",
			if (lack & insufficient::DAYDATE: u8 == 0) "" else
				"daydate",
			if (lack & insufficient::DAYTIME: u8 == 0) "" else
				"time-of-day",
			if (lack & insufficient::ZOFF: u8 == 0) "" else
				"zone-offset",
		));
	case invalid =>
		return "Invalid date information";
	case let lap: zfunresolved =>
		if (lap) {
			return "Failed to resolve zone-offset in a timezone transition overlap";
		} else {
			return "Failed to resolve zone-offset in a timezone transition gap";
		};
	case let pf: parsefail =>
		const (bi, rn) = pf;
		def FMTMSG = "Date parsing failure for layout rune '{}' at byteindex {}";
		static let buf: [len(FMTMSG) + 3]u8 = [0...];
		return fmt::bsprintf(buf, FMTMSG, rn, bi);
	case invalidtzif =>
		return "Invalid TZif data";
	case let err: tzdberror =>
		static let buf: [1024]u8 = [0...];
		match (err) {
		case let err: fs::error =>
			return fmt::bsprintf(buf,
				"Timezone database error: {}",
				fs::strerror(err),
			);
		case let err: io::error =>
			return fmt::bsprintf(buf,
				"Timezone database error: {}",
				io::strerror(err),
			);
		case invalidtzif =>
			return "Timezone database error: Invalid TZif data";
		};
	case let err: chrono::tscmismatch =>
		return fmt::bsprintf(buf,
			"Timescale mismatch: {}, {}",
			err.0.abbr,
			err.1.abbr,
		);
	};
};
