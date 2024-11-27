// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time::chrono;

// Calculates the [[span]] between two [[date]]s, from A to B.
// The returned span, provided to [[reckon]] along with A, will produce B,
// regardless of the [[calculus]] used. All the span's non-zero fields will
// have the same sign.
export fn traverse(a: date, b: date) span = {
	let s = span { ... };

	if (chrono::compare(&a, &b) == 0) {
		return s;
	};

	let reverse = chrono::compare(&a, &b) > 0;
	if (reverse) {
		let tmp = a;
		a = b;
		b = tmp;
	};

	s.years = _year(&b) - _year(&a);

	s.months = _month(&b) - _month(&a);
	if (s.months < 0) {
		s.years -= 1;
		s.months += 12;
	};

	s.days = _day(&b) - _day(&a);
	let year = _year(&b);
	let month = _month(&b);
	let monthdays = calc_days_in_month(year, month);
	for (_day(&a) > monthdays || s.days < 0) {
		month -= 1;
		if (month == 0) {
			year -= 1;
			month = 12;
		};
		monthdays = calc_days_in_month(year, month);

		s.months -= 1;
		if (s.months < 0) {
			s.years -= 1;
			s.months += 12;
		};
		s.days += monthdays;
	};

	s.hours = _hour(&b) - _hour(&a);
	if (s.hours < 0) {
		s.days -= 1;
		s.hours += 24;
	};

	s.minutes = _minute(&b) - _minute(&a);
	if (s.minutes < 0) {
		s.hours -= 1;
		s.minutes += 60;
	};

	s.seconds = _second(&b) - _second(&a);
	if (s.seconds < 0) {
		s.minutes -= 1;
		s.seconds += 60;
	};

	s.nanoseconds = _nanosecond(&b) - _nanosecond(&a);
	if (s.nanoseconds < 0) {
		s.seconds -= 1;
		s.nanoseconds += 1000000000; // 10E9
	};

	return if (reverse) neg(s) else s;
};

@test fn traverse() void = {
	const cases = [
		(
			new(UTC, 0, 2021, 1, 15, 0, 0, 0, 0)!,
			new(UTC, 0, 2022, 2, 16, 0, 0, 0, 0)!,
			span {
				years = 1,
				months = 1,
				days = 1,
				...
			},
		),
		(
			new(UTC, 0, 2021, 1, 15, 0, 0, 0, 0)!,
			new(UTC, 0, 2022, 3, 27, 0, 0, 0, 0)!,
			span {
				years = 1,
				months = 2,
				days = 12,
				...
			},
		),
		(
			new(UTC, 0, 2021, 1, 15, 0, 0, 0, 0)!,
			new(UTC, 0, 2022, 3, 14, 0, 0, 0, 0)!,
			span {
				years = 1,
				months = 1,
				days = 27,
				...
			},
		),
		(
			new(UTC, 0, 2021, 1, 15, 0, 0, 0, 0)!,
			new(UTC, 0, 2021, 1, 16, 0, 0, 0, 0)!,
			span {
				days = 1,
				...
			},
		),
		(
			new(UTC, 0, 2021, 1, 15, 0, 0, 0, 0)!,
			new(UTC, 0, 2021, 1, 16, 1, 3, 2, 4)!,
			span {
				days = 1,
				hours = 1,
				minutes = 3,
				seconds = 2,
				nanoseconds = 4,
				...
			},
		),
		(
			new(UTC, 0, 2021, 1, 15, 2, 3, 2, 2)!,
			new(UTC, 0, 2021, 1, 16, 1, 1, 2, 4)!,
			span {
				hours = 22,
				minutes = 58,
				nanoseconds = 2,
				...
			},
		),
		(
			new(UTC, 0,  500, 1, 1, 0, 0, 0, 0)!,
			new(UTC, 0, 3500, 1, 1, 0, 6, 0, 0)!,
			span {
				years = 3000,
				minutes = 6,
				...
			},
		),
		(
			new(UTC, 0, -500, 1, 1, 0, 0, 0, 0)!,
			new(UTC, 0, 2500, 1, 1, 0, 6, 0, 0)!,
			span {
				years = 3000,
				minutes = 6,
				...
			},
		),
		(
			new(UTC, 0, 2000, 1, 1, 0, 0, 0, 0)!,
			new(UTC, 0, 2000, 1, 1, 0, 6, 0, 999999999)!,
			span {
				minutes = 6,
				nanoseconds = 999999999,
				...
			},
		),
		(
			new(UTC, 0, 2000, 1, 1, 0, 6, 0, 999999999)!,
			new(UTC, 0, 2000, 1, 1, 0, 6, 1, 0)!,
			span {
				nanoseconds = 1,
				...
			},
		),
		(
			new(UTC, 0, -4000, 1, 1, 0, 6, 0, 999999999)!,
			new(UTC, 0, 4000,  1, 1, 0, 6, 1, 0)!,
			span {
				years = 8000,
				nanoseconds = 1,
				...
			},
		),
	];
	for (let (da, db, expected) .. cases) {
		const actual = traverse(da, db);
		assert(equalspan(actual, expected), "traverse miscalculation");
	};
};
