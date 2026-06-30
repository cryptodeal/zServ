const std = @import("std");

pub const EventBackend = enum {
    io_uring,
    libuv,
    asio,
    gcd,
    epoll,
    kqueue,

    pub fn fromBuildOptions(opts: struct {
        with_io_uring: bool,
        with_libuv: bool,
        with_asio: bool,
        with_gcd: bool,
        with_epoll: bool,
        with_kqueue: bool,
    }, target: std.Target) EventBackend {
        if (opts.with_io_uring) return .io_uring;
        if (opts.with_libuv) return .libuv;
        if (opts.with_asio) return .asio;
        if (opts.with_gcd) return .gcd;
        if (opts.with_epoll) return .epoll;
        if (opts.with_kqueue) return .kqueue;
        return switch (target.os.tag) {
            .windows => .libuv,
            .macos, .freebsd => .kqueue,
            else => .epoll,
        };
    }
};

pub const SslType = enum {
    boringssl,
    openssl,
    wolfssl,
    no_ssl,

    pub fn fromBuildOptions(opts: struct {
        with_boringssl: bool,
        with_openssl: bool,
        with_wolfssl: bool,
    }) SslType {
        if (opts.with_boringssl) return .boringssl;
        if (opts.with_openssl) return .openssl;
        if (opts.with_wolfssl) return .wolfssl;
        return .no_ssl;
    }
};
