// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Invalid [[date]].
export type invalid = !void;

// A date/time object; a [[time::chrono::moment]] wrapper optimized for the
// Gregorian chronology, and by extension a [[time::instant]] wrapper.
//
// This object should be treated as private and immutable. Directly mutating its
// fields causes undefined behaviour when used with module functions. Likewise,
// interrogating the fields' type and value (e.g. using match statements) is
// also improper.
//
// A date observes various chronological values, cached in its fields. To
// evaluate and obtain these values, use the various observer functions
// ([[year]], [[hour]], etc.). These values are derived from the embedded moment
// information, and thus are guaranteed to be valid.
//
// See [[virtual]] for an public, mutable, intermediary representation of a
// date, which waives guarantees of validity.
export type date = struct {
	chrono::moment,
	// The [[locality]] with which to interpret this moment.
	loc: locality,
	// The observed [[zone]].
	zonephase: nullable *zonephase,
	// The observed [[daydate]] (scalar day number)
	// since an abitrary epoch (e.g. the Unix epoch 1970-01-01).
	daydate: (void | i64),
	// The observed [[daytime]] (amount of daytime progressed in a day),
	// comparable with [[time::duration]].
	daytime: (void | i64),
	// The observed [[era]].
	era:         (void | int),
	// The observed [[year]].
	year:        (void | int),
	// The observed [[month]].
	month:       (void | int),
	// The observed [[day]].
	day:         (void | int),
	// The observed [[yearday]].
	yearday:     (void | int),
	// The observed [[isoweekyear]].
	isoweekyear: (void | int),
	// The observed [[isoweek]].
	isoweek:     (void | int),
	// The observed [[week]].
	week:        (void | int),
	// The observed [[sundayweek]].
	sundayweek:  (void | int),
	// The observed [[weekday]].
	weekday:     (void | int),
	// The observed [[hour]].
	hour:        (void | int),
	// The observed [[minute]].
	minute:      (void | int),
	// The observed [[second]].
	second:      (void | int),
	// The observed [[nanosecond]].
	nanosecond:  (void | int),
};

fn init() date = date {
	sec         = 0,
	nsec        = 0,
	tsc         = &chrono::utc,
	loc         = UTC,
	zonephase   = null,
	daydate     = void,
	daytime     = void,

	era         = void,
	year        = void,
	month       = void,
	day         = void,
	yearday     = void,
	isoweekyear = void,
	isoweek     = void,
	week        = void,
	sundayweek  = void,
	weekday     = void,

	hour        = void,
	minute      = void,
	second      = void,
	nanosecond  = void,
};

// Evaluates and populates all of a [[date]]'s fields.
fn all(d: *date) *date = {
	_era(d);
	_year(d);
	_month(d);
	_day(d);
	_yearday(d);
	_isoweekyear(d);
	_isoweek(d);
	_week(d);
	_sundayweek(d);
	_weekday(d);

	_hour(d);
	_minute(d);
	_second(d);
	_nanosecond(d);

	return d;
};

