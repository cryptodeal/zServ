const bsd = @import("bsd/root.zig");
const std = @import("std");
const Extension = @import("extension.zig");
const Loop = @import("eventing/impl.zig").Loop;
const Poll = @import("eventing/impl.zig").Poll;
const SocketContext = @import("socket_context.zig");
const Socket = @import("socket.zig");

const Self = @This();

s: Socket,
ext: Extension = .{},

pub fn init(allocator: std.mem.Allocator, context: *SocketContext, comptime MaybeT: ?type) !*Self {
    const self = try allocator.create(Self);
    self.* = .{
        .s = .{
            .context = context,
            .ls_field_ptr = true,
            .ext = try Extension.init(allocator, MaybeT),
        },
    };
    return self;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator, loop: *Loop) void {
    self.s.p.deinit(allocator, loop);
    self.s.ext.deinit(allocator);
    self.ext.deinit(allocator);
    allocator.destroy(self);
}

pub fn close(self: *Self, _: bool) void {
    if (!self.s.isClosed(false)) {
        self.s.context.unlinkListenSocket(self);
        self.s.p.stop(self.s.context.loop);
        bsd.closeSocket(self.s.p.fd());
        self.s.next = self.s.context.loop.data.closed_head;
        self.s.context.loop.data.closed_head = &self.s;
        self.s.prev = @ptrCast(@alignCast(self.s.context));
    }
}
