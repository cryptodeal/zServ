const builtin = @import("builtin");
const std = @import("std");

pub fn setsockopt(fd: std.posix.fd_t, level: i32, optname: u32, optval: []const u8) std.posix.SetSockOptError!void {
    switch (std.posix.errno(std.c.setsockopt(fd, level, optname, optval.ptr, @intCast(optval.len)))) {
        .SUCCESS => {},
        .BADF => unreachable, // always a race condition
        .NOTSOCK => unreachable, // always a race condition
        .INVAL => unreachable,
        .FAULT => unreachable,
        .DOM => return error.TimeoutTooBig,
        .ISCONN => return error.AlreadyConnected,
        .NOPROTOOPT => return error.InvalidProtocolOption,
        .NOMEM => return error.SystemResources,
        .NOBUFS => return error.SystemResources,
        .PERM => return error.PermissionDenied,
        .NODEV => return error.NoDevice,
        .OPNOTSUPP => return error.OperationUnsupported,
        else => |err| return std.posix.unexpectedErrno(err),
    }
}
