const constants = @import("constants.zig");
const std = @import("std");

const Poll = @import("poll.zig");

pub fn kqueueChange(kqfd: std.posix.fd_t, fd: std.posix.fd_t, old_events: u32, new_events: u32, user_data: ?*Poll) i32 {
    var change_list: [2]std.posix.Kevent = undefined;
    var change_size: u4 = 0;
    if ((new_events & constants.socket_readable) != (old_events & constants.socket_readable)) {
        change_list[change_size] = .{
            .ident = @intCast(fd),
            .filter = std.c.EVFILT.READ,
            .flags = if ((new_events & constants.socket_readable) != 0) std.c.EV.ADD else std.c.EV.DELETE,
            .fflags = 0,
            .data = 0,
            .udata = @intFromPtr(user_data),
        };
        change_size += 1;
    }
    if ((new_events & constants.socket_writable) != (old_events & constants.socket_writable)) {
        change_list[change_size] = .{
            .ident = @intCast(fd),
            .filter = std.c.EVFILT.WRITE,
            .flags = if ((new_events & constants.socket_writable) != 0) std.c.EV.ADD else std.c.EV.DELETE,
            .fflags = 0,
            .data = 0,
            .udata = @intFromPtr(user_data),
        };
        change_size += 1;
    }
    return @intCast(std.c.kevent(kqfd, &change_list, @intCast(change_size), &.{}, 0, null));
}
