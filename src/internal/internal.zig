const bsd = @import("../bsd.zig");
const build_opts = @import("build_opts");
const std = @import("std");
const Extension = @import("../extension.zig");
const Poll = @import("../eventing/impl.zig").Poll;
const socket_readable = @import("../eventing/impl.zig").socket_readable;
const socket_writable = @import("../eventing/impl.zig").socket_writable;

const Socket = @import("../socket.zig");
const SocketContext = @import("../socket_context.zig");

pub const Timer = switch (build_opts.event_backend) {
    .io_uring => @import("../io_uring/timer.zig"),
    else => anyopaque,
};

pub const PollType = enum(u8) {
    socket = 0,
    socket_shutdown = 1,
    semi_socket = 2,
    callback = 3,
    polling_out = 4,
    polling_in = 8,
    _,
};

pub const LowPriorityQueueState = enum(u8) {
    not_queued,
    in_queue,
    prev_queued,
};

pub fn isLowPriority(_: *Socket) LowPriorityQueueState {
    return .not_queued;
}

pub fn adoptAcceptedSocket(allocator: std.mem.Allocator, socket: *Socket, context: *SocketContext, accepted_fd: std.posix.fd_t, addr_ip: []u8, extension: Extension) !void {
    socket.* = .{
        .context = context,
        .ext = try extension.dupe(allocator),
    };
    try socket.p.create(allocator, context.loop, false, null);
    socket.p.init(accepted_fd, .socket);
    socket.p.start(context.loop, socket_readable);
    bsd.socketNoDelay(accepted_fd, true);
    context.linkSocket(socket);
    _ = try context.on_open(allocator, socket, false, addr_ip);
}

pub fn connect(allocator: std.mem.Allocator, context: *SocketContext, socket: *Socket, host: [:0]const u8, port: u32, source_host: ?[:0]const u8, options: u32, comptime ExtensionT: ?type) !void {
    const connect_socket_fd = try bsd.createConnectSocket(host, port, source_host, options);
    socket.* = .{
        .context = context,
        .ext = try Extension.init(allocator, ExtensionT),
    };
    try socket.p.create(allocator, context.loop, false, null);
    socket.p.init(connect_socket_fd, .semi_socket);
    socket.p.start(context.loop, socket_writable);
    context.linkSocket(socket);
}

pub fn connectUnix(allocator: std.mem.Allocator, context: *SocketContext, socket: *Socket, server_path: [:0]const u8, options: u32, comptime ExtensionT: ?type) !void {
    const connect_socket_fd = try bsd.createConnectSocketUnix(server_path, options);
    socket.* = .{
        .context = context,
        .ext = try Extension.init(allocator, ExtensionT),
    };
    try socket.p.create(allocator, context.loop, false, null);
    socket.p.init(connect_socket_fd, .semi_socket);
    socket.p.start(context.loop, socket_writable);
    context.linkSocket(socket);
}
