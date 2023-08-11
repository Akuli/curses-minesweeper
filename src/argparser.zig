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

pub fn parse() !Args {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                 Display this help and exit
        \\-s, --size <STR>           How big to make minesweeper, e.g. 15x15
        \\-n, --mine-count <NUM>     How many mines
        \\-a, --ascii-only           Use ASCII characters only
        \\-c, --no-colors            Do not use colors
    );

    var diag = clap.Diagnostic{};
    var parse_result = clap.parse(clap.Help, &params, clap.parsers.default, .{ .diagnostic = &diag }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        std.os.exit(2);
    };
    defer parse_result.deinit();

    var result = Args{
        .width = 10,
        .height = 10,
        .nmines = 10,
        .characters = cursesui.unicode_characters,
        .color = true,
    };

    //if (parse_result.args.help != 0) {
    //    try std.io.getStdErr().writer().print(
    //        "Usage: {s} [options]\n\nOptions:\n",
    //        .{ std.process.parse_result.args().nextPosix().? });
    //    try clap.help(std.io.getStdErr().writer(), params[0..]);
    //    std.os.exit(0);
    //}
    if (parse_result.args.size) |size| {
        parseSize(size, &result.width, &result.height) catch {
            try std.io.getStdErr().writer().print(
                "{s}: invalid minesweeper size \"{s}\"",
                .{ std.process.parse_result.args().nextPosix().?, size });
            std.os.exit(2);
        };
    }
    if (parse_result.args.mine_count) |mineCount| {
        result.nmines = try std.fmt.parseUnsigned(u8, mineCount, 10);
    }
    if (parse_result.args.ascii_only != 0) {
        result.characters = cursesui.ascii_characters;
    }
    if (parse_result.args.no_colors != 0) {
        result.color = false;
    }

    if (result.nmines >= @as(u16, result.width) * @as(u16, result.height)) {
        try std.io.getStdErr().writer().print(
            "{s}: there must be less mines than places for mines\n",
            .{ std.process.parse_result.args().nextPosix().? });
        std.os.exit(2);
    }

    return result;
}
