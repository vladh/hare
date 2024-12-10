// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use os;
use path;
use sort;
use strings;
use time;
use time::chrono;

// The duration of a day on Earth, in terrestrial (SI) seconds.
export def EARTH_DAY: time::duration = 86400 * time::SECOND;

// The duration of a solar day on Mars, in Martian seconds.
export def MARS_SOL_MARTIAN: time::duration = 86400 * time::SECOND;
// TODO: remove

// The duration of a solar day on Mars, in terrestrial (SI) seconds.
export def MARS_SOL_TERRESTRIAL: time::duration = 88775244147000 * time::NANOSECOND;
// TODO: remove

// The locality of a [[date]]. Contains information about how to calculate a
// moment's observed chronological values.
export type locality = *timezone;

// A timezone; a political or otherwise theoretical region with a ruleset
// regarding offsets for calculating localized date/time.
export type timezone = struct {
	// The base timescale (e.g. time::chrono::utc).
	tsc: *chrono::timescale,

	// The textual identifier (e.g. "Europe/Amsterdam").
	name: str,

	// The duration of a day in this timezone (e.g. 24 * time::HOUR).
	daylength: time::duration,

	// The possible zonephases a locality with this timezone can observe
	// (e.g. CET, CEST, ...).
	phases: []zonephase,

	// The transitions between this timezone's zonephases.
	transitions: []zonetransition,

	// The function to calculate the correct [[zonephase]] to observe.
	// If null, defaults to an internal function.
	lookupzone: nullable *zonelookuper,

	// Used for extending calculations beyond the last known transition.
	// See [[petz]].
	petz: petz,
};

// A [[timezone]] state, with an offset for calculating localized date/time.
export type zonephase = struct {
	// The offset from the normal timezone (e.g. 2 * time::HOUR).
	zoff: time::duration,

	// The full descriptive name (e.g. "Central European Summer Time").
	name: str,

	// The abbreviated name (e.g. "CEST").
	abbr: str,

	// Indicator of Daylight Saving Time.
	dst: bool, // true
};

// A [[timezone]] transition between two [[zonephase]]s.
export type zonetransition = struct {
	when: time::instant,
	zoneindex: size,
};

// Determines the correct [[zonephase]] to observe for a given [[date]].
export type zonelookuper = fn(locality, *date) *zonephase;

// Frees a [[timezone]]. A [[locality]] argument can be passed.
export fn timezone_free(tz: *timezone) void = {
	free(tz.name);
	for (let zonephase &.. tz.phases) {
		zone_finish(zonephase);
	};
	free(tz.phases);
	free(tz.transitions);
	petz_finish(&tz.petz);
	free(tz);
};

// Frees resources associated with a [[zonephase]].
export fn zone_finish(z: *zonephase) void = {
	free(z.name);
	free(z.abbr);
};

// Calculates and returns a [[date]]'s observed [[zonephase]].
fn lookupzone(loc: locality, d: *date) *zonephase = {
	if (len(loc.phases) == 0) {
		abort("Timezone has no zonephases");
	};

	if (len(loc.phases) == 1) {
		return &loc.phases[0];
	};

	let t = to_instant(*d);
	let trs = loc.transitions[..];

	if (len(trs) == 0 || time::compare(t, trs[0].when) == -1) {
		// tzfile(5) suggests we use "time type 0" for instants before
		// the first transition.
		return &loc.phases[0];
	};

	// index of transition which t is equal to or greater than.
	const idx = -1 + sort::rbisect(
		trs, size(zonetransition), &t, &cmpinstants,
	);

	let z = &loc.phases[trs[idx].zoneindex];

	// if we've reached the end of the locality's transitions,
	// try its POSIX "extending" TZ string.
	if (idx == len(trs) - 1) {
		z = lookupzone_posix(loc, d);
	};

	return z;
};

fn cmpinstants(a: const *opaque, b: const *opaque) int = {
	let a = a: *zonetransition;
	let b = b: *time::instant;
	return time::compare(a.when, *b): int;
};

// Creates a [[timezone]] with a single [[zonephase]]. Useful for fixed offsets.
// The caller must free the return value with [[timezone_free]]. An example,
// replicate the civil time Hawaii timezone on Earth:
//
// 	let hawaii = chrono::fixedzone(
// 		&chrono::utc,
// 		"Custom/Hawaiian_Reef",
// 		chrono::EARTH_DAY,
// 		chrono::zonephase {
// 			zoff = -10 * time::HOUR,
// 			abbr = "HARE",
// 			dst = false,
// 			...
// 		},
// 	);
//
export fn fixedzone(
	tsc: *chrono::timescale,
	name: str,
	daylen: time::duration,
	z: zonephase,
) *timezone = {
	return alloc(timezone {
		name = strings::dup(name)!,
		tsc = tsc,
		daylength = daylen,
		phases = alloc([z])!,
		transitions = [],
		lookupzone = null,
		petz = PETZ_EMPTY,
	})!;
};

