const builtin = @import("builtin");
const std = @import("std");
const libuv = if (builtin.os.tag.isDarwin()) @import("darwin_libuv.zig") else @import("libuv");

pub fn UvWrapper(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        value: T,

        pub fn init(allocator: std.mem.Allocator) !*Self {
            const self = try allocator.create(Self);
            self.* = .{
                .allocator = allocator,
                .value = undefined,
            };
            return self;
        }

        pub fn deinit(value: ?*libuv.uv_handle_t) callconv(.c) void {
            const self: *Self = @ptrCast(@alignCast(value.?.data));
            self.allocator.destroy(self);
        }

        pub fn ptr(self: *Self) *T {
            return &self.value;
        }
    };
}
