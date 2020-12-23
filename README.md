# LMDB Zig bindings

This repository creates an idiomatic Zig API on top of LMDB. At the moment the
bindings are incomplete, use at your own risk.

## Using with zigmod

Add the following to `dependencies` in your `zig.mod`:

```yaml
- type: git
  path: https://github.com/leroycep/lmdb-zig.git
```

Then run:

```sh
zigmod fetch
```

Check out the [`zigmod` repository](https://github.com/nektro/zigmod) for more
detail.

## Getting started

Make sure to check out the official [LMDB Getting Started][lmdb-getting-started]
documentation too!

First, you need to create a environment.

```zig
const std = @import("std");
const lmdb = @import("lmdb");

pub fn main() !void {
    var env = try lmdb.Environment.open("hellodb", .{ .mode = 0o664 });
    defer env.close();
}
```

`"hellodb"` in this case is a path to a directory that will be used to store the
environment. This directory needs to exists before it is opened as a LMDB
environment. Here we will make sure it exists by creating it manually. `mode` is
the file mode the UNIX permissions to set on created files.

From there we have to open a transaction to get access to a database:

```zig
    var db_txn = try env.transaction(.{});
    var db = try db_txn.database(null, .{ .create = true });
    try db_txn.commit();
```

Here we pass in the `create` flag to create the database if it doesn't exist in
the environment.

After all that, we can get and put keys and values into the database:

```zig
    var txn = try env.transaction(.{});
    try txn.put(db, "hello", "world", .{});

    const value = txn.get(db, "hello");
    std.log.info("hello => {}", .{value}); // prints "hello => world"

    try txn.commit();
```

You can see the full source in [`examples/simple.zig`](./examples/simple.zig).
To run it we need to create the environment directory:

```sh
$ cd lmdb-zig
$ zigmod fetch
$ mkdir hellodb
$ zig build run-example-simple
info: hello => world
```

If you want to go further than this, please check out the official [LMDB Getting
Started][lmdb-getting-started] documentation.

[lmdb-getting-started]: http://www.lmdb.tech/doc/starting.html

## Raw Bindings

Because `lmdb-zig` is new, not all the LMDB API is covered. If you want to
access the raw bindings, use `lmdb.sys` or `@cInclude("lmdb.h")`.
