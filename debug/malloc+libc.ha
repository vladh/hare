// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use unix::signal;

fn begin_fatal() void = {
	signal::resetall();
};

fn begin_altheap() nullable *opaque = {
	return null; // no-op on +libc
};

fn end_altheap(restore: nullable *opaque) void = {
	void; // no-op on +libc
};
