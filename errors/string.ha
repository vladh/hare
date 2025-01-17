// SPDX-License-Identifier: MPL-2.0
// (c) Hare authors <https://harelang.org>

// Converts an [[error]] into a human-friendly string representation.
//
// Note that this strerror implementation lacks any context-specific information
// about the error types supported. For example, [[exists]] is stringified as "An
// attempt was made to create a resource which already exists", but if source of
// the error is, say, creating a file, it would likely be more appropriate to
// use the term "file" rather than "resource". For this reason, it is preferred
// that modules which return an error type from this module provide their own
// strerror function which provides more context-appropriate error messages for
// each of those types.
export fn strerror(err: (error | nomem)) const str = {
	match (err) {
	case busy =>
		return "The requested resource is not available";
	case exists =>
		return "An attempt was made to create a resource which already exists";
	case invalid =>
		return "A function was called with an invalid combination of arguments";
	case noaccess =>
		return "The user does not have permission to use this resource";
	case noentry =>
		return "An entry was requested which does not exist";
	case overflow =>
		return "The requested operation caused a numeric overflow condition";
	case unsupported =>
		return "The requested operation is not supported";
	case timeout =>
		return "The requested operation timed out";
	case cancelled =>
		return "The requested operation was cancelled";
	case refused =>
		return "A connection attempt was refused";
	case interrupted =>
		return "Operation interrupted";
	case again =>
		return "Try again";
	case netunreachable =>
		return "Network unreachable";
	case let op: opaque_ =>
		return op.strerror(&op.data);
	case nomem =>
		return "Memory allocation failure";
	};
};