// Creates a new [[date]]. Accepts a [[time::chrono::locality]], a zone-offset,
// and up to seven nominal fields applied in the following order:
//
// - year
// - month
// - day
// - hour
// - minute
// - second
// - nanosecond
//
// 8 or more fields causes an abort. If omitted, the month and day default to 1,
// and the rest default to 0.
//
// If the desired zone-offset is known, it can be given as a [[time::duration]].
// Otherwise, use a zflag. See [[zflag]] on its effects to the result.
//
// An invalid combination of provided date/time/zoff values returns [[invalid]].
//
// Examples:
//
// 	// 0000-01-01 00:00:00.000000000 +0000 UTC UTC
// 	date::new(date::UTC, date::zflag::CONTIG);
//
// 	// 2000-01-02 15:04:05.600000000 +0000 UTC UTC
// 	date::new(date::UTC, 0,
// 		2000,  1,  2,  15,  4,  5, 600000000);
//
// 	// 2000-01-02 15:00:00.000000000 +0100 CET Europe/Amsterdam
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		1 * time::HOUR, // standard time in January
// 		2000,  1,  2,  15);
//
// 	// Could return [[zfunresolved]] by encountering a timezone transition.
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::CONTIG,
// 		fields...);
//
// 	// Will never return [[zfunresolved]].
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::LAP_EARLY | date::zflag::GAP_END,
// 		fields...);
//
// 	// On this day in Amsterdam, the clock jumped +1 hour at 02:00.
// 	// 02:30 is never observed. Note the difference in zone-offset.
// 	//
// 	// 2000-03-26 01:59:59.999999999 +0100 CET Europe/Amsterdam
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::GAP_START,
// 		2000,  3, 26,   2, 30);
// 	//
// 	// 2000-03-26 03:00:00.000000000 +0200 CET Europe/Amsterdam
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::GAP_END,
// 		2000,  3, 26,   2, 30);
//
// 	// On this day in Amsterdam, the clock jumped -1 hour at 03:00.
// 	// 02:30 is observed twice. Note the difference in zone-offset.
// 	//
// 	// 2000-10-29 02:30:00.000000000 +0200 CET Europe/Amsterdam
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::LAP_EARLY,
// 		2000, 10, 29,   2, 30);
// 	//
// 	// 2000-10-29 02:30:00.000000000 +0100 CET Europe/Amsterdam
// 	date::new(time::chrono::tz("Europe/Amsterdam")!,
// 		date::zflag::LAP_LATE,
// 		2000, 10, 29,   2, 30);
//
export fn new(
	loc: locality,
	zoff: (time::duration | zflag),
	fields: int...
) (date | invalid | zfunresolved) = {
	let _fields: [_]int = [
		0, 1, 1,    // year month day
		0, 0, 0, 0, // hour minute second nanosecond
	];

	assert(len(fields) <= len(_fields),
		"time::date::new(): Too many field arguments");
	_fields[..len(fields)] = fields;

	let v = newvirtual();

	v.vloc       = loc;
	v.zoff       = zoff;
	v.year       = _fields[0];
	v.month      = _fields[1];
	v.day        = _fields[2];
	v.hour       = _fields[3];
	v.minute     = _fields[4];
	v.second     = _fields[5];
	v.nanosecond = _fields[6];

	let d = (realize(v, loc) as (date | invalid | zfunresolved))?;

	let gap_flag_specified = (
		zoff is zflag
		&& zoff as zflag & (zflag::GAP_START | zflag::GAP_END) != 0
	);

	// Some invalid inputs could theoretically calculate a valid date.
	// zflags GAP_START and GAP_END may cause the resultant date to change.
	// unless "GAP_" flags were specified, check if input values match the
	// resultant date's values.
	if (!gap_flag_specified) {
		if (
			_fields[0] != _year(&d)
			|| _fields[1] != _month(&d)
			|| _fields[2] != _day(&d)
			|| _fields[3] != _hour(&d)
			|| _fields[4] != _minute(&d)
			|| _fields[5] != _second(&d)
			|| _fields[6] != _nanosecond(&d)
		) {
			return invalid;
		};
	};

	return d;
};

// Returns a [[date]] of the current system time using
// [[time::clock::REALTIME]], in the [[UTC]] locality.
export fn now() date = {
	return from_instant(UTC, time::now(time::clock::REALTIME));
};

// Returns a [[date]] of the current system time using
// [[time::clock::REALTIME]], in the [[time::chrono::LOCAL]] locality.
export fn localnow() date = {
	return from_instant(LOCAL, time::now(time::clock::REALTIME));
};

// Creates a [[date]] from a [[time::chrono::moment]].
export fn from_moment(loc: locality, m: chrono::moment) (date | chrono::tscmismatch) = {
	if (loc.tsc != m.tsc) {
		return (loc.tsc, m.tsc): chrono::tscmismatch;
	};

	const d = init();
	d.sec = m.sec;
	d.nsec = m.nsec;
	d.tsc = m.tsc;
	d.loc = loc;
	return d;
};

// Creates a [[date]] from a [[time::instant]] in a [[time::chrono::locality]].
export fn from_instant(loc: locality, i: time::instant) date = {
	return from_moment(loc, chrono::new(loc.tsc, i))!;
};

// Creates a [[date]] from a given [[locality]], zone-offset, daydate, and
// time-of-day.
export fn from_datetime(
	loc: locality,
	zo: time::duration,
	dd: i64,
	dt: i64,
) date = {
	return from_instant(loc, calc_instant(loc.daylength, zo, dd, dt));
};

// Creates a [[date]] from a string, parsed according to a layout format.
// See [[parse]] and [[format]]. Example:
//
// 	let new = date::from_str(
// 		date::STAMPLOC,
// 		"2000-01-02 15:04:05.600000000 +0100 CET Europe/Amsterdam",
// 		chrono::tz("Europe/Amsterdam")!
// 	)!;
//
// At least a complete calendar date has to be provided. If the hour, minute,
// second, or nanosecond values are not provided, they default to 0.
// If the zone-offset or zone-abbreviation are not provided, the [[zflags]]s
// LAP_EARLY and GAP_END are used.
//
// The date's [[time::chrono::locality]] will be selected from the provided
// locality arguments. The 'name' field of these localities will be matched
// against the parsed result of the %L specifier. If %L is not specified,
// or if no locality is provided, [[UTC]] is used.
export fn from_str(
	layout: str,
	s: str,
	locs: locality...
) (date | parsefail | insufficient | invalid) = {
	const v = newvirtual();
	v.zoff = zflag::LAP_EARLY | zflag::GAP_END;
	v.hour = 0;
	v.minute = 0;
	v.second = 0;
	v.nanosecond = 0;

	parse(&v, layout, s)?;

	if (v.locname is void || len(locs) == 0) {
		v.vloc = UTC;
	};

	return realize(v, locs...) as (date | insufficient | invalid);
};

