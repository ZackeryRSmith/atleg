// This file is part of atleg, a TUI library for the zig language.
//
// Copyright © 2023 Zackery .R. Smith
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License version 3 as published
// by the Free Software Foundation.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

// TODO: monitor changes in the termios settings before and after cooking (also during?)
//       This would be nice just to make sure the user knows what's happing to their terminal

const builtin = @import("builtin");
const std = @import("std");
const ascii = std.ascii;
const io = std.io;
const mem = std.mem;
const os = std.os;
const unicode = std.unicode;
const debug = std.debug;
const math = std.math;

// workaround for bad libc integration of zigs std.
const constants = if (builtin.link_libc and builtin.os.tag == .linux) os.linux else os.system;

const Attribute = @import("Attribute.zig");
const sequences = @import("sequences.zig");
const line_writer = @import("line_writer.zig");

const Self = @This();

const TermConfig = struct {
    enter_alt_buffer: bool = true,
    // will only request if the terminal is uncooked
    request_kitty_keyboard_protocol: bool = true,
    request_mouse_tracking: bool = false,

    tty_name: []const u8 = "/dev/tty",
};

/// Are we in raw or cooked mode?
cooked: bool = true,

/// The original termios configuration saved when entering raw mode.
cooked_termios: os.termios = undefined,

/// Size of the terminal, updated fetchSize() is called.
width: usize = undefined,
height: usize = undefined,

/// Are we currently rendering?
rendering: bool = false,

/// Descriptor of opened file.
tty: ?os.fd_t = null,

/// Dumb writer, opt for BufferedWriter as it uses less sys calls.
const Writer = io.Writer(os.fd_t, os.WriteError, os.write);
fn writer(self: Self) Writer {
    return .{ .context = self.tty.? };
}

/// Buffered writer, faster then the Dumb writer as it uses less sys calls.
const BufferedWriter = io.BufferedWriter(4096, Writer);
fn bufferedWriter(self: Self) BufferedWriter {
    return io.bufferedWriter(self.writer());
}

pub fn init(self: *Self, config: TermConfig) !void {
    debug.assert(self.tty == null); // only allow a single successful init
    self.* = .{
        .tty = try os.open(config.tty_name, constants.O.RDWR, 0),
    };
}

// NOTE: deinit should NEVER fail (even if tty == null)
pub fn deinit(self: *Self) void {
    debug.assert(!self.rendering);

    if (self.tty == null) return;

    // cook on exit (just in case)
    if (!self.cooked) self.cook() catch {};

    os.close(self.tty.?);
    self.tty = null;
}

pub fn readInput(self: *Self, buffer: []u8) !usize {
    debug.assert(self.tty != null);
    debug.assert(!self.rendering);
    debug.assert(!self.cooked);
    return try os.read(self.tty.?, buffer);
}

