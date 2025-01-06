// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// Signature for abort handler function.
export type abort_handler = fn(
	path: *str,
	line: u64,
	col: u64,
	msg: str,
) never;

let handle_abort: *abort_handler = &platform_abort;

// Sets a new global runtime abort handler, returning the previous handler.
export fn onabort(handler: *abort_handler) *abort_handler = {
	const prev = handle_abort;
	handle_abort = handler;
	return prev;
};

export @symbol("rt.abort") fn _abort(
	path: *str,
	line: u64,
	col: u64,
	msg: str,
) never = {
	handle_abort(path, line, col, msg);
};

// See harec:include/gen.h
const reasons: [_]str = [
	"slice or array access out of bounds",			// 0
	"type assertion failed",				// 1
	"execution reached unreachable code (compiler bug)",	// 2
	"slice allocation capacity smaller than initializer",	// 3
	"assertion failed",					// 4
	"error occurred",					// 5
];

export fn abort_fixed(path: *str, line: u64, col: u64, i: u64) void = {
	handle_abort(path, line, col, reasons[i]);
};
