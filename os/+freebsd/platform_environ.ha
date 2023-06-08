// License: MPL-2.0
// (c) 2021 Drew DeVault <sir@cmpwn.com>
// (c) 2021 Ember Sawady <ecs@d2evs.net>
use errors;
use rt;
use strings;
use types::c;

// The command line arguments provided to the program. By convention, the first
// member is usually the name of the program.
export let args: []str = [];

// Statically allocate arg strings if there are few enough arguments, saves a
// syscall if we don't need it.
let args_static: [32]str = [""...];

@init fn args() void = {
	if (rt::argc < len(args_static)) {
		args = args_static[..rt::argc];
		for (let i = 0z; i < rt::argc; i += 1) {
			args[i] = c::tostr(rt::argv[i]: *const c::char)!;
		};
	} else {
		args = alloc([], rt::argc);
		for (let i = 0z; i < rt::argc; i += 1) {
			append(args, c::tostr(rt::argv[i]: *const c::char)!);
		};
	};

};

@fini fn args() void = {
	if (rt::argc >= len(args_static)) {
		free(args);
	};
};

// Returns a slice of the environment strings in the form KEY=VALUE.
export fn getenvs() []str = {
	if (len(envp) != 0) {
		return envp;
	};
	for (let i = 0z; rt::envp[i] != null; i += 1) {
		let s = c::tostr(rt::envp[i]: *const c::char)!;
		append(envp, strings::dup(s));
	};
	return envp;
};

// Returns the host kernel name
export fn sysname() const str = {
	static let buf: [512]u8 = [0...];
	let sz: size = len(buf);
	rt::sysctlbyname("kern.ostype", &buf, &sz, null, 0)!;
	return strings::fromutf8(buf[..(sz - 1)])!;
};

// Returns the host system hostname
export fn hostname() const str = {
	static let buf: [512]u8 = [0...];
	let sz: size = len(buf);
	rt::sysctlbyname("kern.hostname", &buf, &sz, null, 0)!;
	return strings::fromutf8(buf[..(sz - 1)])!;
};

// Returns the host kernel version
export fn release() const str = {
	static let buf: [512]u8 = [0...];
	let sz: size = len(buf);
	rt::sysctlbyname("kern.osrelease", &buf, &sz, null, 0)!;
	return strings::fromutf8(buf[..(sz - 1)])!;
};

// Returns the host operating system version
export fn version() const str = {
	static let buf: [512]u8 = [0...];
	let sz: size = len(buf);
	rt::sysctlbyname("kern.version", &buf, &sz, null, 0)!;
	return strings::fromutf8(buf[..(sz - 1)])!;
};

// Returns the host CPU architecture
export fn machine() const str = {
	static let buf: [512]u8 = [0...];
	let sz: size = len(buf);
	rt::sysctlbyname("hw.machine", &buf, &sz, null, 0)!;
	const mach = strings::fromutf8(buf[..(sz - 1)])!;
	// Translate to Hare names
	switch (mach) {
	case "amd64" =>
		return "x86_64";
	case =>
		return mach;
	};
};

// Returns the number of usable CPUs.
export fn cpucount() (int | errors::error) = {
	let count = 0;
	let length = size(int);
	match (rt::sysctlbyname("hw.ncpu", &count, &length, null, 0)) {
	case void => void;
	case let err: rt::errno =>
		return errors::errno(err);
	};
	return count;
};