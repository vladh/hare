// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time::chrono;

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

@test fn truncate() void = {
	const d = new(UTC, 0, 1994, 8, 27, 11, 20, 1, 2)!;

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::ERA)!,
			&new(UTC, 0, 1, 1, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 01");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::YEAR)!,
			&new(UTC, 0, 1994, 1, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 02");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::MONTH)!,
			&new(UTC, 0, 1994, 8, 1, 0, 0, 0, 0)!)!,
		"invalid truncate() result 03");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::WEEK)!,
			&new(UTC, 0, 1994, 8, 22, 0, 0, 0, 0)!)!,
		"invalid truncate() result 04");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::DAY)!,
			&new(UTC, 0, 1994, 8, 27, 0, 0, 0, 0)!)!,
		"invalid truncate() result 05");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::HOUR)!,
			&new(UTC, 0, 1994, 8, 27, 11, 0, 0, 0)!)!,
		"invalid truncate() result 06");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::MINUTE)!,
			&new(UTC, 0, 1994, 8, 27, 11, 20, 0, 0)!)!,
		"invalid truncate() result 07");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::SECOND)!,
			&new(UTC, 0, 1994, 8, 27, 11, 20, 1, 0)!)!,
		"invalid truncate() result 08");

	assert(0 == chrono::compare(
			&truncate(d, zflag::CONTIG, step::NANOSECOND)!,
			&d)!,
		"invalid truncate() result 09");
};
