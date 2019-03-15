const std = @import("std");
const curses = @import("curses.zig");
const core = @import("core.zig");


pub const Ui = struct {
    selected_x: u8,
    selected_y: u8,
    game: *core.Game,
    window: curses.Window,

    pub fn init(game: *core.Game, window: curses.Window) Ui {
        return Ui{ .selected_x = 0, .selected_y = 0, .game = game, .window = window };
    }

    fn getWidth(self: Ui) u16 { return (self.game.width * @intCast(u16, "|---".len)) + @intCast(u16, "|".len); }
    fn getHeight(self: Ui) u16 { return (self.game.height * 2) + 1; }

    fn drawLine(self: Ui, y: u16, xleft: u16, left: []const u8, mid: []const u8, right: []const u8, horiz: []const u8) !void {
        var x: u16 = xleft;

        var i: u8 = 0;
        while (i < self.game.width) : (i += 1) {
            try self.window.mvaddstr(y, x, (if (i == 0) left else mid));
            x += 1;
            var j: u8 = 0;
            while (j < 3) : (j += 1) {
                try self.window.mvaddstr(y, x, horiz);
                x += 1;
            }
        }
        try self.window.mvaddstr(y, x, right);
    }

    fn drawGrid(self: Ui, allocator: *std.mem.Allocator) !void {
        var top: u16 = (self.window.getmaxy() - self.getHeight()) / 2;
        var left: u16 = (self.window.getmaxx() - self.getWidth()) / 2;

        var gamey: u8 = 0;
        var y: u16 = top;
        while (gamey < self.game.height) : (gamey += 1) {
            if (gamey == 0) {
                try self.drawLine(y, left, ",", "v", ".", "-");
            } else {
                try self.drawLine(y, left, ">", "+", "<", "-");
            }
            y += 1;

            var x: u16 = left;
            var gamex: u8 = 0;
            while (gamex < self.game.width) : (gamex += 1) {
                const info = self.game.getSquareInfo(gamex, gamey);
                var msg = []u8{ 0 };

                if (self.game.status == core.GameStatus.PLAY) {
                    if (info.opened) {
                        msg[0] = '0' + info.n_mines_around;
                    } else {
                        msg[0] = ' ';
                    }
                } else {
                    if (info.mine) {
                        msg[0] = '*';
                    } else {
                        msg[0] = '0' + info.n_mines_around;
                    }
                }

                try self.window.mvaddstr(y, x, "|");
                x += 1;

                const attrs = if (gamex == self.selected_x and gamey == self.selected_y) curses.A_STANDOUT else 0;
                try self.window.attron(attrs);
                {
                    try self.window.mvaddstr(y, x, " ");
                    x += 1;
                    try self.window.mvaddstr(y, x, msg);
                    x += 1;
                    try self.window.mvaddstr(y, x, " ");
                    x += 1;
                }
                try self.window.attroff(attrs);
            }
            try self.window.mvaddstr(y, x, "|");
            y += 1;
        }

        try self.drawLine(y, left, "`", "^", "'", "-");
    }

    // this may overlap the grid on a small terminal, it doesn't matter
    fn drawStatusText(self: Ui, msg: []const u8) !void {
        try self.window.attron(curses.A_STANDOUT);
        try self.window.mvaddstr(self.window.getmaxy()-1, 0, msg);
        try self.window.attroff(curses.A_STANDOUT);
    }

    pub fn draw(self: Ui, allocator: *std.mem.Allocator) !void {
        try self.drawGrid(allocator);
        switch (self.game.status) {
            core.GameStatus.PLAY => {},
            core.GameStatus.WIN => try self.drawStatusText("You won! :D"),
            core.GameStatus.LOSE => try self.drawStatusText("Game Over :("),
        }
    }

    // returns whether to keep running the game
    pub fn onResize(self: Ui) !bool {
        if (self.window.getmaxy() < self.getHeight() or self.window.getmaxx() < self.getWidth()) {
            try curses.endwin();
            std.debug.warn("Terminal is too small :( Need {}x{}.\n", self.getWidth(), self.getHeight());
            return false;
        }
        return true;
    }

    pub fn moveSelection(self: *Ui, xdiff: i8, ydiff: i8) void {
        switch (xdiff) {
            1 => if (self.selected_x != self.game.width-1) { self.selected_x += 1; },
            -1 => if (self.selected_x != 0) { self.selected_x -= 1; },
            0 => {},
            else => unreachable,
        }
        switch(ydiff) {
            1 => if (self.selected_y != self.game.height-1) { self.selected_y += 1; },
            -1 => if (self.selected_y != 0) { self.selected_y -= 1; },
            0 => {},
            else => unreachable,
        }
    }

    pub fn openSelected(self: *Ui) void {
        self.game.open(self.selected_x, self.selected_y);
    }
};
