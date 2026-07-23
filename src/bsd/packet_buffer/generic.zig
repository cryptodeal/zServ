const bsd = @import("../root.zig");
const builtin = @import("builtin");
const c = @import("../c.zig");
const cmsg = @import("../cmsg.zig");
const constants = @import("../constants.zig");
const std = @import("std");

const udp_max_num = constants.udp_max_num;
const udp_max_size = constants.udp_max_size;

const Self = @This();

msgvec: [udp_max_num]std.c.mmsghdr,
iov: [udp_max_num]std.c.iovec,
addr: [udp_max_num]std.c.sockaddr.storage,
control: [udp_max_num][256]u8,
// has_addresses: bool = false,

pub fn init(allocator: std.mem.Allocator) !*Self {
    var packet_buffer = try allocator.create(Self);
    packet_buffer.* = undefined;
    for (0..udp_max_num) |i| {
        packet_buffer.iov[i].base = (try allocator.alloc(u8, udp_max_size)).ptr;
        packet_buffer.iov[i].len = udp_max_size;
        packet_buffer.msgvec[i].hdr = .{
            .name = @ptrCast(@alignCast(&packet_buffer.addr[i])),
            .namelen = @sizeOf(std.c.sockaddr.storage),
            .iov = @ptrCast(@alignCast(&packet_buffer.iov[i])),
            .iovlen = 1,
            .control = &packet_buffer.control[i],
            .controllen = 1,
            .flags = 0,
        };
    }
    return packet_buffer;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (0..udp_max_num) |i| {
        allocator.free(@as([]u8, self.iov[i].base[0..udp_max_size]));
    }
    allocator.destroy(self);
}

pub fn ecn(self: *Self, index: usize) u8 {
    return bsd.udpPacketBufferEcn(&self.msgvec, index);
}

pub fn payload(self: *Self, index: usize) []u8 {
    return bsd.udpPacketBufferPayload(&self.msgvec, index);
}

pub fn peer(self: *Self, index: usize) [*]u8 {
    return bsd.udpPacketBufferPeer(&self.msgvec, index);
}

pub fn localIp(self: *Self, index: usize, buf: []u8) ![]u8 {
    return bsd.udpPacketBufferLocalIp(&self.msgvec, index, buf);
}

pub fn setPayload(self: *Self, index: usize, offset: usize, payload_: []u8, peer_addr: ?*anyopaque) void {
    return bsd.udpPacketBufferSetPayload(&self.msgvec, index, offset, payload_, peer_addr);
}

pub fn sendmmsg(self: *Self, fd: std.posix.fd_t, vlen: u32, flags: u32) !usize {
    return bsd.sendmmsg(fd, &self.msgvec, vlen, flags);
}

pub fn recvmmsg(self: *Self, fd: std.posix.fd_t, vlen: u32, flags: u32, timeout: ?*anyopaque) !usize {
    return bsd.recvmmsg(fd, &self.msgvec, vlen, flags, timeout);
}
