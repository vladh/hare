// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use io;
use memio;
use strings;

// Invalid shell syntax.
export type syntaxerr = !void;

// Converts an error into a human-friendly string.
export fn strerror(err: syntaxerr) str = "Invalid shell syntax";

// Splits a string of arguments according to shell quoting. The result must be
// freed using [[strings::freeall]] when the caller is done processing it.
export fn split(in: const str) ([]str | syntaxerr | nomem) = {
	let iter = strings::iter(in);

	let s = memio::dynamic();
	defer io::close(&s)!;

	let first = true;
	let dirty = false;

	let slice: []str = [];
	let ok = false;
	defer if (!ok) {
		strings::freeall(slice);
	};

	for (let r => strings::next(&iter)) {
		dirty = true;
		switch (r) {
		case ' ', '\t', '\n' =>
			for (let r => strings::next(&iter)) {
				if (r != ' ' && r != '\t' && r != '\n') {
					strings::prev(&iter); // Unget
					break;
				};
			};
			if (!first) {
				const item = memio::string(&s)!;
				const item = strings::dup(item)?;
				match (append(slice, item)) {
				case void => void;
				case nomem =>
					free(item);
					return nomem;
				};

				memio::reset(&s);
			};
			dirty = false;
		case '\\' =>
			scan_backslash(&s, &iter)?;
		case '"' =>
			scan_double(&s, &iter)?;
		case '\'' =>
			scan_single(&s, &iter)?;
		case =>
			if (memio::appendrune(&s, r) is nomem) {
				return nomem;
			};
		};

		if (first) {
			first = false;
		};
	};

	if (dirty) {
		const item = memio::string(&s)!;
		const item = strings::dup(item)?;
		match (append(slice, item)) {
		case void => void;
		case nomem =>
			free(item);
			return nomem;
		};
	};

	ok = true;
	return slice;
};

fn scan_backslash(
	out: io::handle,
	in: *strings::iterator,
) (void | syntaxerr | nomem) = {
	const r = match (strings::next(in)) {
	case let r: rune =>
		yield r;
	case done =>
		return syntaxerr;
	};

	// The <backslash> and <newline> shall be removed before splitting the
	// input into tokens. Since the escaped <newline> is removed entirely
	// from the input and is not replaced by any white space, it cannot
	// serve as a token separator
	if (r == '\n') {
		return;
	};

	if (memio::appendrune(out, r) is nomem) {
		return nomem;
	};
};

fn scan_double(
	out: io::handle,
	in: *strings::iterator,
) (void | syntaxerr | nomem) = {
	for (true) {
		const r = match (strings::next(in)) {
		case let r: rune =>
			yield r;
		case done =>
			return syntaxerr;
		};

		switch (r) {
		case '"' =>
			break;
		case '\\' =>
			scan_backslash(out, in)?;
		case =>
			if (memio::appendrune(out, r) is nomem) {
				return nomem;
			};
		};
	};
};

fn scan_single(
	out: io::handle,
	in: *strings::iterator,
) (void | syntaxerr | nomem) = {
	for (true) {
		const r = match (strings::next(in)) {
		case let r: rune =>
			yield r;
		case done =>
			return syntaxerr;
		};

		if (r == '\'') {
			break;
		};

		if (memio::appendrune(out, r) is nomem) {
			return nomem;
		};
	};
};
