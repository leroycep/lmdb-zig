const std = @import("std");
const lmdb = @import("lmdb");

pub fn main() !void {
    var env = try lmdb.Environment.open("hellodb", .{ .mode = 0o664 });
    defer env.close();

    var db_txn = try env.transaction(.{});
    var db = try db_txn.database(null, .{ .create = true });
    try db_txn.commit();

    var txn = try env.transaction(.{});
    try txn.put(db, "hello", "world", .{});
    
    const value = txn.get(db, "hello");
    std.log.info("hello => {}", .{value}); // prints "hello => world"
    
    try txn.commit();
}
