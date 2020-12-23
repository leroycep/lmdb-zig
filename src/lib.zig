pub const sys = @import("./sys.zig");

usingnamespace sys;

const log = @import("std").log.scoped(.lmdb);

fn lmdbToZigErr(num: c_int) !void {
    switch (num) {
        0 => {},
        EINVAL => return error.InvalidParameter,
        ENOMEM => return error.OutOfMemory,
        ENOENT => return error.FileNotFound,
        EACCES => return error.AccessDenied,
        EAGAIN => return error.WouldBlock,
        EIO => return error.InputOutput,
        ENOSPC => return error.NoDiskSpace,
        MDB_PANIC => return error.Panic,
        MDB_MAP_RESIZED => return error.MapResized,
        MDB_READERS_FULL => return error.ReadersFull,
        MDB_VERSION_MISMATCH => return error.VersionMismatch,
        MDB_INVALID => return error.Invalid,
        MDB_NOTFOUND => return error.NotFound,
        MDB_DBS_FULL => return error.DatabasesFull,
        MDB_KEYEXIST => return error.KeyExist,
        MDB_MAP_FULL => return error.MapFull,
        MDB_TXN_FULL => return error.TransactionFull,
        else => |n| {
            log.err("Unexpected lmdbToZigErr: {}", .{n});
            unreachable;
        },
    }
}

fn span(mv: MDB_val) []u8 {
    return @ptrCast([*]u8, mv.mv_data)[0..mv.mv_size];
}

fn spanMV(slice: []u8) MDB_val {
    return MDB_val{ .mv_size = slice.len, .mv_data = slice.ptr };
}

fn spanMVConst(slice: []const u8) MDB_val {
    const int_ptr = @ptrToInt(slice.ptr);
    return MDB_val{ .mv_size = slice.len, .mv_data = @intToPtr([*]u8, int_ptr) };
}

pub const Environment = struct {
    env: *MDB_env,

    pub const OpenOptions = struct {
        mode: mdb_mode_t,

        // Env options
        maxdbs: ?u32 = null,
        mapsize: ?usize = null,

        // Env Open Flags
        fixedmap: bool = false,
        nosubdir: bool = false,
        readonly: bool = false,
        writemap: bool = false,
        nometasync: bool = false,
        nosync: bool = false,
        mapasync: bool = false,
        nothreadlocalstorage: bool = false,
        nolock: bool = false,
        noreadahead: bool = false,
        nomeminit: bool = false,
    };

    pub fn open(path: [:0]const u8, options: OpenOptions) !@This() {
        var env_opt: ?*MDB_env = null;

        lmdbToZigErr(mdb_env_create(&env_opt)) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => unreachable,
        };

        var env = env_opt.?;

        if (options.maxdbs) |maxdbs| {
            lmdbToZigErr(mdb_env_set_maxdbs(env, maxdbs)) catch |err| switch (err) {
                error.InvalidParameter => |e| return e,
                else => unreachable,
            };
        }
        if (options.mapsize) |mapsize| {
            lmdbToZigErr(mdb_env_set_mapsize(env, mapsize)) catch |err| switch (err) {
                error.InvalidParameter => |e| return e,
                else => unreachable,
            };
        }

        var flags: u32 = 0;
        if (options.fixedmap) flags |= MDB_FIXEDMAP;
        if (options.nosubdir) flags |= MDB_NOSUBDIR;
        if (options.readonly) flags |= MDB_RDONLY;
        if (options.writemap) flags |= MDB_WRITEMAP;
        if (options.nometasync) flags |= MDB_NOMETASYNC;
        if (options.nosync) flags |= MDB_NOSYNC;
        if (options.mapasync) flags |= MDB_MAPASYNC;
        if (options.nothreadlocalstorage) flags |= MDB_NOTLS;
        if (options.nolock) flags |= MDB_NOLOCK;
        if (options.noreadahead) flags |= MDB_NORDAHEAD;
        if (options.nomeminit) flags |= MDB_NOMEMINIT;

        lmdbToZigErr(mdb_env_open(env, path, flags, options.mode)) catch |err| switch (err) {
            error.VersionMismatch,
            error.Invalid,
            error.FileNotFound,
            error.AccessDenied,
            error.WouldBlock,
            => |e| return e,

            else => unreachable,
        };

        return @This(){
            .env = env,
        };
    }

    pub fn close(this: *@This()) void {
        mdb_env_close(this.env);
    }

    pub fn transaction(this: *@This(), options: Transaction.Options) !Transaction {
        return Transaction.begin(this, options);
    }

    pub fn closeDatabase(this: *@This(), database: Database) void {
        mdb_dbi_close(this.env, database.dbi);
    }
};

