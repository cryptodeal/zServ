const std = @import("std");

pub inline fn @"align"(length: usize) usize {
    const size_t_size: usize = @sizeOf(usize);
    const rem_bits: usize = size_t_size - 1;
    return (length + rem_bits) & (~rem_bits);
}

pub inline fn firsthdr(mhdr: *std.c.msghdr) ?*std.c.cmsghdr {
    return if (mhdr.controllen >= @sizeOf(std.c.cmsghdr)) @ptrCast(@alignCast(mhdr.control)) else null;
}

pub inline fn data(mhdr: *std.c.cmsghdr) [*]u8 {
    return @as([*]u8, @ptrCast(@alignCast(mhdr))) + @"align"(@sizeOf(std.c.cmsghdr));
}

inline fn padding(len: usize) usize {
    return ((@sizeOf(usize) - ((len) & (@sizeOf(usize) - 1))) & (@sizeOf(usize) - 1));
}

pub inline fn nexthdr(mhdr: *std.c.msghdr, cmsghdr: *std.c.cmsghdr) ?*std.c.cmsghdr {
    const msg_control_ptr: [*]u8 = @ptrCast(@alignCast(mhdr.control));
    const cmsg_ptr: [*]u8 = @ptrCast(@alignCast(cmsghdr));
    const size_needed: usize = @sizeOf(std.c.cmsghdr) + padding(cmsghdr.len);

    if (cmsghdr.len < @sizeOf(std.c.cmsghdr))
        return null;

    if ((@intFromPtr(msg_control_ptr) + mhdr.controllen - @intFromPtr(cmsg_ptr) < size_needed) or (@intFromPtr(msg_control_ptr) + mhdr.controllen - @intFromPtr(cmsg_ptr) - size_needed < cmsghdr.len))
        return null;

    return @ptrCast(@alignCast(@as([*]u8, @ptrCast(@alignCast(cmsghdr))) + @"align"(cmsghdr.len)));
}
