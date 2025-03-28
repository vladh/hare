// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

use errors;

// Copies data from one handle into another. If reading from the source file
// returns zero (underread), the copy is terminated and the amount of data
// copied is returned. Note that this function will never return if the source
// handle is infinite.
export fn copy(dest: handle, src: handle) (size | error) = {
	match (dest) {
	case let fd: file =>
		if (src is file) {
			match (fd_copy(fd, src as file)) {
			case let err: error =>
				if (!(err is errors::unsupported)) {
					return err;
				};
				// Use fallback
			case let z: size =>
				return z;
			};
		};
		return copy_fallback(dest, src);
	case let dest: *stream =>
		match (dest.copier) {
		case null =>
			return copy_fallback(dest, src);
		case let c: *copier =>
			match (c(dest, src)) {
			case errors::unsupported =>
				return copy_fallback(dest, src);
			case let err: error =>
				return err;
			case let s: size =>
				return s;
			};
		};
	};
};

fn copy_fallback(dest: handle, src: handle) (size | error) = {
	let w = 0z;
	let buf: [4096]u8 = [0...];

	for (let n => read(src, buf[..])?) {
		w += writeall(dest, buf[..n])?;
	};
	return w;
};
