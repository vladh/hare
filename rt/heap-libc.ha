// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// A group of blocks that were allocated together.
export type chunk = union {
	padding: size, // TODO: track number of active allocations here
	data: [*]u8,
};

// Metadata for a block.
export type meta = struct {
	union {
		sz: size,
		next: uintptr,
	},
	user: [*]u8,
};

export type memory_heap = struct {
	// Number of allocations currently in flight.
	cur_allocs: size,
	// Freelists for blocks up to 2048 bytes.
	bins: [9]nullable *meta,
	// The chunk to allocate from if there are no blocks available in the
	// right freelist.
	cur_chunk: (*chunk, size),
};

// An empty memory heap, used to initialize a [[memory_heap]] for use with
// [[setheap]].
export def EMPTY_HEAP = memory_heap {
	cur_allocs = 0,
	bins = [null...],
	cur_chunk = (null: *chunk, CHUNKSZ),
};

let static_heap = EMPTY_HEAP;
let heap = &static_heap;

// Switches the internal runtime allocator to a new memory heap. The caller
// should provision a [[memory_heap]] initialized to [[EMPTY_HEAP]] somehow
// (statically, or in a second memory_heap, or even on the stack if you're brave
// enough) and pass it to this function to enable it. Returns a pointer to the
// heap which was previously in use, should you wish to restore it later.
//
// The caller is responsible for ensuring that any use of free() or delete()
// makes use of an object which was allocated (via alloc(), insert(), or
// append()) from the same heap.
//
// This function is designed for debugging use, and exists in particular to
// satisfy the needs of [[debug::]].
export fn setheap(new_heap: *memory_heap) *memory_heap = {
	const old = heap;
	heap = new_heap;
	return old;
};