pub const Transaction = struct {
    txn: *MDB_txn,

    pub const Options = struct {
        parent: ?*Transaction = null,
        readonly: bool = false,
    };

    pub fn begin(environment: *Environment, options: Options) !@This() {
        var flags: u32 = 0;
        if (options.readonly) flags |= MDB_RDONLY;

        const parent = if (options.parent) |parent| parent.txn else null;

        var txn_opt: ?*MDB_txn = null;
        lmdbToZigErr(mdb_txn_begin(environment.env, parent, flags, &txn_opt)) catch |err| switch (err) {
            error.Panic,
            error.MapResized,
            error.ReadersFull,
            error.OutOfMemory,
            => |e| return e,

            else => unreachable,
        };

        return @This(){
            .txn = txn_opt.?,
        };
    }

    pub fn commit(this: *@This()) !void {
        lmdbToZigErr(mdb_txn_commit(this.txn)) catch |err| switch (err) {
            error.InvalidParameter,
            error.NoDiskSpace,
            error.InputOutput,
            error.OutOfMemory,
            => |e| return e,

            else => unreachable,
        };
    }

    pub fn abort(this: *@This()) void {
        mdb_txn_abort(this.txn);
    }

    pub fn renew(this: *@This()) !void {
        lmdbToZigErr(mdb_txn_renew(this.txn)) catch |err| switch (err) {
            error.Panic,
            error.InvalidParameter,
            error.NoDiskSpace,
            error.InputOutput,
            error.OutOfMemory,
            => |e| return e,

            else => unreachable,
        };
    }

    pub fn database(this: *@This(), name: ?[:0]const u8, options: Database.Options) !Database {
        return Database.open(this, name, options);
    }

    pub fn cursor(this: *@This(), db: Database) !Cursor {
        return Cursor.open(this, db);
    }

    pub fn get(this: *@This(), db: Database, key: []const u8) !?[]const u8 {
        var key_mv: MDB_val = spanMVConst(key);
        var val_mv: MDB_val = .{ .mv_data = null, .mv_size = 0 };

        lmdbToZigErr(mdb_get(this.txn, db.dbi, &key_mv, &val_mv)) catch |err| switch (err) {
            error.NotFound => return null,
            error.InvalidParameter => |e| return e,
            else => unreachable,
        };

        return span(val_mv);
    }

    pub const PutOptions = struct {
        nodupdata: bool = false,
        nooverwrite: bool = false,
        append: bool = false,
        appenddup: bool = false,

        // TODO: make a put functions for to reserve
        //reserve: bool = false
    };

    pub fn put(this: *@This(), db: Database, key: []const u8, val: []const u8, options: PutOptions) !void {
        var flags: u32 = 0;
        if (options.nodupdata) flags |= MDB_NODUPDATA;
        if (options.nooverwrite) flags |= MDB_NOOVERWRITE;
        if (options.append) flags |= MDB_APPEND;
        if (options.appenddup) flags |= MDB_APPENDDUP;

        var key_mv: MDB_val = spanMVConst(key);
        var val_mv: MDB_val = spanMVConst(val);

        lmdbToZigErr(mdb_put(this.txn, db.dbi, &key_mv, &val_mv, flags)) catch |err| switch (err) {
            error.KeyExist,
            error.MapFull,
            error.TransactionFull,
            error.AccessDenied,
            error.InvalidParameter,
            => |e| return e,
            else => unreachable,
        };
    }
};

pub const Database = struct {
    dbi: MDB_dbi,

    pub const Options = struct {
        reversekey: bool = false,
        dupsort: bool = false,
        integerkey: bool = false,
        dupfixed: bool = false,
        integerdup: bool = false,
        reversedup: bool = false,
        create: bool = false,
    };

    pub fn open(transaction: *Transaction, name: ?[:0]const u8, options: Options) !@This() {
        var flags: u32 = 0;
        if (options.reversekey) flags |= MDB_REVERSEKEY;
        if (options.dupsort) flags |= MDB_DUPSORT;
        if (options.integerkey) flags |= MDB_INTEGERKEY;
        if (options.dupfixed) flags |= MDB_DUPFIXED;
        if (options.integerdup) flags |= MDB_INTEGERDUP;
        if (options.reversedup) flags |= MDB_REVERSEDUP;
        if (options.create) flags |= MDB_CREATE;

        var dbi: MDB_dbi = undefined;
        lmdbToZigErr(mdb_dbi_open(transaction.txn, name orelse null, flags, &dbi)) catch |err| switch (err) {
            error.NotFound,
            error.DatabasesFull,
            => |e| return e,

            else => unreachable,
        };

        return @This(){
            .dbi = dbi,
        };
    }
};

pub const Cursor = struct {
    cursor: *MDB_cursor,

    pub fn open(transaction: *Transaction, database: Database) !@This() {
        var cursor_opt: ?*MDB_cursor = null;
        lmdbToZigErr(mdb_cursor_open(transaction.txn, database.dbi, &cursor_opt)) catch |err| switch (err) {
            error.InvalidParameter => |e| return e,

            else => unreachable,
        };

        return @This(){
            .cursor = cursor_opt.?,
        };
    }

    pub fn close(this: *@This()) void {
        mdb_cursor_close(this.cursor);
    }

    pub const Op = enum {
        First,
        Next,
        Last,
        Prev,
    };

    pub const Entry = struct {
        key: []const u8,
        value: []const u8,
    };

    pub fn get(this: *@This(), key_opt: ?[]const u8, op: Op) !?Entry {
        var key_mv: MDB_val = if (key_opt) |key| spanMVConst(key) else .{ .mv_data = null, .mv_size = 0 };
        var val_mv: MDB_val = .{ .mv_data = null, .mv_size = 0 };

        const mdb_op: MDB_cursor_op = switch (op) {
            .First => .MDB_FIRST,
            .Next => .MDB_NEXT,
            .Last => .MDB_LAST,
            .Prev => .MDB_PREV,
        };

        lmdbToZigErr(mdb_cursor_get(this.cursor, &key_mv, &val_mv, mdb_op)) catch |err| switch (err) {
            error.NotFound => return null,
            error.InvalidParameter => |e| return e,
            else => unreachable,
        };

        return Entry{
            .key = span(key_mv),
            .value = span(val_mv),
        };
    }
};
