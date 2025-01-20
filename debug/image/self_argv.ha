// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use errors;
use fs;
use io;
use os;
use os::exec;

// Fallback implementation of self() that performs path resolution on argv[0]
fn self_argv() (image | io::error | fs::error) = {
	const path = exec::lookup(os::args[0])?;
	const file = os::open(path)?;
	match (open(file)) {
	case let img: image =>
		return img;
	case let err: io::error =>
		return err;
	case errors::invalid =>
		abort("Running program image is not a valid ELF file");
	};
};
