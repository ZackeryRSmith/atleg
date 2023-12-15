const std = @import("std");
const os = std.os;

const atleg = @import("atleg");
const renderHeader = @import("header.zig").renderHeader;

var term: atleg.Term = undefined;
var loop: bool = true;

const sentance = "Hello, World! This is a TypeRacer clone in the terminal! This isn't the most fancy thing ever. It's just designed to show off the stuff you can do using atleg. Try it out sometime!";
var word_count: usize = 0;
var words_done: usize = 0;
var cursor: usize = 0;

var spos: usize = 0;

// attributes
const before_text_attr: atleg.Attribute = .{ .fg = .bright_black };
var on_char_attr: atleg.Attribute = .{ .fg = .red };
const after_text_attr: atleg.Attribute = .{ .fg = .none };

pub fn main() !void {
    try count_words();

    try term.init(.{});
    defer term.deinit();

    var fds: [1]os.pollfd = undefined;
    fds[0] = .{
        .fd = term.tty.?,
        .events = os.POLL.IN,
        .revents = undefined,
    };

    try term.uncook(.{});

    try term.fetchSize();

    try render();

    var buf: [16]u8 = undefined;
    while (loop) {
        _ = try os.poll(&fds, -1);

        const read = try term.readInput(&buf);

        if (read == 0) continue;

        var it = atleg.inputParser(buf[0..read]);
        while (it.next()) |in| {
            if (in.eqlDescriptor("escape")) {
                loop = false;
                break;
            }

            switch (in.content) {
                .codepoint => |cp| {
                    if (cursor < sentance.len and cp == sentance[cursor]) {
                        if (cursor == sentance.len - 1) {
                            loop = false;
                            break;
                        }

                        if (cursor >= (term.width / 2)) spos += 1;

                        if (sentance[cursor] == ' ') words_done += 1;

                        cursor += 1;
                    }
                },
                else => continue,
            }
        }

        try render();
    }
}

fn render() !void {
    var rc = try term.getRenderContext();
    defer rc.done() catch {};

    try rc.clear();

    try static_render(&rc);

    // render the meat and potatos
    try rc.moveCursorTo((term.height / 2) - 1, 0); // inside lines

    var line = rc.lineWriter(term.width);
    try line.padAmount((term.width / 2) - (cursor - spos)); // space before text
    try rc.setAttribute(before_text_attr);
    try line.writer().writeAll(sentance[spos..cursor]); // text before char
    if (sentance[cursor] != ' ') {
        try rc.setAttribute(on_char_attr);
    } else {
        var modified: atleg.Attribute = on_char_attr;
        modified.reverse = true;
        try rc.setAttribute(modified);
    }
    try line.writer().writeByte(sentance[cursor]); // on char
    try rc.setAttribute(after_text_attr);
    try line.writer().writeAll(sentance[(cursor + 1)..]); // text after char
    try line.finish();

    // render stats
    try rc.moveCursorTo(term.height - 5, 0);
    line = rc.lineWriter(term.width);
    try line.writer().print("cursor: {}", .{cursor});
    try rc.moveCursorByLine(1);
    try line.writer().print("spos: {}", .{spos});
    try rc.moveCursorByLine(1);
    try line.writer().print("word_count: {}", .{word_count});
    try rc.moveCursorByLine(1);
    try line.writer().print("words_done: {}", .{words_done});
    try rc.moveCursorByLine(1);
    try line.writer().print("wpm: {} (NOT IMPLEMENTED)", .{0});
    try line.finish();
}

// TODO: this comment is a liar because I haven't added a few funny functions yet :)
/// Render text which shouldn't change during runtime (unless screen size changes)
fn static_render(rc: *atleg.Term.RenderContext) !void {
    try renderHeader(rc, term.width, "tertype", "a poor TypeRacer clone within the terminal; Esc to exit");

    try rc.moveCursorTo((term.height / 2) - 2, 0);

    // line 1
    var line = rc.lineWriter(term.width);
    try line.padAmountByte(line.len_left / 2, '-');
    try line.writer().writeByte('|');
    try line.padByte('-');
    try line.finish();

    try rc.moveCursorByLine(2);

    // line 2
    line = rc.lineWriter(term.width);
    try line.padAmountByte(line.len_left / 2, '-');
    try line.writer().writeByte('|');
    try line.padByte('-');
    try line.finish();
}

fn count_words() !void {
    for (sentance) |c| {
        if (c == ' ') {
            word_count += 1;
        }
    }
    word_count += 1; // for the last word
}
