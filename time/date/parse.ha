// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use ascii;
use strconv;
use strings;
use time;

// A parsing error occurred. This shall contain a byteindex of and rune from the
// layout at the position where the parsing error occured.
export type parsefail = !(size, rune);

// TODO: improve parsefail

type parsed = !(parsed_err | parsed_done);

type parsed_err = !void;

type parsed_done = !void;

// Parses date information from a string into a [[virtual]] date, according to a
// layout with specifiers as documented under [[format]]. Partial, sequential,
// aggregative parsing is possible.
//
// 	date::parse(&v, "%Y-%m-%d",    "2019-12-27");
// 	date::parse(&v, "%H:%M:%S.%N", "22:07:08.000000000");
// 	date::parse(&v, "%z %Z %L",    "+0100 CET Europe/Amsterdam");
//
// Parse will return [[parsefail]] if an invalid layout format specifier is
// encountered or if given info string does not match the layout.
export fn parse(v: *virtual, layout: str, info: str) (void | parsefail) = {
	// TODO: specify if extraneous text is ignored. also for from_str().

	const layout_iter = strings::iter(layout);
	const info_iter = strings::iter(info);
	let escaped = false;

	for (let lr => strings::next(&layout_iter)) {
		if (!escaped && lr == '%') {
			escaped = true;
			continue;
		};

		if (!escaped) {
			const ir = match (strings::next(&info_iter)) {
			case done =>
				return (layout_iter.dec.offs, lr): parsefail;
			case let ir: rune =>
				yield ir;
			};
			if (ir != lr) {
				return (layout_iter.dec.offs, lr): parsefail;
			};
			continue;
		};

		escaped = false;

		match (parse_specifier(v, &info_iter, lr)) {
		case parsed_done =>
			void;
		case parsed_err =>
			return (layout_iter.dec.offs, lr): parsefail;
		};
	};

	return void;
};

fn parse_specifier(
	v: *virtual,
	t: *strings::iterator,
	lr: rune,
) parsed = {
	switch (lr) {
	case 'a' =>
		v.weekday = scan_for(t, WEEKDAYS_SHORT...)?;
	case 'A' =>
		v.weekday = scan_for(t, WEEKDAYS...)?;
	case 'b' =>
		v.month = scan_for(t, MONTHS_SHORT...)? + 1;
	case 'B' =>
		v.month = scan_for(t, MONTHS...)? + 1;
	case 'C' =>
		v.century = scan_int(t, 2)?;
	case 'd', 'e' =>
		v.day = scan_int(t, 2)?;
	case 'F' =>
		v.year = scan_int(t, 4)?;
		scan_rune(t, '-', parsed_err)?;
		v.month = scan_int(t, 2)?;
		scan_rune(t, '-', parsed_err)?;
		v.day = scan_int(t, 2)?;
	case 'G' =>
		v.isoweekyear = scan_int(t, 4)?;
	case 'H' =>
		v.hour = scan_int(t, 2)?;
	case 'I' =>
		v.hour12 = scan_int(t, 2)?;
	case 'j' =>
		v.yearday = scan_int(t, 3)?;
	case 'L' =>
		v.locname = scan_name(t)?;
	case 'm' =>
		v.month = scan_int(t, 2)?;
	case 'M' =>
		v.minute = scan_int(t, 2)?;
	case 'N' =>
		let nsec = scan_decimal(t, 9)?;
		v.nanosecond = nsec: int;
		v.vnsec = nsec;
	case 'p' => // AM=false PM=true
		v.ampm = scan_for(t, "AM", "PM", "am", "pm")? % 2 == 1;
	case 's' =>
		v.vsec = scan_num(t, 1, 20, parsed_err)?;
	case 'S' =>
		v.second = scan_int(t, 2)?;
	case 'T' =>
		v.hour = scan_int(t, 2)?;
		scan_rune(t, ':', parsed_err)?;
		v.minute = scan_int(t, 2)?;
		scan_rune(t, ':', parsed_err)?;
		v.second = scan_int(t, 2)?;
	case 'u' =>
		v.weekday = scan_int(t, 1)? - 1;
	case 'U' =>
		v.week = scan_int(t, 2)?;
	case 'V' =>
		v.isoweek = scan_int(t, 2)?;
	case 'w' =>
		v.weekday = scan_int(t, 1)? - 1;
	case 'W' =>
		v.week = scan_int(t, 2)?;
	case 'y' =>
		v.year100 = scan_int(t, 2)?;
	case 'Y' =>
		v.year = scan_int(t, 4)?;
	case 'z' =>
		v.zoff = scan_zoff(t)?;
	case 'Z' =>
		v.zabbr = scan_name(t)?;
	case '%' =>
		scan_rune(t, '%', parsed_err)?;
	case =>
		return parsed_err;
	};

	return parsed_done;
};

