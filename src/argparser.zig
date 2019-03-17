const std = @import("std");
const clap = @import("zig-clap");
const cursesui = @import("cursesui.zig");


pub const Args = struct {
    width: u8,
    height: u8,
    nmines: u16,
    characters: cursesui.Characters,
    color: bool,

    pub fn initDefaults() Args {
        return Args{
            .width = 10,
            .height = 10,
            .nmines = 10,
            .characters = cursesui.unicode_characters,
            .color = true,
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

fn helpText(param: clap.Param(u8)) []const u8 {
    return switch (param.id) {
        'h' => "show this help and exit",
        's' => "size of the minesweeper, e.g. 15x10",
        'n' => "number of mines to add to the game",
        'a' => "use only ASCII characters",
        'c' => "don't use colors",
        else => unreachable,
    };
}

fn valueText(param: clap.Param(u8)) []const u8 {
    return switch (param.id) {
        's' => "WIDTHxHEIGHT",
        'n' => "NUMBER",
        else => unreachable,
    };
}

// returns true when the process should exit immediately (e.g. --help)
pub fn parse(allocator: *std.mem.Allocator, args: *Args) !bool {
    const params = []clap.Param(u8) {
        clap.Param(u8).flag('h', clap.Names.long("help")),
        clap.Param(u8).option('s', clap.Names.both("size")),
        clap.Param(u8).option('n', clap.Names{ .short = 'n', .long = "mine-count" }),
        clap.Param(u8).flag('a', clap.Names.both("ascii-only")),
        clap.Param(u8).flag('c', clap.Names.long("no-colors")),
    };

    var iter = clap.args.OsIterator.init(allocator);
    defer iter.deinit();
    const exe = (try iter.next()).?;

    var parser = clap.StreamingClap(u8, clap.args.OsIterator).init(params, &iter);
    while (try parser.next()) |arg| {
        switch (arg.param.id) {
            'h' => {
                const stdout = try std.io.getStdOut();
                const stream = &stdout.outStream().stream;
                try stream.print("Usage: {} [options]\n\nOptions:\n", exe);
                try clap.helpEx(stream, u8, params, helpText, valueText);
                return true;
            },
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
            'c' => args.color = false,
            else => unreachable,
        }
    }

    // must be at the end because --size and --mine-count can be in any order
    if (args.nmines >= u16(args.width) * u16(args.height)) {
        std.debug.warn("{}: there must be less mines than places for mines\n", exe);
        return Error;
    }
    return false;
}
