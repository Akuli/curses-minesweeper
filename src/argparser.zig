const std = @import("std");
const clap = @import("zig-clap");
const cursesui = @import("cursesui.zig");


pub const Args = struct {
    width: u8,
    height: u8,
    nmines: u16,
    characters: cursesui.Characters,
    color: bool,
};

fn parseSize(str: []const u8, width: *u8, height: *u8) !void {
    const i = std.mem.indexOfScalar(u8, str, 'x') orelse return error.CantFindTheX;
    width.* = try std.fmt.parseUnsigned(u8, str[0..i], 10);
    height.* = try std.fmt.parseUnsigned(u8, str[i+1..], 10);
    if (width.* == 0 or height.* == 0) {
        return error.MustNotBeZero;
    }
}

pub fn parse(allocator: *std.mem.Allocator) !Args {
    const params = comptime [_]clap.Param(clap.Help) {
        clap.parseParam("-h, --help                 Display this help and exit") catch unreachable,
        clap.parseParam("-s, --size <STR>           How big to make minesweeper, e.g. 15x15") catch unreachable,
        clap.parseParam("-n, --mine-count <NUM>     How many mines") catch unreachable,
        clap.parseParam("-a, --ascii-only           Use ASCII characters only") catch unreachable,
        clap.parseParam("-c, --no-colors            Do not use colors") catch unreachable,
    };

    var diag = clap.Diagnostic{};
    var args = clap.parse(clap.Help, &params, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        std.os.exit(2);
    };
    defer args.deinit();

    var result = Args{
        .width = 10,
        .height = 10,
        .nmines = 10,
        .characters = cursesui.unicode_characters,
        .color = true,
    };

    if (args.flag("--help")) {
        try std.io.getStdErr().writer().print(
            "Usage: {s} [options]\n\nOptions:\n",
            .{ std.process.args().nextPosix().? });
        try clap.help(std.io.getStdErr().writer(), params[0..]);
        std.os.exit(0);
    }
    if (args.option("--size")) |size| {
        parseSize(size, &result.width, &result.height) catch |err| {
            try std.io.getStdErr().writer().print(
                "{s}: invalid minesweeper size \"{s}\"",
                .{ std.process.args().nextPosix().?, size });
            std.os.exit(2);
        };
    }
    if (args.option("--mine-count")) |mineCount| {
        result.nmines = try std.fmt.parseUnsigned(u8, mineCount, 10);
    }
    if (args.flag("--ascii-only")) {
        result.characters = cursesui.ascii_characters;
    }
    if (args.flag("--no-colors")) {
        result.color = false;
    }

    if (result.nmines >= @intCast(u16, result.width) * @intCast(u16, result.height)) {
        try std.io.getStdErr().writer().print(
            "{s}: there must be less mines than places for mines\n",
            .{ std.process.args().nextPosix().? });
        std.os.exit(2);
    }

    return result;
}
