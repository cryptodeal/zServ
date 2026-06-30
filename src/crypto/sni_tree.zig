const std = @import("std");

const max_labels = 10;

threadlocal var sni_free_cb: *const fn (?*anyopaque) void = undefined;

pub const SniNode = struct {
    user: ?*anyopaque = null,
    children: std.StringHashMap(*SniNode),

    pub fn init(allocator: std.mem.Allocator) !*SniNode {
        const node = try allocator.create(SniNode);
        node.* = .{
            .children = std.StringHashMap(*SniNode).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *SniNode, allocator: std.mem.Allocator) void {
        var child_iterator = self.children.iterator();
        while (child_iterator.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            if (entry.value_ptr.*.user) |user| {
                sni_free_cb(user);
            }
            entry.value_ptr.*.deinit(allocator);
        }
        self.children.deinit();
        allocator.destroy(self);
    }
};

pub fn removeUser(allocator: std.mem.Allocator, root: *SniNode, label: u32, labels: []const []const u8) ?*anyopaque {
    if (label == labels.len) {
        const user = root.user;
        root.user = null;
        return user;
    }

    if (root.children.getEntry(labels[label])) |entry| {
        const child = entry.value_ptr.*;
        const removed_user = removeUser(allocator, child, label + 1, labels);
        if (child.children.count() == 0 and child.user == null) {
            allocator.free(entry.key_ptr.*);
            entry.value_ptr.*.deinit(allocator);
            root.children.removeByPtr(entry.key_ptr);
        }
        return removed_user;
    } else return null;
}

pub fn getUser(root: *SniNode, label: u32, labels: []const []const u8) ?*anyopaque {
    if (label == labels.len) return root.user;

    if (root.children.get(labels[label])) |child| {
        if (getUser(child, label + 1, labels)) |user| return user;
    }

    if (root.children.get("*")) |child| {
        return getUser(child, label + 1, labels);
    } else return null;
}

pub fn sniFree(allocator: std.mem.Allocator, sni: *SniNode, cb: *const fn (user: ?*anyopaque) void) void {
    sni_free_cb = cb;
    sni.deinit(allocator);
}

pub fn sniAdd(allocator: std.mem.Allocator, sni: *SniNode, hostname: []const u8, user: ?*anyopaque) !bool {
    var root = sni;
    var split_iterator = std.mem.splitScalar(u8, hostname, '.');
    while (split_iterator.next()) |label| {
        const entry = try root.children.getOrPut(label);
        if (!entry.found_existing) {
            entry.key_ptr.* = try allocator.dupe(u8, label);
            entry.value_ptr.* = try SniNode.init(allocator);
        }
        root = entry.value_ptr.*;
    }
    if (root.user) |_| return true;

    root.user = user;
    return false;
}

pub fn sniRemove(allocator: std.mem.Allocator, sni: *SniNode, hostname: []const u8) ?*anyopaque {
    var labels: [max_labels][]const u8 = undefined;
    var num_labels: u32 = 0;
    var split_iterator = std.mem.splitScalar(u8, hostname, '.');
    while (split_iterator.next()) |label| {
        if (num_labels == 10) return null;
        labels[num_labels] = label;
        num_labels += 1;
    }
    return removeUser(allocator, sni, 0, labels[0..num_labels]);
}

pub fn sniFind(sni: *SniNode, hostname: []const u8) ?*anyopaque {
    var labels: [max_labels][]const u8 = undefined;
    var num_labels: u32 = 0;
    var split_iterator = std.mem.splitScalar(u8, hostname, '.');
    while (split_iterator.next()) |label| {
        if (num_labels == 10) return null;
        labels[num_labels] = label;
        num_labels += 1;
    }
    return getUser(sni, 0, labels[0..num_labels]);
}

test "sni tree" {
    const allocator = std.testing.allocator;
    const sni = try SniNode.init(allocator);
    defer sniFree(allocator, sni, struct {
        pub fn call(user: ?*anyopaque) void {
            std.log.info("freeing user: {d}\n", .{@intFromPtr(user)});
        }
    }.call);
    try std.testing.expectEqual(false, try sniAdd(allocator, sni, "*.google.com", @ptrFromInt(13)));
    try std.testing.expectEqual(false, try sniAdd(allocator, sni, "test.google.com", @ptrFromInt(14)));

    // adding same hostname should not overwrite existing
    try std.testing.expectEqual(true, try sniAdd(allocator, sni, "*.google.com", @ptrFromInt(15)));
    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniFind(sni, "random.google.com")));

    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniFind(sni, "docs.google.com")));
    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniFind(sni, "*.google.com")));
    try std.testing.expectEqual(@as(usize, 14), @intFromPtr(sniFind(sni, "test.google.com")));
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(sniFind(sni, "yolo.nothing.com")));
    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniFind(sni, "yolo.google.com")));

    // should work to remove
    try std.testing.expectEqual(@as(usize, 14), @intFromPtr(sniRemove(allocator, sni, "test.google.com")));
    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniFind(sni, "test.google.com")));
    try std.testing.expectEqual(@as(usize, 13), @intFromPtr(sniRemove(allocator, sni, "*.google.com")));
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(sniFind(sni, "test.google.com")));

    // removing parent with data should not remove child with data
    try std.testing.expectEqual(false, try sniAdd(allocator, sni, "www.google.com", @ptrFromInt(16)));
    try std.testing.expectEqual(false, try sniAdd(allocator, sni, "www.google.com.au.ck.uk", @ptrFromInt(17)));
    try std.testing.expectEqual(@as(usize, 16), @intFromPtr(sniFind(sni, "www.google.com")));
    try std.testing.expectEqual(@as(usize, 17), @intFromPtr(sniFind(sni, "www.google.com.au.ck.uk")));
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(sniRemove(allocator, sni, "www.google.com.yolo")));
    try std.testing.expectEqual(@as(usize, 17), @intFromPtr(sniRemove(allocator, sni, "www.google.com.au.ck.uk")));
    try std.testing.expectEqual(@as(usize, 16), @intFromPtr(sniFind(sni, "www.google.com")));
}
