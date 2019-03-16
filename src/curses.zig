const std = @import("std");
const c = @cImport({
    @cInclude("src/cursesflags.h");
    @cInclude("curses.h");
});


const Error = error.CursesError;

fn checkError(res: c_int) !c_int {
    if (res == c.ERR) {
        return Error;
    }
    return res;
}

pub const KEY_RESIZE: c_int = c.KEY_RESIZE;
pub const KEY_LEFT: c_int = c.KEY_LEFT;
pub const KEY_RIGHT: c_int = c.KEY_RIGHT;
pub const KEY_UP: c_int = c.KEY_UP;
pub const KEY_DOWN: c_int = c.KEY_DOWN;


pub const Window = struct {
    win: *c.WINDOW,
    allocator: *std.mem.Allocator,

    // TODO: change more things to Window methods

    pub fn erase(self: Window) !void {
        _ = try checkError(c.werase(self.win));
    }

    pub fn mvaddstr(self: Window, y: u16, x: u16, str: []const u8) !void {
        const cstr: []u8 = try self.allocator.alloc(u8, str.len + 1);
        defer self.allocator.free(cstr);
        std.mem.copy(u8, cstr, str);
        cstr[str.len] = 0;
        _ = try checkError(c.mvwaddstr(self.win, y, x, cstr.ptr));
    }

    // TODO: don't use "legacy" functions like getmaxy()?
    pub fn getmaxy(self: Window) u16 { return @intCast(u16, c.getmaxy(self.win)); }
    pub fn getmaxx(self: Window) u16 { return @intCast(u16, c.getmaxx(self.win)); }

    pub fn attron(self: Window, attr: c_int) !void { _ = try checkError(c.wattron(self.win, attr)); }
    pub fn attroff(self: Window, attr: c_int) !void { _ = try checkError(c.wattroff(self.win, attr)); }

    pub fn keypad(self: Window, bf: bool) !c_int { return checkError(c.keypad(self.win, bf)); }
};

pub const A_STANDOUT = c.MY_A_STANDOUT;


pub fn initscr(allocator: *std.mem.Allocator) !Window {
    const res = c.initscr();
    if (@ptrToInt(res) == 0) {
        return Error;
    }
    return Window{ .win = res, .allocator = allocator };
}

pub fn endwin() !void {
    _ = try checkError(c.endwin());
}

pub fn getch() !c_int {
    return try checkError(c.getch());
}

pub fn curs_set(visibility: c_int) !c_int {
    return try checkError(c.curs_set(visibility));
}


pub fn has_colors() bool {
    return c.has_colors();
}

pub fn start_color() !void {
    _ = try checkError(c.start_color());
}

const color_pair_attrs = []c_int{
    -1,                 // 0 doesn't seem to be a valid color pair number, curses returns ERR for it
    c.MY_COLOR_PAIR_1,
    c.MY_COLOR_PAIR_2,
    c.MY_COLOR_PAIR_3,
    c.MY_COLOR_PAIR_4,
    c.MY_COLOR_PAIR_5,
    c.MY_COLOR_PAIR_6,
    c.MY_COLOR_PAIR_7,
    c.MY_COLOR_PAIR_8,
    c.MY_COLOR_PAIR_9,
    c.MY_COLOR_PAIR_10,
};

pub const ColorPair = struct {
    id: c_short,

    pub fn init(id: c_short, front: c_short, back: c_short) !ColorPair {
        std.debug.assert(1 <= id and id < c_short(color_pair_attrs.len));
        _ = try checkError(c.init_pair(id, front, back));
        return ColorPair{ .id = id };
    }

    pub fn attr(self: ColorPair) c_int {
        return color_pair_attrs[@intCast(usize, self.id)];
    }
};

// listed in init_pair man page
pub const COLOR_BLACK = c.COLOR_BLACK;
pub const COLOR_RED = c.COLOR_RED;
pub const COLOR_GREEN = c.COLOR_GREEN;
pub const COLOR_YELLOW = c.COLOR_YELLOW;
pub const COLOR_BLUE = c.COLOR_BLUE;
pub const COLOR_MAGENTA = c.COLOR_MAGENTA;
pub const COLOR_CYAN = c.COLOR_CYAN;
pub const COLOR_WHITE = c.COLOR_WHITE;
