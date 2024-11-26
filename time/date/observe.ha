// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// Observes a [[date]]'s [[zonephase]].
export fn zone(d: *date) zonephase = {
	match (d.zonephase) {
	case let z: *zonephase =>
		return *z;
	case null =>
		let lookup = match (d.loc.lookupzone) {
		case let l: *zonelookuper =>
			yield l;
		case null =>
			yield &lookupzone: *zonelookuper;
		};
		const z = lookup(d.loc, d);
		d.zonephase = z;
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
			d.loc, to_instant(*d), zone(d).zoff,
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
			d.loc, to_instant(*d), zone(d).zoff,
		);
		d.daytime = dt;
		d.daydate = dd;
		return dt;
	};
};

// These functions are renamed to avoid namespace conflicts, like in the
// parameters of the [[new]] function.

// Observes a [[date]]'s era.
export fn era(d: *date) int = _era(d);

// Observes a [[date]]'s year.
export fn year(d: *date) int = _year(d);

// Observes a [[date]]'s month of the year. Range January=1 to December=12.
export fn month(d: *date) int = _month(d);

// Observes a [[date]]'s day of the month. Range 1 to 31.
export fn day(d: *date) int = _day(d);

// Observes a [[date]]'s day of the week. Range Monday=0 to Sunday=6.
export fn weekday(d: *date) int = _weekday(d);

// Observes a [[date]]'s ordinal day of the year. Range 1 to 366.
export fn yearday(d: *date) int = _yearday(d);

// Observes a [[date]]'s ISO week-numbering year.
export fn isoweekyear(d: *date) int = _isoweekyear(d);

// Observes a [[date]]'s Gregorian week starting Monday. Range 0 to 53.
// All days in a year before the year's first Monday belong to week 0.
export fn week(d: *date) int = _week(d);

// Observes a [[date]]'s Gregorian week starting Sunday. Range 0 to 53.
// All days in a year before the year's first Sunday belong to week 0.
export fn sundayweek(d: *date) int = _sundayweek(d);

// Observes a [[date]]'s ISO week-numbering week. Range 0 to 53.
export fn isoweek(d: *date) int = _isoweek(d);

// Observes a [[date]]'s hour of the day.
export fn hour(d: *date) int = _hour(d);

// Observes a [[date]]'s minute of the hour.
export fn minute(d: *date) int = _minute(d);

// Observes a [[date]]'s second of the minute.
export fn second(d: *date) int = _second(d);

// Observes a [[date]]'s nanosecond of the second.
export fn nanosecond(d: *date) int = _nanosecond(d);

fn _era(d: *date) int = {
	match (d.era) {
	case void =>
		d.era = calc_era(
			_year(d),
		);
		return d.era: int;
	case let a: int =>
		return a;
	};
};

fn _year(d: *date) int = {
	match (d.year) {
	case void =>
		const ymd = calc_ymd(
			daydate(d),
		);
		d.year = ymd.0;
		d.month = ymd.1;
		d.day = ymd.2;
		return d.year: int;
	case let y: int =>
		return y;
	};
};

fn _month(d: *date) int = {
	match (d.month) {
	case void =>
		const ymd = calc_ymd(
			daydate(d),
		);
		d.year = ymd.0;
		d.month = ymd.1;
		d.day = ymd.2;
		return d.month: int;
	case let y: int =>
		return y;
	};
};

fn _day(d: *date) int = {
	match (d.day) {
	case void =>
		const ymd = calc_ymd(
			daydate(d),
		);
		d.year = ymd.0;
		d.month = ymd.1;
		d.day = ymd.2;
		return d.day: int;
	case let y: int =>
		return y;
	};
};

fn _weekday(d: *date) int = {
	match (d.weekday) {
	case void =>
		d.weekday = calc_weekday(
			daydate(d),
		);
		return d.weekday: int;
	case let y: int =>
		return y;
	};
};

fn _yearday(d: *date) int = {
	match (d.yearday) {
	case void =>
		d.yearday = calc_yearday(
			_year(d),
			_month(d),
			_day(d),
		);
		return d.yearday: int;
	case let yd: int =>
		return yd;
	};
};

fn _isoweekyear(d: *date) int = {
	match (d.isoweekyear) {
	case void =>
		d.isoweekyear = calc_isoweekyear(
			_year(d),
			_month(d),
			_day(d),
			_weekday(d),
		);
		return d.isoweekyear: int;
	case let iwy: int =>
		return iwy;
	};
};

fn _week(d: *date) int = {
	match (d.week) {
	case void =>
		d.week = calc_week(
			_yearday(d),
			_weekday(d),
		);
		return d.week: int;
	case let w: int =>
		return w;
	};
};

fn _sundayweek(d: *date) int = {
	match (d.sundayweek) {
	case void =>
		d.sundayweek = calc_sundayweek(
			_yearday(d),
			_weekday(d),
		);
		return d.sundayweek: int;
	case let w: int =>
		return w;
	};
};

fn _isoweek(d: *date) int = {
	match (d.isoweek) {
	case void =>
		d.isoweek = calc_isoweek(
			_year(d),
			_week(d),
		);
		return d.isoweek: int;
	case let iw: int =>
		return iw;
	};
};

fn _hour(d: *date) int = {
	match (d.hour) {
	case void =>
		const hmsn = calc_hmsn(
			daytime(d),
		);
		d.hour = hmsn.0;
		d.minute = hmsn.1;
		d.second = hmsn.2;
		d.nanosecond = hmsn.3;
		return d.hour: int;
	case let h: int =>
		return h;
	};
};

fn _minute(d: *date) int = {
	match (d.minute) {
	case void =>
		const hmsn = calc_hmsn(
			daytime(d),
		);
		d.hour = hmsn.0;
		d.minute = hmsn.1;
		d.second = hmsn.2;
		d.nanosecond = hmsn.3;
		return d.minute: int;
	case let m: int =>
		return m;
	};
};

fn _second(d: *date) int = {
	match (d.second) {
	case void =>
		const hmsn = calc_hmsn(
			daytime(d),
		);
		d.hour = hmsn.0;
		d.minute = hmsn.1;
		d.second = hmsn.2;
		d.nanosecond = hmsn.3;
		return d.second: int;
	case let s: int =>
		return s;
	};
};

fn _nanosecond(d: *date) int = {
	match (d.nanosecond) {
	case void =>
		const hmsn = calc_hmsn(
			daytime(d),
		);
		d.hour = hmsn.0;
		d.minute = hmsn.1;
		d.second = hmsn.2;
		d.nanosecond = hmsn.3;
		return d.nanosecond: int;
	case let n: int =>
		return n;
	};
};
