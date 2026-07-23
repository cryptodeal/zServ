const bsd = @import("../root.zig");
const constants = @import("../constants.zig");
const std = @import("std");

const udp_max_num = constants.udp_max_num;
const udp_max_size = constants.udp_max_size;

const Self = @This();

buf: [udp_max_num][*]u8,
// length tracked separately as we allocate udp_max_size for each buf, but only use a specific length at any given time
len: [udp_max_num]usize,
addr: [udp_max_num]std.c.sockaddr.storage,

pub fn init(allocator: std.mem.Allocator) !*Self {
    var packet_buffer = try allocator.create(Self);
    packet_buffer.* = undefined;
    for (0..udp_max_num) |i| {
        packet_buffer.buf[i] = (try allocator.alloc(u8, udp_max_size)).ptr;
    }
    return packet_buffer;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    for (0..udp_max_num) |i| {
        allocator.free(@as([]u8, self.buf[i][0..udp_max_size]));
    }
    allocator.destroy(self);
}

pub fn ecn(self: *Self, index: usize) u8 {
    return bsd.udpPacketBufferEcn(self, index);
}

pub fn payload(self: *Self, index: usize) []u8 {
    return self.buf[index][0..self.len[index]];
}

pub fn peer(self: *Self, index: usize) [*]u8 {
    return @ptrCast(@alignCast(&self.addr[index]));
}

pub fn localIp(self: *Self, index: usize, ip: []u8) ![]u8 {
    return bsd.udpPacketBufferLocalIp(self, index, ip);
}

pub fn setPayload(self: *Self, index: usize, offset: usize, payload_: []u8, peer_addr: ?*anyopaque) void {
    return bsd.udpPacketBufferSetPayload(self, index, offset, payload_, peer_addr);
}

pub fn sendmmsg(self: *Self, fd: std.posix.fd_t, vlen: usize, flags: u32) !usize {
    return bsd.sendmmsg(fd, self, vlen, flags);
}

pub fn recvmmsg(self: *Self, fd: std.posix.fd_t, vlen: u32, flags: u32, timeout: ?*anyopaque) !usize {
    return bsd.recvmmsg(fd, self, vlen, flags, timeout);
}
