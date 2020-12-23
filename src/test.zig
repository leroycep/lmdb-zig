const std = @import("std");
const lmdb = @import("./lib.zig");

test "create database, write key and then retrieve it" {
    var tmpdb = std.testing.tmpDir(.{});
    defer tmpdb.cleanup();

    const dbpath_without_null = try tmpdb.dir.realpathAlloc(std.testing.allocator, "./");
    defer std.testing.allocator.free(dbpath_without_null);
    const dbpath = try std.testing.allocator.dupeZ(u8, dbpath_without_null);
    defer std.testing.allocator.free(dbpath);

    var env = try lmdb.Environment.open(dbpath, .{ .mode = 0o660 });
    var db: lmdb.Database = undefined;
    {
        var txn = try env.transaction(.{});
        errdefer txn.abort();
        db = try txn.database(null, .{});
        try txn.commit();
    }
    {
        var txn = try env.transaction(.{});
        errdefer txn.abort();
        try txn.put(db, "hello", "world", .{});
        try txn.commit();
    }
    {
        var txn = try env.transaction(.{ .readonly = true });
        defer txn.abort();
        std.testing.expectEqualSlices(u8, "world", (try txn.get(db, "hello")).?);
    }
}
