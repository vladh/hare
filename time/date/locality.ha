// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use time;
use time::chrono;

// Creates an equivalent [[date]] with a different [[locality]].
//
// If the date's associated [[timescale]] and the target locality's timescale
// are different, a conversion from one to the other via the TAI timescale will
// be attempted. Any [[discontinuity]] occurrence will be returned. If a
// discontinuity against TAI amongst the two timescales exist, consider
// converting such instants manually.
export fn in(loc: locality, d: date) (date | chrono::tscmismatch) = {
	let m = *(&d: *chrono::moment);
	return from_moment(loc, m);
};

// Observes a [[date]]'s observed [[zone]].
export fn ozone(d: *date) zone = {
	match (d.zone) {
	case let z: *zone =>
		return *z;
	case null =>
		const z = lookupzone(d.loc, *(d: *time::instant));
		d.zone = z;
		return *z;
	};
};

// Observes a [[date]]'s observed daydate (day number since epoch).
//
// For dates with [[locality]]s based on the [[utc]], [[tai]], [[gps]], and
// similar timescales, their epoch date should be interpreted as the Unix epoch
// (1970 Janurary 1st). Other timescales may suggest their own interpretations
// applicable to other chronologies.
export fn daydate(d: *date) i64 = {
	match (d.daydate) {
	case let dd: i64 =>
		return dd;
	case void =>
		const (dd, dt) = calc_datetime(
			d.loc, *(d: *time::instant), ozone(d).zoff,
		);
		d.daytime = dt;
		d.daydate = dd;
		return dd;
	};
};

// Observes a [[date]]'s observed time-of-day (amount of daytime progressed in
// a day) as nanoseconds.
export fn daytime(d: *date) i64 = {
	match (d.daytime) {
	case let dt: i64 =>
		return dt;
	case void =>
		const (dd, dt) = calc_datetime(
			d.loc, *(d: *time::instant), ozone(d).zoff,
		);
		d.daytime = dt;
		d.daydate = dd;
		return dt;
	};
};

// Calculates the observed daydate and time-of-day of a [[time::instant]] in a
// [[locality]] at a particular zone offset.
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

// Creates a [[date]] from a given [[locality]], zone offset, daydate, and
// time-of-day.
export fn from_datetime(
	loc: locality,
	zo: time::duration,
	dd: i64,
	dt: i64,
) date = {
	return from_instant(loc, calc_instant(loc.daylength, zo, dd, dt));
};

fn calc_instant(
	day: time::duration, // length of a day
	zo: time::duration,  // zone offset
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

