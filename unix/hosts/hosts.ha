// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use bufio;
use errors;
use encoding::utf8;
use fs;
use io;
use net::ip;
use os;
use strings;

// Represents a host line in /etc/hosts, guaranteed to have at least a single
// name. The first name is the canonical one.
export type host = struct {
	addr: ip::addr,
	names: []str,
};

export type reader = struct {
	scan: bufio::scanner,
	names: []str,
};

// Read from an /etc/hosts-formatted file. Call [[next]] to enumerate entries
// and [[finish]] to free state associated with the [[reader]].
export fn read(in: io::handle) reader = {
	return reader {
		scan = bufio::newscanner(in),
		names = [],
	};
};

// Frees resources associated with a [[reader]].
export fn finish(rd: *reader) void = {
	bufio::finish(&rd.scan);
	free(rd.names);
};

// Returns the next host line as a [[host]] type. The host value is borrowed
// from the [[reader]]; see [[host_dup]] to extend its lifetime.
export fn next(rd: *reader) (host | done | nomem | error) = {
	for (const line => bufio::scan_line(&rd.scan)?) {
		if (len(line) == 0 || strings::hasprefix(line, "#")) {
			continue;
		};

		const tok = strings::tokenize(line, " \t");
		const addr = strings::next_token(&tok) as str;
		const addr = ip::parse(addr)?;

		rd.names = rd.names[..0];

		for (const tok => strings::next_token(&tok)) {
			if (len(tok) == 0) {
				continue;
			};
			// XXX: Rather than return nomem here we could consider
			// handling it by treating
			//
			// 127.0.0.1 long list of hosts...
			//
			// As the following:
			//
			// 127.0.0.1 long
			// 127.0.0.1 list
			// 127.0.0.1 of
			// 127.0.0.1 hosts
			//
			// By storing the tokenizer state in [[reader]] and
			// handling long lines over the course of several calls
			// to [[next]]. But that would require substantial
			// refactoring that the author of this comment lacks the
			// patience for right now.
			append(rd.names, tok)?;
		};

		if (len(rd.names) == 0) {
			return invalid;
		};

		return host {
			addr = addr,
			names = rd.names,
		};
	};

	return done;
};

// Looks up a slice of addresses from /etc/hosts. The caller must free the
// return value.
export fn lookup(name: const str) ([]ip::addr | nomem | error) = {
	const file = os::open(PATH)?;
	defer io::close(file)!;

	const rd = read(file);
	defer finish(&rd);
	return _lookup(&rd, name);
};

fn _lookup(rd: *reader, name: const str) ([]ip::addr | nomem | error) = {
	let addrs: []ip::addr = [];
	let ok = false;
	defer if (!ok) free(addrs);

	for (const host => next(rd)?) {
		for (const cand .. host.names) {
			if (cand == name) {
				append(addrs, host.addr)?;
			};
		};
	};
	ok = true;

	if (len(addrs) != 0) {
		return addrs;
	};

	return [];
};

// Duplicates a [[host]] value.
export fn host_dup(src: *host) (host | nomem) = {
	return host {
		addr = src.addr,
		names = strings::dupall(src.names)?,
	};
};

// Frees resources associated with a [[host]].
export fn host_finish(host: *host) void = {
	strings::freeall(host.names);
};
