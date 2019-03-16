const std = @import("std");
const argparser = @import("argparser.zig");
const core = @import("core.zig");
const curses = @import("curses.zig");
const cursesui = @import("cursesui.zig");


pub fn main() anyerror!void {
    const allocator = std.heap.c_allocator;

    var args = argparser.Args.initDefaults();
    argparser.parse(allocator, &args) catch |e| switch(e) {
        argparser.Error => return,      // error message is printed already
        else => return e,
    };

    var buf: [8]u8 = undefined;
    try std.os.getRandomBytes(buf[0..]);
    var default_prng = std.rand.DefaultPrng.init(std.mem.readIntSliceLittle(u64, buf[0..]));
    const rnd = &default_prng.random;

    var game = try core.Game.init(allocator, 10, 10, 10, rnd);
    defer game.deinit();

    const stdscr = try curses.initscr(allocator);
    defer {
        _ = curses.endwin();    // failures are ignored because not much can be done to them
    }

    _ = try curses.curs_set(0);
    _ = try stdscr.keypad(true);

    var ui = cursesui.Ui.init(&game, stdscr);

    if (!try ui.onResize()) {
        return;
    }

    while (true) {
        try stdscr.erase();
        try ui.draw(allocator);

        switch (try curses.getch()) {
            'Q', 'q' => return,
            curses.KEY_RESIZE => if (!try ui.onResize()) return,
            curses.KEY_LEFT => ui.moveSelection(-1, 0),
            curses.KEY_RIGHT => ui.moveSelection(1, 0),
            curses.KEY_UP => ui.moveSelection(0, -1),
            curses.KEY_DOWN => ui.moveSelection(0, 1),
            '\n' => ui.openSelected(),
            else => {},
        }
    }
}