// Extracts the [[chrono::moment]] of the given [[date]].
export fn to_moment(d: date) chrono::moment = *(&d: *chrono::moment);

// Extracts the [[time::instant]] of the given [[date]].
export fn to_instant(d: date) time::instant = *(&d: *time::instant);

// Returns true if two [[date]]s represent the same time in the same locality,
// which is to say that their [[locality]] and [[time::instant]] are both equal.
// Their observed values and representations in a chronology should be the same
// in all cases.
//
// See [[simultaneous]] to determine if two moments represent the same date in
// time regardless of locality.
export fn coincident(a: *date, b: *date) bool = {
	return a.tsc == b.tsc && a.sec == b.sec && a.nsec == b.nsec;
};

// Returns true if two [[date]]s represent the same date in time, regardless
// of locality.
//
// The moments are compared as [[time::instant]]s; their observed chronological
// values and representations are ignored.
//
// If the moments' associated [[timescale]]s are different, they will be
// converted to [[tai]] instants first. Any [[discontinuity]] occurence will be
// returned. If a discontinuity against TAI amongst the two timescales exist,
// consider converting such instants manually.
//
// See [[coincident]] to determine if two [[date]]s are equal with respect to
// both time and locality.
export fn simultaneous(a: *date, b: *date) (bool | chrono::tscmismatch) = {
	return 0 == chrono::compare(a, b)?;
};

// Calculates the observed daydate and time-of-day of a [[time::instant]] in a
// [[locality]] at a particular zone-offset.
fn calc_datetime(
	loc: locality,
	inst: time::instant,
	zoff: time::duration,
) (i64, time::duration) = {
	const i = time::add(inst, zoff);
	const day = loc.daylength;
	const daysec = day / time::SECOND;
	const dd = if (i.sec >= 0) i.sec / daysec else (i.sec + 1) / daysec - 1;
	const dt = ((i.sec % daysec + daysec) * time::SECOND + i.nsec) % day;
	return (dd, dt);
};

fn calc_instant(
	day: time::duration, // length of a day
	zo: time::duration,  // zone-offset
	dd: i64,             // date since epoch
	dt: i64,             // time since start of day (ns)
) time::instant = {
	const daysec = (day / time::SECOND): i64;
	const dayrem = day % time::SECOND;
	let i = time::instant {
		sec = dd * daysec,
		nsec = 0,
	};
	i = time::add(i, dd * dayrem);
	i = time::add(i, dt);
	i = time::add(i, -zo);
	return i;
};

@test fn from_str() void = {
	let testcases: [_](str, str, []locality, (date | error)) = [
		(STAMPLOC, "2001-02-03 15:16:17.123456789 +0000 UTC UTC", [],
			new(UTC, 0, 2001, 2, 3, 15, 16, 17, 123456789)!),
		(STAMP, "2001-02-03 15:16:17", [],
			new(UTC, 0, 2001, 2, 3, 15, 16, 17)!),
		(RFC3339, "2001-02-03T15:16:17+0000", [],
			new(UTC, 0, 2001, 2, 3, 15, 16, 17)!),
		("%F", "2009-06-30", [],
			new(UTC, 0, 2009, 6, 30)!),
		("%F %L", "2009-06-30 GPS", [TAI, GPS],
			new(GPS, 0, 2009, 6, 30)!),
		("%F %T", "2009-06-30 01:02:03", [],
			new(UTC, 0, 2009, 6, 30, 1, 2, 3)!),
		("%FT%T%z", "2009-06-30T18:30:00Z", [],
			new(UTC, 0, 2009, 6, 30, 18, 30)!),
		("%FT%T.%N%z", "2009-06-30T18:30:00.987654321Z", [],
			new(UTC, 0, 2009, 6, 30, 18, 30, 0, 987654321)!),
		// TODO: for the tests overhaul, when internal test timezones
		// are available, check for %L
		//("%FT%T%z %L", "2009-06-30T18:30:00+0200 Europe/Amsterdam", [amst],
		//	new(amst, 2 * time::HOUR, 2009, 6, 30, 18, 30)!),

		("%Y", "a", [], (0z, 'a'): parsefail),
		("%X", "2008", [], (0z, '2'): parsefail),
	];

	let buf: [64]u8 = [0...];
	for (let tc .. testcases) {
		const expect = tc.3;
		const actual = from_str(tc.0, tc.1, tc.2...);

		match (expect) {
		case let e: date =>
			assert(actual is date, "wanted 'date', got 'error'");
			assert(simultaneous(&(actual as date), &e)!,
				"incorrect 'date' value");
		case let e: parsefail =>
			assert(actual is parsefail,
				"wanted 'parsefail', got other");
		case insufficient =>
			assert(actual is insufficient,
				"wanted 'insufficient', got other");
		case invalid =>
			assert(actual is invalid,
				"wanted 'invalid', got other");
		};
	};
};
