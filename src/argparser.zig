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
pub fn parse(allocator: *std.mem.Allocator, resultArgs: *Args) !bool {
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("-h, --help                 Display this help and exit.") catch unreachable,
        clap.parseParam("-s, --size <STR>           How big to make minesweeper, e.g. 15x15") catch unreachable,
        clap.parseParam("-n, --mine-count <NUM>     How many mines") catch unreachable,
        clap.parseParam("-a, --ascii-only           Use ASCII characters only") catch unreachable,
        clap.parseParam("-c, --no-colors            Do not use colors") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return true;
    };
    defer args.deinit();

    if (args.option("--size")) |size| {
        parseSize(size, &resultArgs.width, &resultArgs.height) catch |err| {
            var stderr = std.io.getStdErr();
            _ = try stderr.write(std.process.args().nextPosix().?);
            _ = try stderr.write(": invalid minesweeper size \"");
            _ = try stderr.write(size);
            _ = try stderr.write("\"\n");
            return Error;
        };
    }

    if (args.option("--mine-count")) |mineCount| {
        resultArgs.nmines = try std.fmt.parseUnsigned(u8, mineCount, 10);
    }
    if (args.flag("--ascii-only")) {
        resultArgs.characters = cursesui.ascii_characters;
    }
    if (args.flag("--no-colors")) {
        resultArgs.color = false;
    }

    // must be at the end because --size and --mine-count can be in any order
    if (resultArgs.nmines >= @intCast(u16, resultArgs.width) * @intCast(u16, resultArgs.height)) {
        var stderr = std.io.getStdErr();
        _ = try stderr.write(std.process.args().nextPosix().?);
        _ = try stderr.write(": there must be less mines than places for mines\n");
        return Error;
    }
    return false;
}
