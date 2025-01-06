// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

export type slice = struct {
	data: nullable *opaque,
	length: size,
	capacity: size,
};

export fn ensure(s: *slice, membsz: size) bool = {
	let cap = s.capacity;
	if (cap >= s.length) {
		return true;
	};
	for (cap < s.length) {
		assert(cap >= s.capacity, "slice out of memory (overflow)");
		if (cap == 0) {
			cap = s.length;
		} else {
			cap *= 2;
		};
	};
	s.capacity = cap;
	let data = realloc(s.data, s.capacity * membsz);
	if (data == null) {
		if (s.capacity * membsz == 0) {
			s.data = null;
			return true;
		} else {
			return false;
		};
	};
	s.data = data;
	return true;
};

export fn unensure(s: *slice, membsz: size) void = {
	let cap = s.capacity;
	for (cap > s.length) {
		cap /= 2;
	};
	cap *= 2;
	s.capacity = cap;
	let data = realloc(s.data, s.capacity * membsz);

	if (data != null || s.capacity * membsz == 0) {
		s.data = data;
	};
};
