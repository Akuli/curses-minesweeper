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

pub fn parse(allocator: std.mem.Allocator) !Args {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var result = Args{
        .width = 10,
        .height = 10,
        .nmines = 10,
        .characters = cursesui.unicode_characters,
        .color = true,
    };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.debug.print("Usage: {s} [options]\n\nOptions:\n", .{args[0]});
            std.debug.print("  -h, --help               Display this help and exit\n", .{});
            std.debug.print("  -s, --size <SIZE>        How big to make minesweeper, e.g. 15x15\n", .{});
            std.debug.print("  -n, --mine-count <NUM>   How many mines\n", .{});
            std.debug.print("  -a, --ascii-only         Use ASCII characters only\n", .{});
            std.debug.print("  -c, --no-colors          Do not use colors\n", .{});
            std.process.exit(0);
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--size")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: Missing value for size\n", .{});
                std.process.exit(2);
            }
            const size = args[i];
            parseSize(size, &result.width, &result.height) catch {
                std.debug.print("Error: Invalid minesweeper size \"{s}\"\n", .{size});
                std.process.exit(2);
            };
        } else if (std.mem.eql(u8, arg, "-n") or std.mem.eql(u8, arg, "--mine-count")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: Missing value for mine count\n", .{});
                std.process.exit(2);
            }
            const mineCount = args[i];
            result.nmines = try std.fmt.parseUnsigned(u16, mineCount, 10);
        } else if (std.mem.eql(u8, arg, "-a") or std.mem.eql(u8, arg, "--ascii-only")) {
            result.characters = cursesui.ascii_characters;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--no-colors")) {
            result.color = false;
        } else {
            std.debug.print("Error: Unknown argument \"{s}\"\n", .{arg});
            std.process.exit(2);
        }
    }

    if (result.nmines >= @as(u16, result.width) * @as(u16, result.height)) {
        std.debug.print("Error: there must be less mines than places for mines\n", .{});
        std.process.exit(2);
    }

    return result;
}