/// Enter raw mode.
pub fn uncook(self: *Self, config: TermConfig) !void {
    // The information on all the various flags and escape sequences is
    // pieced together from a wide number of sources here are the major ones:
    //   * termios(3)
    //   * https://viewsourcecode.org/snaptoken/kilo/
    //   * https://github.com/antirez/kilo
    debug.assert(self.tty != null);

    if (!self.cooked) return;
    self.cooked = false;

    self.cooked_termios = try os.tcgetattr(self.tty.?);
    errdefer self.cook() catch {};

    var raw = self.cooked_termios;

    //   ECHO: Stop the terminal from displaying pressed keys.
    // ICANON: Disable canonical ("cooked") mode. Allows us to read inputs
    //         byte-wise instead of line-wise.
    //   ISIG: Disable signals for Ctrl-C (SIGINT) and Ctrl-Z (SIGTSTP), so we
    //         can handle them as normal escape sequences.
    // IEXTEN: Disable input preprocessing. This allows us to handle Ctrl-V,
    //         which would otherwise be intercepted by some terminals.
    raw.lflag &= ~@as(
        constants.tcflag_t,
        constants.ECHO | constants.ICANON | constants.ISIG | constants.IEXTEN,
    );

    //   IXON: Disable software control flow. This allows us to handle Ctrl-S
    //         and Ctrl-Q.
    //  ICRNL: Disable converting carriage returns to newlines. Allows us to
    //         handle Ctrl-J and Ctrl-M.
    // BRKINT: Disable converting sending SIGINT on break conditions. Likely has
    //         no effect on anything remotely modern.
    //  INPCK: Disable parity checking. Likely has no effect on anything
    //         remotely modern.
    // ISTRIP: Disable stripping the 8th bit of characters. Likely has no effect
    //         on anything remotely modern.
    raw.iflag &= ~@as(
        constants.tcflag_t,
        constants.IXON | constants.ICRNL | constants.BRKINT | constants.INPCK | constants.ISTRIP,
    );

    // Disable output processing. Common output processing includes prefixing
    // newline with a carriage return.
    raw.oflag &= ~@as(constants.tcflag_t, constants.OPOST);

    // Set the character size to 8 bits per byte. Likely has no efffect on
    // anything remotely modern.
    raw.cflag |= constants.CS8;

    // With these settings, the read syscall will immediately return when it
    // can't get any bytes. This allows poll to drive our loop.
    raw.cc[constants.V.TIME] = 0;
    raw.cc[constants.V.MIN] = 0;

    try os.tcsetattr(self.tty.?, .FLUSH, raw);

    var bufwriter = self.bufferedWriter();
    const wrtr = bufwriter.writer();
    try wrtr.writeAll(
        sequences.save_cursor_position ++
            sequences.overwrite_mode ++
            sequences.reset_auto_wrap ++
            sequences.reset_auto_repeat ++
            sequences.reset_auto_interlace ++
            sequences.hide_cursor,
    );
    if (config.request_kitty_keyboard_protocol) {
        try wrtr.writeAll(sequences.enable_kitty_keyboard);
    }
    if (config.request_mouse_tracking) {
        try wrtr.writeAll(sequences.enable_mouse_tracking);
    }
    if (config.enter_alt_buffer) {
        try wrtr.writeAll(sequences.save_screen ++ sequences.enter_alt_buffer);
    }
    try bufwriter.flush();
}

/// Enter cooked mode.
pub fn cook(self: *Self) !void {
    debug.assert(self.tty != null);

    if (self.cooked) return;
    self.cooked = true;

    var bufwriter = self.bufferedWriter();
    const wrtr = bufwriter.writer();
    try wrtr.writeAll(
        // NOTE: even if we did not request the kitty keyboard protocol or mouse
        //       tracking, asking the terminal to disable it should have no effect
        sequences.disable_kitty_keyboard ++
            sequences.disable_mouse_tracking ++
            // TODO: figure out what to do with these, I'd like to have it when exiting
            //       an alternate buffer but otherwise shouldn't happen
            //sequences.clear ++
            sequences.leave_alt_buffer ++
            //sequences.restore_screen ++
            //sequences.restore_cursor_position ++
            sequences.show_cursor ++
            sequences.reset_attributes ++
            sequences.reset_attributes ++ "\n",
    );
    try bufwriter.flush();

    try os.tcsetattr(self.tty.?, .FLUSH, self.cooked_termios);
}

/// Get the terminal's width and height (TERMINAL MUST BE UNCOOKED!)
pub fn fetchSize(self: *Self) !void {
    debug.assert(self.tty != null);

    if (self.cooked) return;
    var size = mem.zeroes(constants.winsize);
    const err = os.system.ioctl(self.tty.?, constants.T.IOCGWINSZ, @intFromPtr(&size));
    if (os.errno(err) != .SUCCESS) {
        return os.unexpectedErrno(@as(os.system.E, @enumFromInt(err)));
    }
    self.height = size.ws_row;
    self.width = size.ws_col;
}

/// Set window title using OSC 2. Shall not be called while rendering.
pub fn setWindowTitle(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    debug.assert(self.tty != null);
    debug.assert(!self.rendering);
    const wrtr = self.writer();
    try wrtr.print("\x1b]2;" ++ fmt ++ "\x1b\\", args);
}

