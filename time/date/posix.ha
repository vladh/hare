// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use ascii;
use strconv;
use strings;
use time;

// Invalid POSIX extend TZ string.
export type invalidpetzstr = !void;

// A POSIX "extending timezone" of the "TZ" environment variable format.
// Used for extending calculations beyond the last known transition.
//
// Example PETZ in string form: "CET-1CEST,M3.5.0,M10.5.0/3".
export type petz = struct {
	std_abbr: str,
	std_offset: time::duration,
	dst_abbr: str, // empty string means no DST
	dst_offset: time::duration,
	dst_startdate: petz_ruledate,
	dst_starttime: time::duration,
	dst_enddate: petz_ruledate,
	dst_endtime: time::duration,
};

export type petz_ruledate = (
	petz_ruledate_julian
	| petz_ruledate_ordinal
	| petz_ruledate_weekdate
);

export type petz_ruledate_julian = i16; // "Jn"

export type petz_ruledate_ordinal = i16; // "n"

export type petz_ruledate_weekdate = (u8, u8, u8); // "Mm.w.d"

def PETZ_EMPTY = petz {
	std_abbr = "",
	std_offset = 0 * time::HOUR,
	dst_abbr = "",
	dst_offset = 0 * time::HOUR,
	dst_startdate = (0, 0, 0),
	dst_starttime = 2 * time::HOUR,
	dst_enddate = (0, 0, 0),
	dst_endtime = 2 * time::HOUR,
};

fn petz_finish(p: *petz) void = {
	free(p.std_abbr);
	free(p.dst_abbr);
};

fn parse_petz(p: *petz, petzstring: str) (void | invalidpetzstr) = {
	match (parse_petz_string(p, petzstring)) {
	case parsed_err =>
		return invalidpetzstr;
	case parsed_done =>
		return void;
	};
};

fn parse_petz_string(p: *petz, petzstring: str) parsed = {
	p.dst_starttime = 2 * time::HOUR;
	p.dst_endtime   = 2 * time::HOUR;

	let t = strings::iter(petzstring);

	p.std_abbr   = strings::dup(scan_petz_abbr(&t)?)!;
	p.std_offset = -scan_petz_time(&t, 25, parsed_err)?;

	scan_rune(&t, void, parsed_done)?; strings::prev(&t);

	p.dst_abbr   = strings::dup(scan_petz_abbr(&t)?)!;
	p.dst_offset = -scan_petz_time(&t, 25, -(p.std_offset + 1 * time::HOUR))?;

	// enforce PETZ strings with DST to specify a rule
	scan_rune(&t, ',', parsed_err)?;

	p.dst_startdate = scan_petz_ruledate(&t, parsed_err)?;
	if (scan_rune(&t, void, parsed_err)? == '/') {
		p.dst_starttime = scan_petz_time(&t, 168, 2 * time::HOUR)?;
	} else {
		strings::prev(&t);
	};

	scan_rune(&t, ',', parsed_err)?;

	p.dst_enddate = scan_petz_ruledate(&t, parsed_err)?;
	scan_rune(&t, '/', parsed_done)?;
	p.dst_endtime = scan_petz_time(&t, 168, 2 * time::HOUR)?;

	return parsed_done;
};

fn scan_petz_time(
	t: *strings::iterator,
	hour_range: int,
	default: (time::duration | parsed),
) (time::duration | parsed) = {
	let sign: int = 1;
	let hour: int = 2;
	let mins: int = 0;
	let secs: int = 0;

	switch (scan_rune(t, void, parsed_done)?) {
	case =>
		strings::prev(t);
		return default;
	case '+' =>
		sign = 1;
	case '-' =>
		sign = -1;
	case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' =>
		strings::prev(t);
	};

	hour = scan_num(t, 1, 3, parsed_err)?: int;
	if (hour >= hour_range) {
		return parsed_err;
	};

	match (strings::next(t)) {
	case done =>
		return calc_petz_daytime(sign, hour, mins, secs);
	case let r: rune =>
		if (r != ':') {
			strings::prev(t);
			return calc_petz_daytime(sign, hour, mins, secs);
		};
	};

	mins = scan_num(t, 1, 2, 0)?: int;
	if (mins >= 60) {
		return parsed_err;
	};

	match (strings::next(t)) {
	case done =>
		return calc_petz_daytime(sign, hour, mins, secs);
	case let r: rune =>
		if (r != ':') {
			strings::prev(t);
			return calc_petz_daytime(sign, hour, mins, secs);
		};
	};

	secs = scan_num(t, 1, 2, 0)?: int;
	if (mins >= 60) {
		return parsed_err;
	};

	return calc_petz_daytime(sign, hour, mins, secs);
};

