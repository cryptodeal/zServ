const std = @import("std");

fn unpackJsonSources(arr: std.json.Value, alloc: std.mem.Allocator) std.ArrayList([]const u8) {
    var result: std.ArrayList([]const u8) = .empty;
    for (arr.array.items) |it| {
        result.append(alloc, it.string) catch @panic("OOM");
    }
    return result;
}

pub const LibBoringSSL = struct {
    bcm: *std.Build.Step.Compile,
    crypto: *std.Build.Step.Compile,
    ssl: *std.Build.Step.Compile,
    decrepit: *std.Build.Step.Compile,
    pki: *std.Build.Step.Compile,
    bssl: *std.Build.Step.Compile,
    include_path: std.Build.LazyPath,

    pub fn link(self: *const @This(), compile: *std.Build.Step.Compile) *const @This() {
        compile.root_module.linkLibrary(self.bcm);
        compile.root_module.linkLibrary(self.crypto);
        compile.root_module.linkLibrary(self.ssl);
        compile.root_module.linkLibrary(self.decrepit);
        compile.root_module.linkLibrary(self.pki);
        compile.root_module.linkLibrary(self.bssl);
        compile.root_module.addIncludePath(self.include_path);
        return self;
    }

    pub fn installArtifacts(self: *const @This(), b: *std.Build) void {
        b.installArtifact(self.bcm);
        b.installArtifact(self.crypto);
        b.installArtifact(self.ssl);
        b.installArtifact(self.decrepit);
        b.installArtifact(self.pki);
        b.installArtifact(self.bssl);
    }
};

