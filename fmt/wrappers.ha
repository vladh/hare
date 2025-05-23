// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use io;
use memio;
use os;
use strings;

// Formats text for printing and writes it to [[os::stdout]].
export fn printf(fmt: str, args: field...) (size | io::error) =
	fprintf(os::stdout, fmt, args...);

// Formats text for printing and writes it to [[os::stdout]], followed by a line
// feed.
export fn printfln(fmt: str, args: field...) (size | io::error) =
	fprintfln(os::stdout, fmt, args...);

// Formats text for printing and writes it to [[os::stderr]].
export fn errorf(fmt: str, args: field...) (size | io::error) =
	fprintf(os::stderr, fmt, args...);

// Formats text for printing and writes it to [[os::stderr]], followed by a line
// feed.
export fn errorfln(fmt: str, args: field...) (size | io::error) =
	fprintfln(os::stderr, fmt, args...);

// Formats text for printing and writes it into a heap-allocated string. The
// caller must free the return value.
export fn asprintf(fmt: str, args: field...) (str | nomem) = {
	let buf = memio::dynamic();
	match (fprintf(&buf, fmt, args...)) {
	case size => void;
	case let e: io::error =>
		return e as nomem;
	};
	return strings::fromutf8_unsafe(memio::buffer(&buf));
};

// Formats text for printing and writes it into a caller supplied buffer. The
// returned string is borrowed from this buffer. Returns nomem, if the buffer
// isn't large enough to hold the formatted text.
export fn bsprintf(buf: []u8, fmt: str, args: field...) (str | nomem) = {
	let sink = memio::fixed(buf);
	match (fprintf(&sink, fmt, args...)) {
	case let l: size =>
		return strings::fromutf8_unsafe(buf[..l]);
	case let e: io::error =>
		return e as nomem;
	};
};

// Formats text for printing and writes it to [[os::stderr]], followed by a line
// feed, then exits the program with an error status.
export fn fatalf(fmt: str, args: field...) never = {
	fprintfln(os::stderr, fmt, args...): void;
	os::exit(255);
};

// Formats values for printing using the default format modifiers and writes
// them to [[os::stderr]] separated by spaces and followed by a line feed, then
// exits the program with an error status.
export fn fatal(args: formattable...) never = {
	fprintln(os::stderr, args...): void;
	os::exit(255);
};

// Formats text for printing and writes it to an [[io::handle]], followed by a
// line feed.
export fn fprintfln(
	h: io::handle,
	fmt: str,
	args: field...
) (size | io::error) = fprintf(h, fmt, args...)? + io::write(h, ['\n'])?;

// Formats values for printing using the default format modifiers and writes
// them to [[os::stdout]] separated by spaces.
export fn print(args: formattable...) (size | io::error) =
	fprint(os::stdout, args...);

// Formats values for printing using the default format modifiers and writes
// them to [[os::stdout]] separated by spaces and followed by a line feed.
export fn println(args: formattable...) (size | io::error) =
	fprintln(os::stdout, args...);

// Formats values for printing using the default format modifiers and writes
// them to [[os::stderr]] separated by spaces.
export fn error(args: formattable...) (size | io::error) =
	fprint(os::stderr, args...);

// Formats values for printing using the default format modifiers and writes
// them to [[os::stderr]] separated by spaces and followed by a line feed.
export fn errorln(args: formattable...) (size | io::error) =
	fprintln(os::stderr, args...);

// Formats values for printing using the default format modifiers and writes
// them into a heap-allocated string separated by spaces. The caller must free
// the return value.
export fn asprint(args: formattable...) (str | nomem) = {
	let buf = memio::dynamic();
	match (fprint(&buf, args...)) {
	case size => void;
	case let e: io::error =>
		return e as nomem;
	};
	return strings::fromutf8_unsafe(memio::buffer(&buf));
};

// Formats values for printing using the default format modifiers and writes
// them into a caller supplied buffer separated by spaces. The returned string
// is borrowed from this buffer. Returns nomem, if the buffer isn't large enough
// to hold the formatted text.
export fn bsprint(buf: []u8, args: formattable...) (str | nomem) = {
	let sink = memio::fixed(buf);
	match (fprint(&sink, args...)) {
	case let l: size =>
		return strings::fromutf8_unsafe(buf[..l]);
	case let e: io::error =>
		return e as nomem;
	};
};

// Formats values for printing using the default format modifiers and writes
// them to an [[io::handle]] separated by spaces and followed by a line feed.
export fn fprintln(h: io::handle, args: formattable...) (size | io::error) =
	fprint(h, args...)? + io::write(h, ['\n'])?;
