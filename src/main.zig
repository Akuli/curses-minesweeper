const std = @import("std");
const c_locale = @cImport(@cInclude("locale.h"));
const argparser = @import("argparser.zig");
const core = @import("core.zig");
const curses = @import("curses.zig");
const cursesui = @import("cursesui.zig");
const help = @import("help.zig");


pub fn main() anyerror!void {
    const allocator = std.heap.c_allocator;

    // displaying unicode characters in curses needs this and cursesw in build.zig
    _ = c_locale.setlocale(c_locale.LC_ALL, c"");

    var args = argparser.Args.initDefaults();
    argparser.parse(allocator, &args) catch |e| switch(e) {
        argparser.Error => return,      // error message is printed already
        else => return e,
    };

    var buf: [8]u8 = undefined;
    try std.os.getRandomBytes(buf[0..]);
    var default_prng = std.rand.DefaultPrng.init(std.mem.readIntSliceLittle(u64, buf[0..]));
    const rnd = &default_prng.random;

    var game = try core.Game.init(allocator, args.width, args.height, args.nmines, rnd);
    defer game.deinit();

    const stdscr = try curses.initscr(allocator);
    defer {
        _ = curses.endwin();    // failures are ignored because not much can be done to them
    }

    _ = try curses.curs_set(0);
    _ = try stdscr.keypad(true);

    var ui = try cursesui.Ui.init(&game, stdscr, args.characters);

    if (!try ui.onResize()) {
        return;
    }

    const key_bindings = []const help.KeyBinding{
        help.KeyBinding{ .key = "q", .help = "quit the game" },
        help.KeyBinding{ .key = "h", .help = "show this help" },
        help.KeyBinding{ .key = "n", .help = "new game" },
        help.KeyBinding{ .key = "arrow keys", .help = "move the selection" },
        help.KeyBinding{ .key = "enter", .help = "open the selected square" },
        help.KeyBinding{ .key = "f", .help = "flag or unflag the selected square" },
        help.KeyBinding{ .key = "d", .help = "open all non-flagged neighbors if the correct number of them are flagged" },
    };
    ui.setStatusMessage("Press h for help.");

    while (true) {
        try stdscr.erase();
        try ui.draw(allocator);

        switch (try stdscr.getch()) {
            'Q', 'q' => return,
            'N', 'n' => game = try core.Game.init(allocator, args.width, args.height, args.nmines, rnd),
            'H', 'h' => {
                const help_fit_on_terminal = try help.show(stdscr, key_bindings, allocator);
                // terminal may have been resized while looking at help
                if (!try ui.onResize()) {
                    return;
                }
                if (!help_fit_on_terminal) {
                    ui.setStatusMessage("Please make your terminal bigger to read the help message.");
                }
            },
            curses.KEY_RESIZE => if (!try ui.onResize()) return,
            curses.KEY_LEFT => ui.moveSelection(-1, 0),
            curses.KEY_RIGHT => ui.moveSelection(1, 0),
            curses.KEY_UP => ui.moveSelection(0, -1),
            curses.KEY_DOWN => ui.moveSelection(0, 1),
            '\n' => ui.openSelected(),
            'F', 'f' => ui.toggleFlagSelected(),
            'D', 'd' => ui.openAroundIfSafe(),
            else => {},
        }
    }
}