// The local [[locality]]; the system or environment configured [[timezone]].
//
// This is set during the program's initialization. In order of preference, the
// TZ environment variable is used, if set; the file at [[LOCALTIME_PATH]], if
// present; or, as a last resort, [[UTC]] is used as a default.
export const LOCAL: locality = &TZ_UTC;

@init fn init_tz_local() void = {
	let path = match (os::getenv("TZ")) {
	case let s: str =>
		// remove POSIX prefix ':'
		let s =
			if (strings::hasprefix(s, ":"))
				strings::trimprefix(s, ":")
			else
				s;

		yield match (path::init(s)) {
		case => return;
		case let p: path::buffer =>
			yield path::string(&p);
		};

	case void =>
		let s = match (os::realpath(LOCALTIME_PATH)) {
		case => return;
		case let s: str =>
			yield s;
		};

		let p = match (path::init(s)) {
		case => return;
		case let p: path::buffer =>
			yield p;
		};

		yield match (path::trimprefix(&p, TZDB_PATH)) {
		case => return;
		case let s: str =>
			yield s;
		};
	};

	match (tz(path)) {
	case => void;
	case let loc: locality =>
		LOCAL = loc;
	};
};

@fini fn free_tz_local() void = {
	if (LOCAL != UTC) {
		timezone_free(LOCAL);
	};
};

// The UTC (Coordinated Universal Time) "Zulu" [[timezone]] as a [[locality]].
// Uses the [[time::chrono::utc]] timescale.
export const UTC: locality = &TZ_UTC;

const TZ_UTC: timezone = timezone {
	name = "UTC",
	tsc = &chrono::utc,
	daylength = EARTH_DAY,
	phases = [
		zonephase {
			zoff = 0 * time::SECOND,
			name = "Universal Coordinated Time",
			abbr = "UTC",
			dst = false,
		},
	],
	transitions = [],
	lookupzone = null,
	petz = PETZ_EMPTY,
};

// The TAI (International Atomic Time) "Zulu" [[timezone]] as a [[locality]].
// Uses the [[time::chrono::tai]] timescale.
export const TAI: locality = &TZ_TAI;

const TZ_TAI: timezone = timezone {
	name = "TAI",
	tsc = &chrono::tai,
	daylength = EARTH_DAY,
	phases = [
		zonephase {
			zoff = 0 * time::SECOND,
			name = "International Atomic Time",
			abbr = "TAI",
			dst = false,
		},
	],
	transitions = [],
	lookupzone = null,
	petz = PETZ_EMPTY,
};

// The GPS (Global Positioning System) "Zulu" [[timezone]] as a [[locality]].
// Uses the [[time::chrono::gps]] timescale.
export const GPS: locality = &TZ_GPS;

const TZ_GPS: timezone = timezone {
	name = "GPS",
	tsc = &chrono::gps,
	daylength = EARTH_DAY,
	phases = [
		zonephase {
			zoff = 0 * time::SECOND,
			name = "Global Positioning System",
			abbr = "GPS",
			dst = false,
		},
	],
	transitions = [],
	lookupzone = null,
	petz = PETZ_EMPTY,
};

// The TT (Terrestrial Time) "Zulu" [[timezone]] as a [[locality]].
// Uses the [[time::chrono::tt]] timescale.
export const TT: locality = &TZ_TT;

const TZ_TT: timezone = timezone {
	name = "TT",
	tsc = &chrono::tt,
	daylength = EARTH_DAY,
	phases = [
		zonephase {
			zoff = 0 * time::SECOND,
			name = "Terrestrial Time",
			abbr = "TT",
			dst = false,
		},
	],
	transitions = [],
	lookupzone = null,
	petz = PETZ_EMPTY,
};

// The MTC (Coordinated Mars Time) "Zulu" [[timezone]] as a [[locality]].
// Uses the [[time::chrono::mtc]] timescale.
export const MTC: locality = &TZ_MTC;

const TZ_MTC: timezone = timezone {
	name = "MTC",
	tsc = &chrono::mtc,
	daylength = MARS_SOL_MARTIAN,
	phases = [
		zonephase {
			zoff = 0 * time::SECOND,
			name = "Coordinated Mars Time",
			abbr = "MTC",
			dst = false,
		},
	],
	transitions = [],
	lookupzone = null,
	petz = PETZ_EMPTY,
};
