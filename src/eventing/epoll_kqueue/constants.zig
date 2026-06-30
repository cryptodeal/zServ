const build_opts = @import("build_opts");
const std = @import("std");

pub const socket_readable = if (build_opts.event_backend == .epoll) std.os.linux.EPOLL.IN else 1;
pub const socket_writable = if (build_opts.event_backend == .epoll) std.os.linux.EPOLL.OUT else 2;
