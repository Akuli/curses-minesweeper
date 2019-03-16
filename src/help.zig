const std = @import("std");
const curses = @import("curses.zig");


pub const KeyBinding = struct { key: []const u8, help: []const u8 };

const Wrapper = struct {
    s: []const u8,
    maxlen: usize,

    fn nextLine(self: *Wrapper) ?[]const u8 {
        if (self.s.len == 0) {
            return null;
        }

        var line = if (std.mem.indexOfScalar(u8, self.s, '\n')) |i| self.s[0..i] else self.s;
        if (line.len > self.maxlen) {
            line = line[0..self.maxlen];
            if (std.mem.lastIndexOfScalar(u8, line, ' ')) |i| {
                line = line[0..i];
            }
        }

        if (self.s.len > line.len and (self.s[line.len] == '\n' or self.s[line.len] == ' ')) {
            self.s = self.s[line.len+1..];
        } else {
            self.s = self.s[line.len..];
        }
        return line;
    }
};


const text_with_single_newlines =
    \\The goal is to open all squares that don't contain mines, but none of the squares that contain
    \\mines. When you have opened a square, the number of the square indicates how many mines there
    \\are in the 8 other squares around the opened square.
    \\
    \\The game ends when all non-mine squares are opened (you win), or a mine square is opened (you
    \\lose).
    ;

// does nothing to \n\n repeated, but replaces single \n with spaces
fn removeSingleNewlines(s: []const u8, allocator: *std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < s.len) {
        if (i+1 < s.len and s[i] == '\n' and s[i+1] == '\n') {
            try result.append('\n');
            try result.append('\n');
            i += 2;
        } else if (s[i] == '\n') {
            try result.append(' ');
            i += 1;
        } else {
            try result.append(s[i]);
            i += 1;
        }
    }
    return result.toOwnedSlice();
}

fn incrementY(window: curses.Window, y: *u16) !void {
    y.* += 1;
    if (y.* >= window.getmaxy()) {
        return error.TerminalIsTooSmall;
    }
}

fn drawText(window: curses.Window, key_bindings: []const KeyBinding, allocator: *std.mem.Allocator) !void {
    try window.erase();

    var maxlen: u16 = 0;
    for (key_bindings) |kb| {
        maxlen = std.math.max(maxlen, @intCast(u16, kb.key.len));
    }

    var y: u16 = 0;
    try window.mvaddstr(y, 0, "Key Bindings:");
    try incrementY(window, &y);
    for (key_bindings) |kb| {
        try window.mvaddstr(y, 2, kb.key);
        try window.mvaddstr(y, 2 + maxlen + 2, kb.help);
        try incrementY(window, &y);
    }
    try incrementY(window, &y);

    {
        const text = try removeSingleNewlines(text_with_single_newlines, allocator);
        defer allocator.free(text);

        var wrapper = Wrapper{ .s = text, .maxlen = window.getmaxx() };
        while (wrapper.nextLine()) |line| {
            try window.mvaddstr(y, 0, line);
            try incrementY(window, &y);
        }
    }

    try window.attron(curses.A_STANDOUT);
    try window.mvaddstr(window.getmaxy() - 1, 0, "Press q to quit this help...");
    try window.attroff(curses.A_STANDOUT);
}

pub fn show(window: curses.Window, key_bindings: []const KeyBinding, allocator: *std.mem.Allocator) !void {
    while (true) {
        drawText(window, key_bindings, allocator) catch |err| switch(err) {
            error.TerminalIsTooSmall => return,     // it might be playable even if help doesn't fit
            else => return err,
        };
        switch (try window.getch()) {
            'Q', 'q' => return,
            else => {},
        }
    }
}
