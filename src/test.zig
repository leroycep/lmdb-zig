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

test "create database, write values and iterate over all values with cursor" {
    var tmpdb = std.testing.tmpDir(.{});
    defer tmpdb.cleanup();

    const dbpath_without_null = try tmpdb.dir.realpathAlloc(std.testing.allocator, "./");
    defer std.testing.allocator.free(dbpath_without_null);
    const dbpath = try std.testing.allocator.dupeZ(u8, dbpath_without_null);
    defer std.testing.allocator.free(dbpath);

    var env = try lmdb.Environment.open(dbpath, .{ .mode = 0o660 });
    var db: lmdb.Database = undefined;
    // Open default database
    {
        var txn = try env.transaction(.{});
        errdefer txn.abort();
        db = try txn.database(null, .{});
        try txn.commit();
    }
    // Add data
    {
        var txn = try env.transaction(.{});
        errdefer txn.abort();
        try txn.put(db, "hello", "world", .{});
        try txn.put(db, "ihello", "apple world", .{});
        try txn.put(db, "ahello", "planet", .{});
        try txn.commit();
    }
    // Iterate over data
    {
        var txn = try env.transaction(.{ .readonly = true });
        defer txn.abort();
        var cursor = try txn.cursor(db);

        var idx: usize = 0;
        var op: lmdb.Cursor.Op = .First;
        while (try cursor.get(null, op)) |entry| : (op = .Next) {
            defer idx += 1;
            const expected_key = switch (idx) {
                0 => "ahello",
                1 => "hello",
                2 => "ihello",
                else => unreachable,
            };
            std.testing.expectEqualSlices(u8, expected_key, entry.key);
            const expected_val = switch (idx) {
                0 => "planet",
                1 => "world",
                2 => "apple world",
                else => unreachable,
            };
            std.testing.expectEqualSlices(u8, expected_val, entry.value);
        }
    }
}
