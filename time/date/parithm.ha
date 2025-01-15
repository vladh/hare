// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Nominal unitary periods of the Gregorian chronology. Used for chronological
// arithmetic.
export type step = enum {
	NANOSECOND = 0b000000001,
	SECOND     = 0b000000010,
	MINUTE     = 0b000000100,
	HOUR       = 0b000001000,
	DAY        = 0b000010000,
	WEEK       = 0b000100000,
	MONTH      = 0b001000000,
	YEAR       = 0b010000000,
	ERA        = 0b100000000,

	// TODO: consider adding NONE=0, ALL=YEAR|MONTH|..., etc
	// TODO: consider adding ISOWEEKYEAR, ISOWEEK
};

// Calculates the nominal [[step]] difference between two [[date]]s.
export fn hop(a: date, b: date, u: step) i64 = {
	switch (u) {
	case step::ERA =>
		return era(&b) - era(&a);
	case step::YEAR =>
		return pdiff(a, b).years;
	case step::MONTH =>
		const d = pdiff(a, b);
		return d.years * 12 + d.months;
	case step::WEEK =>
		return hop(a, b, step::DAY) / 7;
	case step::DAY =>
		return daydate(&b) - daydate(&a);
	case step::HOUR =>
		return hop(a, b, step::DAY) * 24 + pdiff(a, b).hours;
	case step::MINUTE =>
		return hop(a, b, step::HOUR) * 60 + pdiff(a, b).minutes;
	case step::SECOND =>
		return hop(a, b, step::MINUTE) * 60 + pdiff(a, b).seconds;
	case step::NANOSECOND =>
		return hop(a, b, step::SECOND) * 1000000000 + pdiff(a, b).nanoseconds;
	};
};

// Truncates the given [[date]] at the provided nominal [[step]].
// The [[zflag]] parameter affects the final result. Example:
//
// 	// On this day in Sao Paulo, a +1 hour jump occurs at 00:00.
// 	// The time range 00:00..00:59 is never observed.
// 	//
// 	// 2000-10-08 12:00:00.000000000 -0200 -02 America/Sao_Paulo
// 	let a = date::new(chrono::tz("America/Sao_Paulo")!, -2 * time::HOUR,
// 		2000, 10,  8, 12)!
// 	//
// 	// 2000-10-08 01:00:00.000000000 -0200 -02 America/Sao_Paulo
// 	let b = date::truncate(a, date::zflag::GAP_END, date::step::DAY)!;
//
export fn truncate(d: date, zf: zflag, u: step) (date | invalid | zfunresolved) = {
	switch (u) {
	case step::ERA =>
		return new(d.loc, zf,
			1, 1, 1,
			0, 0, 0, 0,
		);
	case step::YEAR =>
		return new(d.loc, zf,
			_year(&d), 1, 1,
			0, 0, 0, 0,
		);
	case step::MONTH =>
		return new(d.loc, zf,
			_year(&d), _month(&d), 1,
			0, 0, 0, 0,
		);
	case step::WEEK =>
		const dd = daydate(&d) - _weekday(&d);
		const ymd = calc_ymd(dd);
		return new(d.loc, zf,
			ymd.0, ymd.1, ymd.2,
			0, 0, 0, 0,
		);
	case step::DAY =>
		return new(d.loc, zf,
			_year(&d), _month(&d), _day(&d),
			0, 0, 0, 0,
		);
	case step::HOUR =>
		return new(d.loc, zf,
			_year(&d), _month(&d), _day(&d),
			_hour(&d), 0, 0, 0,
		);
	case step::MINUTE =>
		return new(d.loc, zf,
			_year(&d), _month(&d), _day(&d),
			_hour(&d), _minute(&d), 0, 0,
		);
	case step::SECOND =>
		return new(d.loc, zf,
			_year(&d), _month(&d), _day(&d),
			_hour(&d), _minute(&d), _second(&d), 0,
		);
	case step::NANOSECOND =>
		return d;
	};
};

@test fn hop() void = {
	const cases = [
		(
			new(UTC, 0,  1994,  8, 27,  11, 20,  1,         2)!,
			new(UTC, 0,  2022,  1,  5,  13, 53, 30,        20)!,
			(27, 328, 1427, 9993, 239834, 14390073, 863404409i64,
				(863404409i64 * time::SECOND) + 18),
		),
		(
			new(UTC, 0,  1994,  8, 27,  11, 20,  1,         0)!,
			new(UTC, 0,  1994,  8, 28,  11, 20,  1,         2)!,
			(0, 0, 0, 1, 24, 1440, 86400i64,
				(86400i64 * time::SECOND) + 2),
		),
		(
			new(UTC, 0,  1994,  8, 27,  11, 20,  1,         0)!,
			new(UTC, 0,  1994,  8, 27,  11, 20,  1,         0)!,
			(0, 0, 0, 0, 0, 0, 0i64, 0i64),
		),
		(
			new(UTC, 0,  -500,  1,  1,   0, 59,  1,         0)!,
			new(UTC, 0,  2000,  1,  1,  23,  1,  1,         0)!,
			(2500, 30000, 130443, 913106, 913106 * 24 + 22,
				(913106 * 24 + 22) * 60 + 2,
				((913106 * 24 + 22) * 60 + 2) * 60i64,
				(((913106 * 24 + 22) * 60 + 2) * 60i64 *
					time::SECOND)),
		),
	];
	for (let (da, db, expected) .. cases) {
		assert(hop(da, db, step::YEAR) == expected.0,
			"invalid diff_in_years() result");
		assert(hop(da, db, step::MONTH) == expected.1,
			"invalid diff_in_months() result");
		assert(hop(da, db, step::WEEK) == expected.2,
			"invalid diff_in_weeks() result");
		assert(hop(da, db, step::DAY) == expected.3,
			"invalid diff_in_days() result");
		assert(hop(da, db, step::HOUR) == expected.4,
			"invalid diff_in_hours() result");
		assert(hop(da, db, step::MINUTE) == expected.5,
			"invalid diff_in_minutes() result");
		assert(hop(da, db, step::SECOND) == expected.6,
			"invalid diff_in_seconds() result");
		assert(hop(da, db, step::NANOSECOND) == expected.7,
			"invalid diff_in_nanoseconds() result");
	};
};

@test fn truncate() void = {
	const d = new(UTC, 0, 1994, 8, 27, 11, 20, 1, 2)!;

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::ERA)!,
			&new(UTC, 0, 1, 1, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 01");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::YEAR)!,
			&new(UTC, 0, 1994, 1, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 02");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::MONTH)!,
			&new(UTC, 0, 1994, 8, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 03");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::WEEK)!,
			&new(UTC, 0, 1994, 8, 22, 0, 0, 0, 0)!)!,
		"invalid truncate() result 04");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::DAY)!,
			&new(UTC, 0, 1994, 8, 27, 0, 0, 0, 0)!)!,
		"invalid truncate() result 05");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::HOUR)!,
			&new(UTC, 0, 1994, 8, 27, 11, 0, 0, 0)!)!,
		"invalid truncate() result 06");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::MINUTE)!,
			&new(UTC, 0, 1994, 8, 27, 11, 20, 0, 0)!)!,
		"invalid truncate() result 07");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::SECOND)!,
			&new(UTC, 0, 1994, 8, 27, 11, 20, 1, 0)!)!,
		"invalid truncate() result 08");

	assert(chrono::simultaneous(
			&truncate(d, zflag::CONTIG, step::NANOSECOND)!,
			&d)!,
		"invalid truncate() result 09");
};
