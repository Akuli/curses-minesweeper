const std = @import("std");
const clap = @import("zig-clap");
const cursesui = @import("cursesui.zig");


pub const Args = struct {
    width: u8,
    height: u8,
    nmines: u16,
    characters: cursesui.Characters,

    pub fn initDefaults() Args {
        return Args{
            .width = 10,
            .height = 10,
            .nmines = 10,
            .characters = cursesui.unicode_characters,
        };
    }
};


pub const Error = error.ArgparserInvalidArg;

fn parseSize(str: []const u8, width: *u8, height: *u8) !void {
    const i = std.mem.indexOfScalar(u8, str, 'x') orelse return error.CantFindTheX;
    width.* = try std.fmt.parseUnsigned(u8, str[0..i], 10);
    height.* = try std.fmt.parseUnsigned(u8, str[i+1..], 10);
    if (width.* == 0 or height.* == 0) {
        return error.MustNotBeZero;
    }
}

pub fn parse(allocator: *std.mem.Allocator, args: *Args) !void {
    const params = []clap.Param(u8) {
        clap.Param(u8).option('s', clap.Names.both("size")),
        clap.Param(u8).option('n', clap.Names{ .short = 'n', .long = "mine-count" }),
        clap.Param(u8).flag('a', clap.Names.both("ascii-only")),
    };

    var iter = clap.args.OsIterator.init(allocator);
    defer iter.deinit();
    const exe = (try iter.next()).?;

    var parser = clap.StreamingClap(u8, clap.args.OsIterator).init(params, &iter);
    while (try parser.next()) |arg| {
        switch (arg.param.id) {
            's' => parseSize(arg.value.?, &args.width, &args.height) catch |err| {
                std.debug.warn("{}: invalid minesweeper size \"{}\": ", exe, arg.value.?);
                switch (err) {
                    error.Overflow => std.debug.warn("numbers cannot be bigger than {}\n", @intCast(u8, std.math.maxInt(u8))),
                    error.InvalidCharacter => std.debug.warn("number contains invalid character\n"),

                    error.CantFindTheX => std.debug.warn("expected two x-separated numbers\n"),
                    error.MustNotBeZero => std.debug.warn("expected a positive number, not 0\n"),
                }
                return Error;
            },
            'n' => args.nmines = std.fmt.parseUnsigned(u16, arg.value.?, 10) catch |err| {
                std.debug.warn("{}: mine count must be an integer between 0 and {}\n",
                    exe, @intCast(u16, std.math.maxInt(u16)));
                return Error;
            },
            'a' => args.characters = cursesui.ascii_characters,
            else => unreachable,
        }
    }

    // must be at the end because --size and --mine-count can be in any order
    if (args.nmines >= u16(args.width) * u16(args.height)) {
        std.debug.warn("{}: there must be less mines than places for mines\n", exe);
        return Error;
    }
}