fn calc_petz_daytime(sign: int, hour: int, mins: int, secs: int) time::duration = {
	return sign * (
		hour * time::HOUR
		+ mins * time::MINUTE
		+ secs * time::SECOND
	);
};

fn scan_petz_abbr(t: *strings::iterator) (str | parsed) = {
	let start = *t;
	let quoted = scan_rune(t, void, parsed_done)? == '<';

	if (!quoted) {
		strings::prev(t);
	};

	for (let r => strings::next(t)) {
		if (quoted) {
			if (r == '<') return parsed_err;
			if (r == '>') break;
			if (!(ascii::isalnum(r) || r == '+' || r == '-')) {
				strings::prev(t);
				break;
			};
		} else {
			if (!ascii::isalpha(r)) {
				strings::prev(t);
				break;
			};
		};
	};

	let end = *t;
	if (quoted) {
		strings::next(&start);
		strings::prev(&end);
	};

	let abbr = strings::slice(&start, &end);
	if (len(abbr) < 3) {
		return parsed_err;
	};

	return abbr;
};

fn scan_petz_ruledate(
	t: *strings::iterator,
	default: parsed,
) (petz_ruledate | parsed) = {
	switch (scan_rune(t, void, default)?) {
	case 'M' =>
		// Mm.w.d
		let m = scan_num(t, 1, 2, parsed_err)?: u8;
		scan_rune(t, '.', parsed_err)?;
		let w = scan_num(t, 1, 1, parsed_err)?: u8;
		scan_rune(t, '.', parsed_err)?;
		let d = scan_num(t, 1, 1, parsed_err)?: u8;
		if (m < 1 || 12 < m) return parsed_err;
		if (w < 1 || 5 < w)  return parsed_err;
		if (d < 0 || 6 < d) return parsed_err;
		return (m, w, d): petz_ruledate_weekdate;
	case 'J' =>
		// Jn
		let n = scan_num(t, 1, 3, parsed_err)?: petz_ruledate_julian;
		if (n < 1 || 365 < n) return parsed_err;
		return n;
	case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' =>
		// n
		strings::prev(t);
		let n = scan_num(t, 1, 3, parsed_err)?: petz_ruledate_ordinal;
		if (n < 1 || 365 < n) return parsed_err;
		return n;
	case =>
		return parsed_err;
	};
};

fn petz_is_twophased(p: petz) bool = {
	return p.dst_abbr != "";
};