// Scans one rune.
// If [want] is void, any rune is accepted.
// If [want] is rune, rune must match [want], or [[parsed_err]] is returned.
// If iterator returns done, [default] is returned.
fn scan_rune(
	iter: *strings::iterator,
	want: (void | rune),
	default: (rune | parsed),
) (rune | parsed) = {
	match (strings::next(iter)) {
	case done =>
		return default;
	case let r: rune =>
		match (want) {
		case void =>
			return r;
		case let w: rune =>
			if (r == w) {
				return r;
			} else {
				return parsed_err;
			};
		};
	};
};

// Scans a number, upto [maxwidth] digits.
// Number must be at least [minwidth] digits, or returns [[parsed_err]].
// If a non-digit is encountered, returns [[parsed_err]].
// If first rune scanned is a non-digit, returns [default].
// If iterator immediately returns done, returns [default].
fn scan_num(
	t: *strings::iterator,
	minwidth: size,
	maxwidth: size,
	default: (i64 | parsed),
) (i64 | parsed) = {
	let start = *t;

	for (let i = 0z; i < maxwidth; i += 1) {
		match (strings::next(t)) {
		case done =>
			if (i == 0z) {
				strings::prev(t);
				return default;
			};
			if (i < minwidth) return parsed_err;
			break;
		case let r: rune =>
			if (!ascii::isdigit(r)) {
				if (i < minwidth) {
					*t = start;
					return parsed_err;
				};
				strings::prev(t);
				break;
			};
			continue;
		};
	};

	return strconv::stoi64(strings::slice(&start, t))!;
};

// Scans a number, left-padded with ' ' or '0'. [width] runes are scanned.
// Digits must be consecutive, or returns [[parsed_err]].
// The last rune must be a digit, or returns [[parsed_err]].
// If an invalid rune is encountered, returns [[parsed_err]].
// If first rune is invalid, returns [default].
// If iterator immediately returns done, returns [default].
fn scan_numpad(
	t: *strings::iterator,
	width: size,
	default: (i64 | parsed),
) (i64 | parsed) = {
	for (let i = 0z; i < width; i += 1) {
		match (strings::next(t)) {
		case done =>
			if (i == 0) {
				strings::prev(t);
				return default;
			};
			return parsed_err;
		case let r: rune =>
			switch (r) {
			case =>
				if (i == 0) {
					strings::prev(t);
					return default;
				};
				return parsed_err;
			case ' ' =>
				continue;
			case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' =>
				strings::prev(t);
				width = width - i;
				return scan_num(t, width, width, parsed_err);
			};
		};
	};

	return parsed_err;
};

// Scans a left-padded number. Returns an int. See [[scan_numpad]].
// If first rune is invalid, returns [[parsed_err]].
fn scan_int(t: *strings::iterator, width: size) (int | parsed_err) = {
	match (scan_numpad(t, width, parsed_err)) {
	case let n: i64 =>
		return n: int;
	case parsed_err =>
		return parsed_err;
	case parsed_done =>
		return abort();
	};
};

// Scans a number as a subunit decimal.
// Scans upto [maxwidth] digits.
// The scanned decimal is right-padded with zeros to reach [maxwidth].
//
// For example, the string
// 	"Foo 42.125 Bar"
// can have its substring
// 	"125"
// interpreted with [maxwidth]=6 as
// 	"125000"
// and scanned as value
// 	125000
//
fn scan_decimal(t: *strings::iterator, maxwidth: size) (i64 | parsed_err) = {
	let start = *t;
	for (let i = 0z; i < maxwidth; i += 1) {
		let rn: rune = match (strings::next(t)) {
		case done =>
			break;
		case let rn: rune =>
			yield rn;
		};
		if (!ascii::isdigit(rn)) {
			strings::prev(t);
			break;
		};
	};
	const s = strings::slice(&start, t);
	match (strconv::stoi64(s)) {
	case let num: i64 =>
		for (let i = 0z; i < maxwidth - len(s); i += 1) {
			num *= 10;
		};
		return num;
	case =>
		return parsed_err;
	};
};

// Scans and parses zone offsets of the form:
//
// 	Z
// 	z
// 	+nn:nn
// 	+nnnn
// 	-nn:nn
// 	-nnnn
//
fn scan_zoff(t: *strings::iterator) (time::duration | parsed_err) = {
	const first = match (strings::next(t)) {
	case done =>
		return parsed_err;
	case let first: rune =>
		yield first;
	};
	if (first == 'Z' || first == 'z') {
		return 0;
	};

	let zo = scan_int(t, 2)? * time::HOUR;

	match (strings::next(t)) {
	case done =>
		return parsed_err;
	case let sep: rune =>
		if (sep != ':') {
			strings::prev(t);
		};
	};

	zo += scan_int(t, 2)? * time::MINUTE;

	if (first == '-') {
		zo *= -1;
	};

	return zo;
};

