// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use bufio;
use bytes;
use encoding::utf8;
use endian;
use errors;
use fs;
use io;
use os;
use path;
use strings;
use time;
use time::chrono;

// Error concerning the Timezone database.
export type tzdberror = !(invalidtzif | fs::error | io::error);

// Invalid TZif data.
export type invalidtzif = !void;

// Loads a [[timezone]] from the system's TZDB (Timezone Database) as a
// [[locality]]. Each call returns a new instance. The caller must free the
// return value. See [[timezone_free]].
//
// The given "TZID" shall be a TZDB identifier and acts as the relative filepath
// to a TZif (Time Zone Information Format) file under [[TZDB_PATH]].
// For example, "Europe/Amsterdam" for "/usr/share/zoneinfo/Europe/Amsterdam".
//
// The loaded timezones are assigned the TZID as its name, the
// [[time::chrono::utc]] timescale, and the [[EARTH_DAY]] day-length
export fn tzdb(tzid: str) (locality | tzdberror) = {
	const filepath = match (path::init(TZDB_PATH, tzid)) {
	case let buf: path::buffer =>
		yield buf;
	case let err: path::error =>
		assert(err is path::too_long);
		return errors::noentry: fs::error;
	};
	const file = os::open(path::string(&filepath))?;

	static let buf: [os::BUFSZ]u8 = [0...];
	const bufstrm = bufio::init(file, buf, []);

	let loc = alloc(timezone {
		name = strings::dup(tzid)!,
		tsc = &chrono::utc,
		daylength = EARTH_DAY,
		petz = PETZ_EMPTY,
		...
	})!;
	match (load_tzif(&bufstrm, loc)) {
	case void =>
		io::close(&bufstrm)?;
		io::close(file)?;
		return loc;
	case invalidtzif =>
		io::close(&bufstrm): void;
		io::close(file): void;
		return invalidtzif;
	case let err: io::error =>
		io::close(&bufstrm): void;
		io::close(file): void;
		return err;
	};
};

