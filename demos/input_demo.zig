// TODO: add a way to see repeated keypresses

const std = @import("std");
const os = std.os;
const unicode = std.unicode;
const stdout = std.io.getStdOut().writer();

const atleg = @import("atleg");
const renderHeader = @import("header.zig").renderHeader;

var term: atleg.Term = undefined;
var loop: bool = true;
var buf: [32]u8 = undefined;
var read: usize = undefined;
var empty: bool = true; // no buttons have been pressed yet

pub fn main() !void {
    try term.init(.{});
    defer term.deinit();

    var fds: [1]os.pollfd = undefined;
    fds[0] = .{
        .fd = term.tty.?,
        .events = os.POLL.IN,
        .revents = undefined,
    };

    try term.uncook(.{ .enter_alt_buffer = true, .request_mouse_tracking = true });
    defer term.cook() catch {};

    try term.fetchSize();

    try render();

    while (loop) {
        _ = try os.poll(&fds, -1);

        read = try term.readInput(&buf);
        if (read == 0) continue;

        empty = false;

        try render();
    }
}

pub fn render() !void {
    var rc = try term.getRenderContext();
    defer rc.done() catch {};

    try rc.clear();

    if (empty) {
        try renderHeader(&rc, term.width, "input tester", "Welcome to the demo, press any key to get started!");
        return;
    }

    try renderHeader(&rc, term.width, "input tester", "Press 'q' to exit the demo");

    // is valid unicode?
    var valid_unicode = true;
    _ = unicode.Utf8View.init(buf[0..read]) catch {
        valid_unicode = false;
    };

    try rc.setAttribute(.{ .bold = true });
    var line = rc.lineWriter(term.width);
    var writer = line.writer();
    try writer.writeAll(" Valid unicode: ");
    try rc.resetAttribute();
    if (valid_unicode) {
        try writer.writeAll("yes: \"");
        for (buf[0..read]) |c| {
            switch (c) {
                127 => try writer.writeAll("^H"),
                '\x1B' => try writer.writeAll("\\x1B"),
                '\t' => try writer.writeAll("\\t"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                'a' & '\x1F' => try writer.writeAll("^a"),
                'b' & '\x1F' => try writer.writeAll("^b"),
                'c' & '\x1F' => try writer.writeAll("^c"),
                'd' & '\x1F' => try writer.writeAll("^d"),
                'e' & '\x1F' => try writer.writeAll("^e"),
                'f' & '\x1F' => try writer.writeAll("^f"),
                'g' & '\x1F' => try writer.writeAll("^g"),
                'h' & '\x1F' => try writer.writeAll("^h"),
                'k' & '\x1F' => try writer.writeAll("^k"),
                'l' & '\x1F' => try writer.writeAll("^l"),
                'n' & '\x1F' => try writer.writeAll("^n"),
                'o' & '\x1F' => try writer.writeAll("^o"),
                'p' & '\x1F' => try writer.writeAll("^p"),
                'q' & '\x1F' => try writer.writeAll("^q"),
                'r' & '\x1F' => try writer.writeAll("^r"),
                's' & '\x1F' => try writer.writeAll("^s"),
                't' & '\x1F' => try writer.writeAll("^t"),
                'u' & '\x1F' => try writer.writeAll("^u"),
                'v' & '\x1F' => try writer.writeAll("^v"),
                'w' & '\x1F' => try writer.writeAll("^w"),
                'x' & '\x1F' => try writer.writeAll("^x"),
                'y' & '\x1F' => try writer.writeAll("^y"),
                'z' & '\x1F' => try writer.writeAll("^z"),
                else => try writer.writeByte(c),
            }
        }
        try writer.writeByte('"');
    } else {
        try writer.writeAll("no");
    }
    try line.finish();

    var it = atleg.inputParser(buf[0..read]);
    var i: usize = 1;
    while (it.next()) |in| : (i += 1) {
        line = rc.lineWriter(term.width);
        writer = line.writer();

        try rc.moveCursorTo(5 + (i - 1), 0);

        const msg = " Input events:  ";
        if (i == 1) {
            try rc.setAttribute(.{ .bold = true });
            try writer.writeAll(msg);
            try rc.setAttribute(.{ .bold = false });
        } else {
            try writer.writeByteNTimes(' ', msg.len);
        }

        var mouse: ?struct { x: usize, y: usize } = null;

        try writer.print("{}: ", .{i});
        switch (in.content) {
            .codepoint => |cp| {
                if (cp == 'q') {
                    loop = false;
                    break;
                }
                try writer.print("codepoint: {} ({u}) x{X}", .{ cp, cp, cp });
            },
            .function => |f| try writer.print("F{}", .{f}),
            .mouse => |m| {
                mouse = .{ .x = m.x, .y = m.y };
                try writer.print("mouse {s} {} {}", .{ @tagName(m.button), m.x, m.y });
            },
            else => try writer.writeAll(@tagName(in.content)),
        }
        if (in.mod_alt) try writer.writeAll(" +Alt");
        if (in.mod_ctrl) try writer.writeAll(" +Ctrl");
        if (in.mod_super) try writer.writeAll(" +Super");

        try line.finish();

        if (mouse) |m| {
            try rc.moveCursorTo(m.y, m.x);
            try rc.setAttribute(.{ .bg = .red, .bold = true });
            try rc.buffer.writer().writeByte('X');
        }

        //if (in.eqlDescriptor("escape") or in.eqlDescriptor("q")) {
        //    loop = false;
        //    break;
        //}
    }
}

/// Draws the Example's header (title and description)
pub fn renderExampleHeader(
    rc: *atleg.Term.RenderContext,
    comptime test_name: []const u8,
    comptime test_desc: []const u8,
) !void {
    try rc.moveCursorTo(0, 0);

    var line = rc.lineWriter(term.width);
    var title_attr: atleg.Attribute = .{ .fg = .bright_white, .bg = .red };

    try rc.setAttribute(title_attr);

    // to center the text
    // (len_left / 2) - (("atleg example program: ".len + test_name.len) / 2)
    //  ^ Half total len.  ^ Total amount of space                       ^ Half that.
    try line.padAmount((line.len_left / 2) - ((23 + test_name.len) / 2));

    title_attr.bold = true;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll("atleg");

    title_attr.bold = false;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll(" example program:");

    title_attr.italic = true;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll(" " ++ test_name);

    try line.pad();
    try line.finish();

    try rc.resetAttribute();

    try rc.moveCursorTo(1, 0);
    line = rc.lineWriter(term.width);
    try line.padAmount((line.len_left / 2) - (test_desc.len / 2));
    try line.writer().writeAll(test_desc);
    try line.finish();
    try rc.moveCursorTo(3, 0);
}
