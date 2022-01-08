// TODO:
// - Set name field
// - Figure out the portability mess that is this interface
use rt;
use slice;
use fmt;

export type msghdr = struct {
	native: rt::msghdr,
	vectors: []rt::iovec,
	control: []u8,
};

// Creates a new message header for advanced socket usage, with configurable I/O
// vectors, control messages, and other details, for use with [[sendmsg]] and
// [[recvmsg]].
//
// The user must call [[finish]] when they are done using this message for
// sending or receiving. The same message may be used for multiple operations
// before calling [[finish]]. [[reset]] may be used to "reset" a [[msghdr]] to
// an empty list of I/O vectors and control messages without freeing the
// underlying memory, which may be useful if future messages are expected to
// have similar characteristics.
export fn newmsg() msghdr = msghdr { ... };

// Frees resources associated with a [[msghdr]].
export fn finish(msg: *msghdr) void = {
	free(msg.control);
	free(msg.vectors);
};

// Resets a message header, clearing out any I/O vectors or control messages,
// without freeing the underlying memory. This allows the user to configure new
// vectors or control messages without a re-allocation, which improves
// performance if the new configuration fits into the same amount of memory.
export fn reset(msg: *msghdr) void = {
	slice::trunc(&msg.control: *[]void);
	slice::trunc(&msg.vectors: *[]void);
};

// Adds an I/O vector to the message.
export fn addvector(msg: *msghdr, vec: []u8) void = {
	append(msg.vectors, rt::iovec {
		iov_base = vec: *[*]u8,
		iov_len = len(vec),
	});
};

// Sets flags for this message.
export fn setflags(msg: *msghdr, flags: int) void = {
	msg.native.msg_flags = flags;
};

// Adds a control message of the desired length to a [[msghdr]], returning a
// buffer in which the ancillary data may be written in a domain-specific
// format.
//
// This is a low-level interface, and is not generally used by users. More
// often, users will call functions like [[net::unix::addfiles]] or
// [[net::unix::prepfiles]], which provide a high-level interface to this
// function for domain-specific use-cases.
export fn addcontrol(
	msg: *msghdr,
	length: size,
	level: int,
	ctype: int,
) []u8 = {
	const prev = len(msg.control);
	const space = cmsg_space(length);
	append(msg.control, [0...], space);
	let newbuf = msg.control[prev..prev + space]: *[*]rt::cmsghdr;
	newbuf[0].cmsg_len = cmsg_len(length): uint;
	newbuf[0].cmsg_level = level;
	newbuf[0].cmsg_type = ctype;
	let user = &newbuf[1]: *[*]u8;
	return user[..length];
};

// Retrieves a control header from a message, returning a slice of
// domain-specific data.
//
// This is a low-level interface, and is not generally used by users. More
// often, users will call functions like [[net::unix::addfiles]] or
// [[net::unix::prepfiles]], which provide a high-level interface to this
// function for domain-specific use-cases.
export fn getcontrol(
	msg: *msghdr,
	length: size,
	level: int,
	ctype: int,
) ([]u8 | void) = {
	let native = &msg.native;
	let cbuf = native.msg_control: *[*]u8;
	for (let i = 0z; i < native.msg_controllen) {
		let next = &cbuf[i]: *rt::cmsg;
		if (next.hdr.cmsg_len >= length
				&& next.hdr.cmsg_level == level
				&& next.hdr.cmsg_type == ctype) {
			return next.cmsg_data[..length];
		};
		i += next.hdr.cmsg_len;
	};
};

fn cmsg_align(z: size) size = (z + size(size) - 1) & ~(size(size) - 1);
fn cmsg_len(z: size) size = cmsg_align(size(rt::cmsghdr) + z);
fn cmsg_space(z: size) size = cmsg_align(z) + cmsg_align(size(rt::cmsghdr));