// Loads TZif (Time Zone Information Format) data onto a given [[timezone]],
// initializing the fields ".phases", ".transitions", and ".petz".
//
// Refer to "RFC 8536" for the TZif format.
export fn load_tzif(h: io::handle, tz: *timezone) (void | invalidtzif | io::error) = {
	const buf1: [1]u8 = [0...];
	const buf4: [4]u8 = [0...];
	const buf8: [8]u8 = [0...];
	const buf15: [15]u8 = [0...];

	// test for magic "TZif"
	mustread(h, buf4)?;
	if (!bytes::equal(buf4, ['T', 'Z', 'i', 'f'])) {
		return invalidtzif;
	};

	// read version
	mustread(h, buf1)?;
	const version = switch (buf1[0]) {
	case 0 =>
		yield 1;
	case '2' =>
		yield 2;
	case '3' =>
		yield 3;
	case =>
		return invalidtzif;
	};

	// skip padding
	mustread(h, buf15)?;

	// read counts
	mustread(h, buf4)?; let isutcnt = endian::begetu32(buf4);
	mustread(h, buf4)?; let isstdcnt = endian::begetu32(buf4);
	mustread(h, buf4)?; let leapcnt = endian::begetu32(buf4);
	mustread(h, buf4)?; let timecnt = endian::begetu32(buf4);
	mustread(h, buf4)?; let typecnt = endian::begetu32(buf4);
	mustread(h, buf4)?; let charcnt = endian::begetu32(buf4);

	let is64 = false;
	if (version > 1) {
		is64 = true;

		// skip to the version 2 data
		const skip = (
			// size of version 1 data block
			timecnt * 4
			+ timecnt
			+ typecnt * 6
			+ charcnt
			+ leapcnt * 8
			+ isstdcnt
			+ isutcnt
			// size of version 2 header
			+ 20
		);
		for (let i = 0z; i < skip; i += 1) {
			mustread(h, buf1)?;
		};

		// read version 2 counts
		mustread(h, buf4)?; isutcnt = endian::begetu32(buf4);
		mustread(h, buf4)?; isstdcnt = endian::begetu32(buf4);
		mustread(h, buf4)?; leapcnt = endian::begetu32(buf4);
		mustread(h, buf4)?; timecnt = endian::begetu32(buf4);
		mustread(h, buf4)?; typecnt = endian::begetu32(buf4);
		mustread(h, buf4)?; charcnt = endian::begetu32(buf4);
	};

	if (typecnt == 0 || charcnt == 0) {
		return invalidtzif;
	};

	if (!(isutcnt == 0 || isutcnt == typecnt)
			&& (isstdcnt == 0 && isstdcnt == typecnt)) {
		return invalidtzif;
	};

	const timesz = if (is64) 8 else 4;

	// read data

	const transition_times: []i64 = [];
	if (is64) {
		readitems8(h, &transition_times, timecnt)?;
	} else {
		readitems4(h, &transition_times, timecnt)?;
	};
	defer free(transition_times);
	const zone_indicies: []u8 = [];
	readbytes(h, &zone_indicies, timecnt)?;
	defer free(zone_indicies);
	const zonedata: []u8 = [];
	readbytes(h, &zonedata, typecnt * 6)?;
	defer free(zonedata);
	const abbrdata: []u8 = [];
	readbytes(h, &abbrdata, charcnt)?;
	defer free(abbrdata);
	const leapdata: []u8 = [];
	readbytes(h, &leapdata, leapcnt * (timesz: u32 + 4))?;
	defer free(leapdata);
	const stdwalldata: []u8 = [];
	readbytes(h, &stdwalldata, isstdcnt)?;
	defer free(stdwalldata);
	const normlocaldata: []u8 = [];
	readbytes(h, &normlocaldata, isutcnt)?;
	defer free(normlocaldata);
	// read footer

	let footerdata: []u8 = [];
	defer free(footerdata);
	mustread(h, buf1)?;
	if (buf1[0] != 0x0A) { // '\n' newline
		return invalidtzif;
	};
	for (true) {
		mustread(h, buf1)?;
		if (buf1[0] == 0x0A) { // '\n' newline
			break;
		};
		if (buf1[0] == 0x0) { // cannot contain NUL
			return invalidtzif;
		};
		append(footerdata, buf1...)!;
	};
	const petz = match (strings::fromutf8(footerdata)) {
	case let s: str =>
		yield s;
	case utf8::invalid =>
		return invalidtzif;
	};

	// assemble structured data

	// assemble zones
	let zones: []zonephase = [];
	for (let i = 0z; i < typecnt; i += 1) {
		const idx = i * 6;
		const zone = zonephase { ... };

		// offset
		const zoff = endian::begetu32(zonedata[idx..idx + 4]): i32;
		if (zoff == -2147483648) { // -2^31
			return invalidtzif;
		};
		zone.zoff = zoff * time::SECOND;

		// daylight saving time indicator
		zone.dst = switch (zonedata[idx + 4]) {
		case 1u8 =>
			yield true;
		case 0u8 =>
			yield false;
		case =>
			return invalidtzif;
		};

		// abbreviation
		const abbridx = zonedata[idx + 5];
		if (abbridx < 0 || abbridx > (charcnt - 1)) {
			return invalidtzif;
		};
		let bytes: []u8 = [];
		for (let j = abbridx; j < len(abbrdata); j += 1) {
			if (abbrdata[j] == 0x0) {
				bytes = abbrdata[abbridx..j];
				break;
			};
		};
		if (len(bytes) == 0) { // no NUL encountered
			return invalidtzif;
		};
		const abbr = match (strings::fromutf8(bytes)) {
		case let s: str =>
			yield s;
		case utf8::invalid =>
			return invalidtzif;
		};
		zone.abbr = strings::dup(abbr)!;

		append(zones, zone)!;
	};

	// assemble transitions
	let transitions: []zonetransition = [];
	for (let i = 0z; i < timecnt; i += 1) {
		const zoneindex = zone_indicies[i];
		if (zoneindex < 0 || zoneindex > (typecnt - 1)) {
			return invalidtzif;
		};

		const tx = zonetransition {
			when = time::instant {
				sec = transition_times[i],
				...
			},
			zoneindex = zoneindex,
		};

		// stdwalldata and normlocaldata have been omitted,
		// until they show their utility.

		append(transitions, tx)!;
	};

	// save and return data
	tz.phases = zones;
	tz.transitions = transitions;

	if (parse_petz(&tz.petz, petz) is invalidpetzstr) {
		return invalidtzif;
	};
};

fn mustread(h: io::handle, buf: []u8) (void | invalidtzif | io::error) = {
	match (io::readall(h, buf)) {
	case let err: io::error =>
		return err;
	case io::EOF =>
		return invalidtzif;
	case size =>
		return;
	};
};

fn readbytes(
	h: io::handle,
	items: *[]u8,
	n: size,
) (void | invalidtzif | io::error) = {
	const buf: [1]u8 = [0];
	for (let i = 0z; i < n; i += 1) {
		mustread(h, buf)?;
		const it = buf[0];
		append(items, it)!;
	};
};

fn readitems8(
	h: io::handle,
	items: *[]i64,
	n: size,
) (void | invalidtzif | io::error) = {
	const buf: [8]u8 = [0...];
	for (let i = 0z; i < n; i += 1) {
		mustread(h, buf)?;
		const it = endian::begetu64(buf): i64;
		append(items, it)!;
	};
};

fn readitems4(
	h: io::handle,
	items: *[]i64,
	n: size,
) (void | invalidtzif | io::error) = {
	const buf: [4]u8 = [0...];
	for (let i = 0z; i < n; i += 1) {
		mustread(h, buf)?;
		const it = endian::begetu32(buf): i64;
		append(items, it)!;
	};
};