pub fn createBoringssl(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) ?LibBoringSSL {
    const boringssl = b.lazyDependency("boringssl", .{}) orelse return null;

    var arena = std.heap.ArenaAllocator.init(b.allocator);

    const data = blk: {
        const path = boringssl.path("gen/sources.json").getPath(b);

        const file = std.Io.Dir.cwd().openFile(b.graph.io, path, .{}) catch @panic("failed to open gen/sources.json for sources");
        var buf: [1024]u8 = undefined;
        var reader = file.reader(b.graph.io, &buf);
        break :blk reader.interface.readAlloc(b.allocator, @intCast(file.length(b.graph.io) catch unreachable)) catch unreachable;
    };
    defer b.allocator.free(data);

    const Sources = struct {
        const Src = struct {
            srcs: std.json.Value,
            @"asm": std.json.Value,
            nasm: std.json.Value,
        };
        const SrcWithoutAsm = struct {
            srcs: std.json.Value,
        };

        bcm: Src,
        crypto: Src,
        decrepit: SrcWithoutAsm,
        pki: SrcWithoutAsm,
        bssl: SrcWithoutAsm,
        ssl: SrcWithoutAsm,
    };

    const parsed = std.json.parseFromSlice(
        Sources,
        b.allocator,
        data,
        .{ .ignore_unknown_fields = true },
    ) catch @panic("parse sources failed");
    defer parsed.deinit();
    const sources: Sources = parsed.value;

    const windows = target.result.os.tag == .windows;

    const bcm = b.addLibrary(.{
        .name = "bcm",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
        .linkage = .static,
    });

    bcm.link_function_sections = true;
    bcm.link_data_sections = true;
    bcm.link_gc_sections = true;
    bcm.root_module.addIncludePath(boringssl.path("include"));

    var bcm_sources = unpackJsonSources(sources.bcm.srcs, b.allocator);
    var bcm_asm_sources = unpackJsonSources(sources.bcm.@"asm", b.allocator);
    defer bcm_sources.deinit(b.allocator);
    defer bcm_asm_sources.deinit(b.allocator);

    bcm.root_module.addCSourceFiles(.{
        .files = bcm_sources.items,
        .root = boringssl.path(""),
    });

    bcm.root_module.addCSourceFiles(.{
        .files = bcm_asm_sources.items,
        .root = boringssl.path(""),
        .language = .assembly_with_preprocessor,
    });

    if (windows) {
        // Temporary disable assembly
        // boringssl assembly on windows use microsoft nasm `.asm` files,
        // which is not supported by clang / llvm / zig, so call nasm manually is required.
        //
        // ref: (Zig Discord server)
        // https://canary.discord.com/channels/605571803288698900/719644313348341760/1419174777247240295
        bcm.root_module.addCMacro("OPENSSL_NO_ASM", "1");
    }

    const libcrypto = b.addLibrary(.{
        .name = "crypto",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    libcrypto.link_function_sections = true;
    libcrypto.link_data_sections = true;
    libcrypto.link_gc_sections = true;
    libcrypto.root_module.linkLibrary(bcm);
    libcrypto.root_module.addIncludePath(boringssl.path("include"));

    var crypto_sources = unpackJsonSources(sources.crypto.srcs, b.allocator);
    var crypto_asm_sources = unpackJsonSources(sources.crypto.@"asm", b.allocator);
    defer crypto_sources.deinit(b.allocator);
    defer crypto_asm_sources.deinit(b.allocator);

    libcrypto.root_module.addCSourceFiles(.{
        .files = crypto_sources.items,
        .root = boringssl.path(""),
    });

    libcrypto.root_module.addCSourceFiles(.{
        .files = crypto_asm_sources.items,
        .root = boringssl.path(""),
        .language = .assembly_with_preprocessor,
    });

    if (windows) {
        // Temporary disable assembly
        // boringssl assembly on windows use microsoft nasm `.asm` files,
        // which is not supported by clang / llvm / zig, so call nasm manually is required.
        //
        // ref: (Zig Discord server)
        // https://canary.discord.com/channels/605571803288698900/719644313348341760/1419174777247240295
        libcrypto.root_module.addCMacro("OPENSSL_NO_ASM", "1");
    }

    _ = arena.reset(.retain_capacity);
    defer arena.deinit();

    const libssl = b.addLibrary(.{
        .name = "ssl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    if (target.result.isMinGW()) {
        libssl.root_module.addCMacro("NOCRYPT", "1");
    }
    libssl.link_function_sections = true;
    libssl.link_data_sections = true;
    libssl.link_gc_sections = true;
    libssl.root_module.linkLibrary(libcrypto);
    libssl.root_module.addIncludePath(boringssl.path("include"));
    libssl.installHeadersDirectory(boringssl.path("include"), "", .{});

    var ssl_sources: std.ArrayListUnmanaged([]const u8) = unpackJsonSources(sources.ssl.srcs, b.allocator);
    defer ssl_sources.deinit(b.allocator);

    libssl.root_module.addCSourceFiles(.{
        .files = ssl_sources.items,
        .root = boringssl.path(""),
    });

    const libdecrepit = b.addLibrary(.{
        .name = "decrepit",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .static,
    });

    libdecrepit.link_function_sections = true;
    libdecrepit.link_data_sections = true;
    libdecrepit.link_gc_sections = true;
    libdecrepit.root_module.linkLibrary(libcrypto);
    libdecrepit.root_module.linkLibrary(libssl);
    libdecrepit.root_module.addIncludePath(boringssl.path("include"));

    var decrepit_sources = unpackJsonSources(sources.decrepit.srcs, b.allocator);
    defer decrepit_sources.deinit(b.allocator);

    libdecrepit.root_module.addCSourceFiles(.{
        .files = decrepit_sources.items,
        .root = boringssl.path(""),
    });

    const libpki = b.addLibrary(.{
        .name = "pki",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .linkage = .static,
    });

    libpki.link_function_sections = true;
    libpki.link_data_sections = true;
    libpki.link_gc_sections = true;
    libpki.root_module.linkLibrary(libcrypto);
    libpki.root_module.addIncludePath(boringssl.path("include"));

    var pki_sources = unpackJsonSources(sources.pki.srcs, b.allocator);
    defer pki_sources.deinit(b.allocator);

    libpki.root_module.addCSourceFiles(.{
        .files = pki_sources.items,
        .root = boringssl.path(""),
    });

    const bssl = b.addLibrary(.{
        .name = "bssl",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    if (target.result.os.tag == .windows) {
        bssl.root_module.addCMacro("NOCRYPT", "1");
    }
    bssl.link_function_sections = true;
    bssl.link_data_sections = true;
    bssl.link_gc_sections = true;
    bssl.root_module.linkLibrary(libssl);
    bssl.root_module.linkLibrary(libcrypto);
    bssl.root_module.addIncludePath(boringssl.path("include"));

    var bssl_sources = unpackJsonSources(sources.bssl.srcs, b.allocator);
    defer bssl_sources.deinit(b.allocator);

    bssl.root_module.addCSourceFiles(.{
        .files = bssl_sources.items,
        .root = boringssl.path(""),
    });

    return .{
        .bcm = bcm,
        .crypto = libcrypto,
        .ssl = libssl,
        .decrepit = libdecrepit,
        .pki = libpki,
        .bssl = bssl,
        .include_path = boringssl.path("include"),
    };
}
