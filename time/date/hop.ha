// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;

// Calculates the nominal [[step]] difference between two [[date]]s.
//
// Be aware, using date of different [[locality]]s may return unexpected
// results.
export fn hop(a: date, b: date, u: step) i64 = {
	switch (u) {
	case step::ERA =>
		return era(&b) - era(&a);
	case step::YEAR =>
		return traverse(a, b).years;
	case step::MONTH =>
		const d = traverse(a, b);
		return d.years * 12 + d.months;
	case step::WEEK =>
		return hop(a, b, step::DAY) / 7;
	case step::DAY =>
		return daydate(&b) - daydate(&a);
	case step::HOUR =>
		return hop(a, b, step::DAY) * 24 + traverse(a, b).hours;
	case step::MINUTE =>
		return hop(a, b, step::HOUR) * 60 + traverse(a, b).minutes;
	case step::SECOND =>
		return hop(a, b, step::MINUTE) * 60 + traverse(a, b).seconds;
	case step::NANOSECOND =>
		return hop(a, b, step::SECOND) * 1000000000 + traverse(a, b).nanoseconds;
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
