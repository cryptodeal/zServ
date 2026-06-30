//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
const Io = std.Io;

pub const loop = @import("loop.zig");
pub const Loop = @import("eventing/impl.zig").Loop;
pub const Poll = @import("eventing/impl.zig").Poll;
pub const Socket = @import("socket.zig");
pub const SocketContext = @import("socket_context.zig");
pub const SocketContextOptions = @import("socket_context_options.zig");
pub const InternalCallback = @import("internal_callback.zig");
pub const ListenSocket = @import("listen_socket.zig");

pub const constants = @import("internal/constants.zig");

test "SNI Tree functionality" {
    std.testing.refAllDecls(@import("crypto/sni_tree.zig"));
}