export fn lookupzone_posix(loc: locality, d: *date) *zonephase = {
	let p = loc.petz;

	if (!petz_is_twophased(p)) {
		let pz = zonephase{
			zoff = p.std_offset,
			abbr = p.std_abbr,
			...
		};
		return search_zonephase(pz, loc.phases...);
	};

	let stdphase = zonephase{
		zoff = p.std_offset,
		abbr = p.std_abbr,
		...
	};
	let dstphase = zonephase{
		zoff = p.dst_offset,
		abbr = p.dst_abbr,
		...
	};

	// virtual dates for STD and DST.
	// one of these is the correct date to be observed.
	//
	// we use vstd to help observe STD time with the STD offset to see where
	// it falls in relation to the two most "recent" STD->DST
	// zonetransition. vice versa for vdst.
	let vstd = *d; vstd.zonephase = &stdphase;
	let vdst = *d; vdst.zonephase = &dstphase;

	// the daydates of the two most recent zonephase transitions for STD and
	// DST each.
	//
	// we record two because of edge cases around the year boundary, where
	// vstd and vdst can observe different years, causing the calculated
	// transitions' daydates to be in different years. we account for this
	// below.
	let std_daydate1 = 0i64; let std_daydate2 = 0i64;
	let dst_daydate1 = 0i64; let dst_daydate2 = 0i64;

	match (p.dst_startdate) {
	case let r: petz_ruledate_julian =>
		abort("POSIX Timezone detail unimplemented (julian)"); // TODO

	case let r: petz_ruledate_ordinal =>
		abort("POSIX Timezone detail unimplemented (ordinal)"); // TODO

	case let r: petz_ruledate_weekdate =>
		let (month, week, weekday) = r;
		let weekday = (weekday + 6) % 7; // Sunday=0 -> Monday=0

		let weekday_monthfirst = calc_weekday(
			calc_daydate__ymd(_year(&vstd), month: int, 1)!
		);
		let monthday = (
			1
			+ (weekday: int - weekday_monthfirst)
			+ (week: int - 1) * 7
		);
		if (monthday > calc_days_in_month(_year(&vstd), month: int)) {
			monthday -= 7;
		};

		dst_daydate1 = calc_daydate__ymd(
			_year(&vstd) - 1, month: int, monthday,
		)!;
		dst_daydate2 = calc_daydate__ymd(
			_year(&vstd), month: int, monthday,
		)!;
	};

	match (p.dst_enddate) {
	case let r: petz_ruledate_julian =>
		abort("POSIX Timezone detail unimplemented (julian)"); // TODO

	case let r: petz_ruledate_ordinal =>
		abort("POSIX Timezone detail unimplemented (ordinal)"); // TODO

	case let r: petz_ruledate_weekdate =>
		let (month, week, weekday) = r;
		let weekday = (weekday + 6) % 7; // Sunday=0 -> Monday=0

		let weekday_monthfirst = calc_weekday(
			calc_daydate__ymd(_year(&vdst), month: int, 1)!
		);
		let monthday = (
			1
			+ (weekday: int - weekday_monthfirst)
			+ (week: int - 1) * 7
		);
		if (monthday > calc_days_in_month(_year(&vdst), month: int)) {
			monthday -= 7;
		};

		std_daydate1 = calc_daydate__ymd(
			_year(&vdst) - 1, month: int, monthday,
		)!;
		std_daydate2 = calc_daydate__ymd(
			_year(&vdst), month: int, monthday,
		)!;
	};

	// handle edge cases near the year boundaries
	//
	// (A) DST: |  1.....   |  2.....   |  '.....   |
	//     STD: |..      1..|..      2..|..      '..|
	//                            ^
	//
	// (B) DST: |  1.....   |  2.....   |  '.....   |
	//     STD: |..      '..|..      1..|..      2..|
	//                                  ^
	//
	// (C) DST: |..      1..|..      2..|..      '..|
	//     STD: |  1.....   |  2.....   |  '.....   |
	//                            ^
	//
	// (D) DST: |..      '..|..      1..|..      2..|
	//     STD: |  1.....   |  2.....   |  '.....   |
	//                              ^
	//
	let (dst_daydate, std_daydate) = :dd {
		if (dst_daydate2 < std_daydate1) { // (B)
			yield :dd, (dst_daydate2, std_daydate1);
		};

		if (std_daydate2 < dst_daydate1) { // (D)
			yield :dd, (dst_daydate1, std_daydate2);
		};

		yield (dst_daydate2, std_daydate2);
	};

	let after_dst = {
		if (daydate(&vstd) < dst_daydate) yield false;
		if (daydate(&vstd) > dst_daydate) yield true;
		if (daytime(&vstd) < p.dst_starttime) yield false;
		if (daytime(&vstd) >= p.dst_starttime) yield true;
		abort("Unreachable");
	};

	let after_std = {
		if (daydate(&vdst) < std_daydate) yield false;
		if (daydate(&vdst) > std_daydate) yield true;
		if (daytime(&vdst) < p.dst_endtime) yield false;
		if (daytime(&vdst) >= p.dst_endtime) yield true;
		abort("Unreachable");
	};

	let phase = if (dst_daydate < std_daydate) {
		yield if (!after_dst && !after_std) {
			yield stdphase;
		} else if (after_dst && !after_std) {
			yield dstphase;
		} else if (after_dst && after_std) {
			yield stdphase;
		} else if (!after_dst && after_std) {
			yield dstphase;
		} else {
			abort("POSIX Timezone error");
		};
	} else if (std_daydate < dst_daydate) {
		yield if (!after_std && !after_dst) {
			yield dstphase;
		} else if (after_std && !after_dst) {
			yield stdphase;
		} else if (after_std && after_dst) {
			yield dstphase;
		} else if (!after_std && after_dst) {
			yield stdphase;
		} else {
			abort("POSIX Timezone error");
		};
	} else {
		abort("POSIX Timezone error");
	};

	return search_zonephase(phase, loc.phases...);
};

fn search_zonephase(z: zonephase, haystack: zonephase...) *zonephase = {
	for (let hz &.. haystack) {
		// TODO: full comparison with .dst doesnt work. maybe it should.
		if (z.zoff == hz.zoff && z.abbr == hz.abbr) {
			return hz;
		};
	};

	abort("POSIX Timezone missing zonephase");
};
