const std = @import("std");


const Square = struct {
    opened: bool,
    mine: bool,
    flagged: bool,
};

pub const SquareInfo = struct {
    opened: bool,
    mine: bool,
    flagged: bool,
    n_mines_around: u8,
};

pub const GameStatus = enum { PLAY, WIN, LOSE };

pub const Game = struct {
    allocator: std.mem.Allocator,
    map: [][]Square,
    width: u8,
    height: u8,
    nmines: u16,
    status: GameStatus,
    mines_added: bool,
    rnd: std.Random,

    pub fn init(allocator: std.mem.Allocator, width: u8, height: u8, nmines: u16, rnd: std.Random) !Game {
        // in the beginning, there are width*height squares, but the mines are
        // added when the user has already opened one of them, otherwise the
        // first square that the user opens could be a mine
        std.debug.assert(@as(u16, width)*@as(u16, height) - 1 >= nmines);

        const map = try allocator.alloc([]Square, height);
        var nalloced: u8 = 0;
        errdefer {
            var i: u8 = 0;
            while (i < nalloced) : (i += 1) {
                allocator.free(map[i]);
            }
            allocator.free(map);
        }

        for (map) |*row| {
            row.* = try allocator.alloc(Square, width);
            nalloced += 1;
            for (row.*) |*square| {
                square.* = Square{ .opened = false, .mine = false, .flagged = false };
            }
        }

        return Game{
            .allocator = allocator,
            .map = map,
            .width = width,
            .height = height,
            .nmines = nmines,
            .status = GameStatus.PLAY,
            .mines_added = false,
            .rnd = rnd,
        };
    }

    pub fn deinit(self: Game) void {
        for (self.map) |arr| {
            self.allocator.free(arr);
        }
        self.allocator.free(self.map);
    }

    const NeighborArray = [8][2]u8;

    fn getNeighbors(self: Game, x: u8, y: u8, res: [][2]u8) [][2]u8 {
        const neighbors = [_][2]i16{
            [2]i16{@as(i16, x)-1, @as(i16, y)-1},
            [2]i16{@as(i16, x)-1, @as(i16, y)  },
            [2]i16{@as(i16, x)-1, @as(i16, y)+1},
            [2]i16{@as(i16, x),   @as(i16, y)+1},
            [2]i16{@as(i16, x)+1, @as(i16, y)+1},
            [2]i16{@as(i16, x)+1, @as(i16, y)  },
            [2]i16{@as(i16, x)+1, @as(i16, y)-1},
            [2]i16{@as(i16, x),   @as(i16, y)-1},
        };
        var i: u8 = 0;

        for (neighbors) |neighbor| {
            const nx_signed = neighbor[0];
            const ny_signed = neighbor[1];
            if (0 <= nx_signed and nx_signed < @as(i16, self.width) and 0 <= ny_signed and ny_signed < @as(i16, self.height)) {
                res[i] = [2]u8{ @intCast(nx_signed), @intCast(ny_signed) };
                i += 1;
            }
        }
        return res[0..i];
    }

    fn countNeighborMines(self: Game, x: u8, y: u8) u8 {
        var neighbors: NeighborArray = undefined;
        var res: u8 = 0;
        for (self.getNeighbors(x, y, neighbors[0..])) |neighbor| {
            const nx = neighbor[0];
            const ny = neighbor[1];
            if (self.map[ny][nx].mine) {
                res += 1;
            }
        }
        return res;
    }

    pub fn getSquareInfo(self: Game, x: u8, y: u8) SquareInfo {
        return SquareInfo{
            .opened = self.map[y][x].opened,
            .mine = self.map[y][x].mine,
            .flagged = self.map[y][x].flagged,
            .n_mines_around = self.countNeighborMines(x, y),
        };
    }

    pub fn debugDump(self: Game) void {
        // M = showing mine, m = hidden mine, S = showing safe, s = hidden safe
        var y: u8 = 0;
        while (y < self.height) : (y += 1) {
            std.debug.warn("|");
            var x: u8 = 0;
            while (x < self.width) : (x += 1) {
                if (self.map[y][x].opened) {
                    if (self.map[y][x].mine) {
                        std.debug.warn("M");
                    } else {
                        std.debug.warn("S");
                    }
                } else {
                    if (self.map[y][x].mine) {
                        std.debug.warn("m");
                    } else {
                        std.debug.warn("s");
                    }
                }

                if (self.map[y][x].mine) {
                    std.debug.warn(" ");
                } else {
                    std.debug.warn("{}", self.countNeighborMines(x, y));
                }
                std.debug.warn("|");
            }
            std.debug.warn("\n");
        }
        std.debug.warn("status = {}\n", self.status);
    }

    fn openRecurser(self: *Game, x: u8, y: u8) void {
        if (self.map[y][x].opened) {
            return;
        }

        self.map[y][x].opened = true;
        if (!self.mines_added) {
            self.addMines();
            self.mines_added = true;
        }

        if (self.map[y][x].mine) {
            self.status = GameStatus.LOSE;
        } else if (self.countNeighborMines(x, y) == 0) {
            var neighbors: NeighborArray = undefined;
            for (self.getNeighbors(x, y, neighbors[0..])) |neighbor| {
                const nx = neighbor[0];
                const ny = neighbor[1];
                self.openRecurser(nx, ny);
            }
        }
    }

    pub fn open(self: *Game, x: u8, y: u8) void {
        if (self.status != GameStatus.PLAY or self.map[y][x].flagged) {
            return;
        }

        self.openRecurser(x, y);
        switch (self.status) {
            GameStatus.PLAY => {},
            GameStatus.LOSE => return,
            GameStatus.WIN => unreachable,    // openRecurser shouldn't set this status
        }

        // try to find a non-mine, non-opened square
        // player won if there are none
        var xx: u8 = 0;
        while (xx < self.width) : (xx += 1) {
            var yy: u8 = 0;
            while (yy < self.height) : (yy += 1) {
                if (!self.map[yy][xx].opened and !self.map[yy][xx].mine) {
                    return;
                }
            }
        }
        self.status = GameStatus.WIN;
    }

    fn addMines(self: *Game) void {
        var mined: u16 = 0;
        while (mined < self.nmines) {
            const x = self.rnd.uintLessThan(u8, self.width);
            const y = self.rnd.uintLessThan(u8, self.height);
            const square = &self.map[y][x];
            if (!square.opened and !square.mine) {
                square.mine = true;
                std.debug.assert(self.map[y][x].mine);
                mined += 1;
            }
        }
    }

    pub fn openAroundIfSafe(self: *Game, x: u8, y: u8) void {
        if (self.status != GameStatus.PLAY or !self.map[y][x].opened) {
            return;
        }

        var arr: NeighborArray = undefined;
        var neighbor_mines: u8 = 0;
        var neighbor_flags: u8 = 0;
        for (self.getNeighbors(x, y, arr[0..])) |neighbor| {
            const nx = neighbor[0];
            const ny = neighbor[1];
            if (self.map[ny][nx].mine) {
                neighbor_mines += 1;
            }
            if (self.map[ny][nx].flagged) {
                neighbor_flags += 1;
            }
        }
        if (neighbor_mines != neighbor_flags) {
            return;
        }

        for (self.getNeighbors(x, y, arr[0..])) |neighbor| {
            const nx = neighbor[0];
            const ny = neighbor[1];
            self.open(nx, ny);
        }
    }

    pub fn openAroundEverythingSafe(self: *Game) void {
        var x: u8 = 0;
        while (x < self.width) : (x += 1) {
            var y: u8 = 0;
            while (y < self.height) : (y += 1) {
                self.openAroundIfSafe(x, y);
            }
        }
    }

    pub fn toggleFlag(self: *Game, x: u8, y: u8) void {
        if (self.status != GameStatus.PLAY or self.map[y][x].opened) {
            return;
        }
        self.map[y][x].flagged = !self.map[y][x].flagged;
    }
};
