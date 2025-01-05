// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use rt;
use unix::signal;

let heap = rt::EMPTY_HEAP;

// Reconfigure the process to handle a fatal condition, such as a segfault, as
// safely as possible. Resets all signals (in case of faults in debug::) and
// configures the runtime to use the debug heap (in case of heap overflow or
// similar faults in the user program).
fn begin_fatal() void = {
	signal::resetall();
	rt::setheap(&heap);
	rt::onabort(default_abort);
};

// Enables the debug:: heap.
fn begin_altheap() *rt::memory_heap = {
	return rt::setheap(&heap);
};

// Restores the original heap corresponding to [[begin_altheap]].
fn end_altheap(restore: *rt::memory_heap) void = {
	rt::setheap(restore);
};
