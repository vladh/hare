// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use hash;
use hash::fnv;
use rt;

def TRACE_BUCKETS = 65535;

let traces: [TRACE_BUCKETS][]trace = [[]...];

export type trace = struct {
	id: u64,
	frames: *stackframe,
};

// Retrives a stack trace by its ID.
export fn trace_by_id(id: u64) (stackframe | void) = {
	let bucket = &traces[id % TRACE_BUCKETS];
	for (let trace &.. bucket) {
		if (trace.id == id) {
			return *trace.frames;
		};
	};
};

// Stores a stack trace and returns its ID. Stored stack traces are hashed and
// de-duplicated in a global stack list.
export fn trace_store(frame: stackframe) u64 = {
	static let pc: []uintptr = [];
	pc = pc[..0];

	const hash = fnv::fnv64a();
	for (true) {
		hash::write(&hash, &frame_pc(frame): *[size(uintptr)]u8);
		append(pc, frame_pc(frame));

		match (next(frame)) {
		case let next: stackframe =>
			frame = next;
		case done => break;
		};
	};

	const id = fnv::sum64(&hash);
	let bucket = &traces[id % TRACE_BUCKETS];
	for (let trace &.. bucket) {
		if (trace.id == id) {
			return id;
		};
	};

	let frames: []stackframe = alloc([stackframe { ... }...], len(pc) + 1);
	for (let i = 0z; i < len(pc); i += 1) {
		frames[i] = mkframe(&frames[i + 1], pc[i]);
	};

	append(bucket, trace {
		id = id,
		frames = &frames[0],
	});

	return id;
};