pub fn getRenderContextSafe(self: *Self) !?RenderContext {
    debug.assert(self.tty != null);
    if (self.rendering) return null;
    if (self.cooked) return null;

    self.rendering = true;
    errdefer self.rendering = false;

    var rc = RenderContext{
        .term = self,
        .buffer = self.bufferedWriter(),
    };

    const wrtr = rc.buffer.writer();
    // BUG: at least on the terminal preinstalled on MacOS start sync
    //      will leave an artifact: =1s
    try wrtr.writeAll(sequences.start_sync);
    try wrtr.writeAll(sequences.reset_attributes);

    return rc;
}

pub fn getRenderContext(self: *Self) !RenderContext {
    debug.assert(self.tty != null);
    debug.assert(!self.rendering);
    debug.assert(!self.cooked);
    return (try self.getRenderContextSafe()) orelse unreachable;
}

// TODO: move to it's own file
pub const RenderContext = struct {
    term: *Self,
    buffer: BufferedWriter,

    const LineWriter = line_writer.LineWriter(BufferedWriter.Writer);

    /// Finishes the render operation. The render context may not be used any
    /// further.
    pub fn done(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        debug.assert(!rc.term.cooked);
        defer rc.term.rendering = false;
        const wrtr = rc.buffer.writer();
        // BUG: at least on the terminal preinstalled on MacOS start sync
        //      will leave an artifact: =2s
        try wrtr.writeAll(sequences.end_sync);
        try rc.buffer.flush();
    }

    /// Clears all content.
    pub fn clear(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.writeAll(sequences.clear);
    }

    /// Move the cursor to the specified cell.
    pub fn moveCursorTo(rc: *RenderContext, row: usize, col: usize) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.print(sequences.move_cursor_to_fmt, .{ row + 1, col + 1 });
    }

    /// Move the cursor by an # of rows and cols
    /// Opt for moveCursorTo when possible for performance reasons
    pub fn moveCursorBy(rc: *RenderContext, rows: isize, cols: isize) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        if (rows != 0) {
            if (rows > 0) {
                try wrtr.print(sequences.move_cursor_down_fmt, .{rows});
            } else {
                try wrtr.print(sequences.move_cursor_up_fmt, .{rows * -1});
            }
        }

        if (cols != 0) {
            if (cols > 0) {
                try wrtr.print(sequences.move_cursor_right_fmt, .{cols});
            } else {
                try wrtr.print(sequences.move_cursor_left_fmt, .{cols * -1});
            }
        }
    }

    pub fn moveCursorToCol(rc: *RenderContext, col: usize) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.print(sequences.move_cursor_to_col_fmt, .{col + 1});
    }

    pub fn moveCursorByLine(rc: *RenderContext, lines: isize) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        if (lines > 0) {
            try wrtr.print(sequences.move_cursor_down_fmt ++
                sequences.move_cursor_to_col_fmt, .{ lines, 0 });
        } else {
            try wrtr.print(sequences.move_cursor_up_fmt ++
                sequences.move_cursor_to_col_fmt, .{ lines * -1, 0 });
        }
    }

    pub fn move(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.print(sequences.move_prev_line);
    }

    /// Hide the cursor.
    pub fn hideCursor(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.writeAll(sequences.hide_cursor);
    }

    /// Show the cursor.
    pub fn showCursor(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.writeAll(sequences.show_cursor);
    }

    /// Set the text attributes for all following writes.
    pub fn setAttribute(rc: *RenderContext, attr: Attribute) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try attr.dump(wrtr);
    }

    /// Reset the text attributes for all following writes.
    pub fn resetAttribute(rc: *RenderContext) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.writeAll(sequences.reset_attributes);
    }

    pub fn lineWriter(rc: *RenderContext, len: usize) LineWriter {
        debug.assert(rc.term.rendering);
        return line_writer.lineWriter(rc.buffer.writer(), len);
    }

    /// Write all bytes, wrapping at the end of the line.
    pub fn writeAllWrapping(rc: *RenderContext, bytes: []const u8) !void {
        debug.assert(rc.term.rendering);
        const wrtr = rc.buffer.writer();
        try wrtr.writeAll(sequences.enable_auto_wrap);
        try wrtr.writeAll(bytes);
        try wrtr.writeAll(sequences.reset_auto_wrap);
    }
};
