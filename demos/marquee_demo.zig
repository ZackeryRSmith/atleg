const std = @import("std");
const os = std.os;

const atleg = @import("atleg");

var term: atleg.Term = undefined;
var loop: bool = true;

pub fn main() !void {
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
}