// Scans and parses locality names, made of printable characters.
fn scan_name(t: *strings::iterator) (str | parsed_err) = {
	let start = *t;
	for (let rn => strings::next(t)) {
		if (!ascii::isgraph(rn)) {
			strings::prev(t);
			break;
		};
	};
	return strings::slice(&start, t);
};

// Scans the iterator for a given list of strings.
// Returns the list index of the matched string.
fn scan_for(iter: *strings::iterator, list: str...) (int | parsed_err) = {
	const name = strings::iterstr(iter);
	if (len(name) == 0) {
		return parsed_err;
	};
	for(let i = 0z; i < len(list); i += 1) {
		if (strings::hasprefix(name, list[i])) {
			// Consume name
			for (let j = 0z; j < len(list[i]); j += 1) {
				strings::next(iter);
			};
			return i: int;
		};
	};
	return parsed_err;
};

@test fn parse() void = {
	let v = newvirtual();
	assert(parse(&v, "foo", "foo") is void, "none: parsefail");
	assert(v.zonephase   == null, "none: non-null zonephase");
	assert(v.daydate     is void, "none: non-void daydate");
	assert(v.daytime     is void, "none: non-void daytime");
	assert(v.era         is void, "none: non-void era");
	assert(v.year        is void, "none: non-void year");
	assert(v.month       is void, "none: non-void month");
	assert(v.day         is void, "none: non-void day");
	assert(v.yearday     is void, "none: non-void yearday");
	assert(v.isoweekyear is void, "none: non-void isoweekyear");
	assert(v.isoweek     is void, "none: non-void isoweek");
	assert(v.week        is void, "none: non-void week");
	assert(v.sundayweek  is void, "none: non-void sundayweek");
	assert(v.weekday     is void, "none: non-void weekday");
	assert(v.hour        is void, "none: non-void hour");
	assert(v.minute      is void, "none: non-void minute");
	assert(v.second      is void, "none: non-void second");
	assert(v.nanosecond  is void, "none: non-void nanosecond");
	assert(v.vloc        is void, "none: non-void vloc");
	assert(v.locname     is void, "none: non-void locname");
	assert(v.zoff        is void, "none: non-void zoff");
	assert(v.zabbr       is void, "none: non-void zabbr");
	assert(v.hour12      is void, "none: non-void hour12");
	assert(v.ampm        is void, "none: non-void ampm");

	let v = newvirtual();
	assert(parse(&v, "%a", "Fri") is void                , "%a: parsefail");
	assert(v.weekday is int                              , "%a: void");
	assert(v.weekday as int == 4                         , "%a: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%A", "Friday") is void             , "%A: parsefail");
	assert(v.weekday is int                              , "%A: void");
	assert(v.weekday as int == 4                         , "%A: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%b", "Jan") is void                , "%b: parsefail");
	assert(v.month is int                                , "%b: void");
	assert(v.month as int == 1                           , "%b: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%B", "January") is void   ,         "%B: parsefail");
	assert(v.month is int                                , "%B: void");
	assert(v.month as int == 1                           , "%B: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%d", "27") is void                 , "%d: parsefail");
	assert(v.day is int                                  , "%d: void");
	assert(v.day as int == 27                            , "%d: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%d", " 1") is void                 , "%d: parsefail");
	assert(v.day is int                                  , "%d: void");
	assert(v.day as int == 1                             , "%d: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%d", "x1") is parsefail            , "%d: not parsefail");

	let v = newvirtual();
	assert(parse(&v, "%e", " 7") is void                 , "%d: parsefail");
	assert(v.day is int                                  , "%d: void");
	assert(v.day as int == 7                             , "%d: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%F", "2012-10-01") is void         , "%d: parsefail");
	assert(v.year is int                                 , "%d: void");
	assert(v.year as int == 2012                         , "%d: incorrect");
	assert(v.month is int                                , "%d: void");
	assert(v.month as int == 10                          , "%d: incorrect");
	assert(v.day is int                                  , "%d: void");
	assert(v.day as int == 1                             , "%d: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%H", "22") is void                 , "%H: parsefail");
	assert(v.hour is int                                 , "%H: void");
	assert(v.hour as int == 22                           , "%H: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%I", "10") is void                 , "%I: parsefail");
	assert(v.hour12 is int                               , "%I: void");
	assert(v.hour12 as int == 10                         , "%I: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%j", "361") is void                , "%j: parsefail");
	assert(v.yearday is int                              , "%j: void");
	assert(v.yearday as int == 361                       , "%j: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%j", "  9") is void                , "%j: parsefail");
	assert(v.yearday is int                              , "%j: void");
	assert(v.yearday as int == 9                         , "%j: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%L", "Europe/Amsterdam") is void   , "%L: parsefail");
	assert(v.locname is str                              , "%L: void");
	assert(v.locname as str == "Europe/Amsterdam"        , "%L: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%m", "12") is void                 , "%m: parsefail");
	assert(v.month is int                                , "%m: void");
	assert(v.month as int == 12                          , "%m: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%M", "07") is void                 , "%M: parsefail");
	assert(v.minute is int                               , "%M: void");
	assert(v.minute as int == 7                          , "%M: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%N", "123456789") is void          , "%N: parsefail");
	assert(v.nanosecond is int                           , "%N: void");
	assert(v.nanosecond as int == 123456789              , "%N: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%N", "123") is void                , "%N: parsefail");
	assert(v.nanosecond is int                           , "%N: void");
	assert(v.nanosecond as int == 123000000              , "%N: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%p", "PM") is void                 , "%p: parsefail");
	assert(v.ampm is bool                                , "%p: void");
	assert(v.ampm as bool == true                        , "%p: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%S", "08") is void                 , "%S: parsefail");
	assert(v.second is int                               , "%S: void");
	assert(v.second as int == 8                          , "%S: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%T", "18:42:05") is void           , "%d: parsefail");
	assert(v.hour is int                                 , "%d: void");
	assert(v.hour as int == 18                           , "%d: incorrect");
	assert(v.minute is int                               , "%d: void");
	assert(v.minute as int == 42                         , "%d: incorrect");
	assert(v.second is int                               , "%d: void");
	assert(v.second as int == 5                          , "%d: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%u", "5") is void                  , "%u: parsefail");
	assert(v.weekday is int                              , "%u: void");
	assert(v.weekday as int == 4                         , "%u: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%U", "51") is void                 , "%U: parsefail");
	assert(v.week is int                                 , "%U: void");
	assert(v.week as int == 51                           , "%U: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%w", "5") is void                  , "%w: parsefail");
	assert(v.weekday is int                              , "%w: void");
	assert(v.weekday as int == 4                         , "%w: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%W", "51") is void                 , "%W: parsefail");
	assert(v.week is int                                 , "%W: void");
	assert(v.week as int == 51                           , "%W: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%Y", "2019") is void               , "%Y: parsefail");
	assert(v.year is int                                 , "%Y: void");
	assert(v.year as int == 2019                         , "%Y: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%z", "+0100") is void              , "%z: parsefail");
	assert(v.zoff is i64                                 , "%z: void");
	assert(v.zoff as i64 == 1 * time::HOUR               , "%z: incorrect");
	let v = newvirtual();
	assert(parse(&v, "%z", "+01:00") is void             , "%z: parsefail");
	assert(v.zoff is i64                                 , "%z: void");
	assert(v.zoff as i64 == 1 * time::HOUR               , "%z: incorrect");

	let v = newvirtual();
	assert(parse(&v, "%Z", "CET") is void                , "%Z: parsefail");
	assert(v.zabbr is str                                , "%Z: void");
	assert(v.zabbr as str == "CET"                       , "%Z: incorrect");

	let v = newvirtual();
	assert((
		parse(&v,
			"%Y-%m-%d %H:%M:%S.%N %z %Z %L",
			"2038-01-19 03:14:07.000000000 +0000 UTC UTC",
		)
		is void
	),
		"test 1: parsefail"
	);
	assert(v.year       is int         , "test 1: year void");
	assert(v.year       as int ==  2038, "test 1: year incorrect");
	assert(v.month      is int         , "test 1: month void");
	assert(v.month      as int ==     1, "test 1: month incorrect");
	assert(v.day        is int         , "test 1: day void");
	assert(v.day        as int ==    19, "test 1: day incorrect");
	assert(v.hour       is int         , "test 1: hour void");
	assert(v.hour       as int ==     3, "test 1: hour incorrect");
	assert(v.minute     is int         , "test 1: minute void");
	assert(v.minute     as int ==    14, "test 1: minute incorrect");
	assert(v.second     is int         , "test 1: second void");
	assert(v.second     as int ==     7, "test 1: second incorrect");
	assert(v.nanosecond is int         , "test 1: nanosecond void");
	assert(v.nanosecond as int ==     0, "test 1: nanosecond incorrect");
	assert(v.zoff       is i64         , "test 1: zoff void");
	assert(v.zoff       as i64 ==     0, "test 1: zoff incorrect");
	assert(v.zabbr      is str         , "test 1: zabbr void");
	assert(v.zabbr      as str == "UTC", "test 1: zabbr incorrect");
	assert(v.locname    is str         , "test 1: locname void");
	assert(v.locname    as str == "UTC", "test 1: locname incorrect");

};
