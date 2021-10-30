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
    _ = c_locale.setlocale(c_locale.LC_ALL, "");

    var args = argparser.Args.initDefaults();
    try argparser.parse(allocator, &args);

    var buf: [8]u8 = undefined;
    try std.os.getrandom(buf[0..]);
    var default_prng = std.rand.DefaultPrng.init(std.mem.readIntSliceLittle(u64, buf[0..]));
    const rnd = &default_prng.random;

    var game = try core.Game.init(allocator, args.width, args.height, args.nmines, rnd);
    defer game.deinit();

    const stdscr = try curses.initscr(allocator);
    var endwin_called: bool = false;
    defer {
        if (!endwin_called) {
            curses.endwin() catch {};    // failures are ignored because not much can be done to them
        }
    }

    _ = try curses.curs_set(0);
    _ = try stdscr.keypad(true);

    var ui = try cursesui.Ui.init(&game, stdscr, args.characters, args.color);

    if (!try ui.onResize()) {
        endwin_called = true;
        return;
    }

    // FIXME: the help doesn't fit in 80x24 terminal
    const key_bindings = comptime[_]help.KeyBinding{
        help.KeyBinding{ .key = "q", .help = "quit the game" },
        help.KeyBinding{ .key = "h", .help = "show this help" },
        help.KeyBinding{ .key = "n", .help = "new game" },
        help.KeyBinding{ .key = "arrow keys", .help = "move the selection" },
        help.KeyBinding{ .key = "enter", .help = "open the selected square" },
        help.KeyBinding{ .key = "f", .help = "flag or unflag the selected square" },
        help.KeyBinding{ .key = "d", .help = "open all non-flagged neighbors if the correct number of them are flagged" },
        help.KeyBinding{ .key = "e", .help = "like pressing d in all the squares" },
    };
    ui.setStatusMessage("Press h for help.");

    while (true) {
        try stdscr.erase();
        try ui.draw(allocator);

        switch (try stdscr.getch()) {
            'Q', 'q' => return,
            'N', 'n' => game = try core.Game.init(allocator, args.width, args.height, args.nmines, rnd),
            'H', 'h' => {
                const help_fit_on_terminal = try help.show(stdscr, key_bindings[0..], allocator);
                // terminal may have been resized while looking at help
                if (!try ui.onResize()) {
                    endwin_called = true;
                    return;
                }
                if (!help_fit_on_terminal) {
                    ui.setStatusMessage("Please make your terminal bigger to read the help message.");
                }
            },
            curses.KEY_RESIZE => {
                if (!try ui.onResize()) {
                    endwin_called = true;
                    return;
                }
            },
            curses.KEY_LEFT => ui.moveSelection(-1, 0),
            curses.KEY_RIGHT => ui.moveSelection(1, 0),
            curses.KEY_UP => ui.moveSelection(0, -1),
            curses.KEY_DOWN => ui.moveSelection(0, 1),
            '\n' => ui.openSelected(),
            'F', 'f' => ui.toggleFlagSelected(),
            'D', 'd' => ui.openAroundIfSafe(),
            'E', 'e' => ui.openAroundEverythingSafe(),
            else => {},
        }
    }
}
