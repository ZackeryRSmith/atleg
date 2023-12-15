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

const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const unicode = std.unicode;

const Input = @import("input.zig").Input;

/// A parser to convert human readable/writable utf8 plain-text input
/// descriptors into Input structs.
/// Examples:
///   "M-x" -> Input{ .content = .{ .codepoint = 'x' }, .mod_alt = true }
///   "C-a" -> Input{ .content = .{ .codepoint = 'a' }, .mod_ctrl = true }
pub fn parseInputDescriptor(str: []const u8) !Input {
    var ret = Input{ .content = .unknown };

    var buf: []const u8 = str;
    while (true) {
        if (buf.len == 0) {
            return error.UnknownBadDescriptor;
        } else if (mem.startsWith(u8, buf, "M-")) {
            try addMod(&ret, .alt);
            buf = buf["M-".len..];
        } else if (mem.startsWith(u8, buf, "A-")) {
            try addMod(&ret, .alt);
            buf = buf["A-".len..];
        } else if (mem.startsWith(u8, buf, "Alt-")) {
            try addMod(&ret, .alt);
            buf = buf["Alt-".len..];
        } else if (mem.startsWith(u8, buf, "C-")) {
            try addMod(&ret, .control);
            buf = buf["C-".len..];
        } else if (mem.startsWith(u8, buf, "Ctrl-")) {
            try addMod(&ret, .control);
            buf = buf["Ctrl-".len..];
        } else if (mem.startsWith(u8, buf, "S-")) {
            try addMod(&ret, .super);
            buf = buf["S-".len..];
        } else if (mem.startsWith(u8, buf, "Super-")) {
            buf = buf["Super-".len..];
            try addMod(&ret, .super);
        } else if (mem.eql(u8, buf, "escape")) {
            ret.content = .escape;
            break;
        } else if (mem.eql(u8, buf, "arrow-up")) {
            ret.content = .arrow_up;
            break;
        } else if (mem.eql(u8, buf, "arrow-down")) {
            ret.content = .arrow_down;
            break;
        } else if (mem.eql(u8, buf, "arrow-left")) {
            ret.content = .arrow_left;
            break;
        } else if (mem.eql(u8, buf, "arrow-right")) {
            ret.content = .arrow_right;
            break;
        } else if (mem.eql(u8, buf, "end")) {
            ret.content = .end;
            break;
        } else if (mem.eql(u8, buf, "home")) {
            ret.content = .home;
            break;
        } else if (mem.eql(u8, buf, "page-up")) {
            ret.content = .page_up;
            break;
        } else if (mem.eql(u8, buf, "page-down")) {
            ret.content = .page_down;
            break;
        } else if (mem.eql(u8, buf, "delete")) {
            ret.content = .delete;
            break;
        } else if (mem.eql(u8, buf, "insert")) {
            ret.content = .insert;
            break;
        } else if (mem.eql(u8, buf, "space")) {
            ret.content = .{ .codepoint = ' ' };
            break;
        } else if (mem.eql(u8, buf, "backspace")) {
            ret.content = .{ .codepoint = 127 };
            break;
        } else if (mem.eql(u8, buf, "enter") or mem.eql(u8, buf, "return")) {
            ret.content = .{ .codepoint = '\n' };
            break;
        } else if (mem.eql(u8, buf, "print")) {
            ret.content = .print;
            break;
        } else if (mem.eql(u8, buf, "scroll-lock")) {
            ret.content = .scroll_lock;
            break;
        } else if (mem.eql(u8, buf, "pause")) {
            ret.content = .pause;
            break;
        } else if (mem.eql(u8, buf, "begin")) {
            ret.content = .begin;
            break;
        } else if (buf[0] == 'F') {
            ret.content = .{ .function = fmt.parseInt(u8, buf[1..], 10) catch return error.UnknownBadDescriptor };
            break;
        } else {
            const len = unicode.utf8ByteSequenceLength(buf[0]) catch return error.UnknownBadDescriptor;
            if (buf.len != len) return error.UnknownBadDescriptor;
            ret.content = .{ .codepoint = unicode.utf8Decode(buf) catch return error.UnknownBadDescriptor };
            break;
        }
    }

    if (ret.content == .unknown) {
        return error.UnknownBadDescriptor;
    } else {
        return ret;
    }
}

const Mod = enum { alt, control, super };

fn addMod(in: *Input, mod: Mod) !void {
    switch (mod) {
        .alt => {
            if (in.mod_alt) return error.DuplicateMod;
            in.mod_alt = true;
        },
        .control => {
            if (in.mod_ctrl) return error.DuplicateMod;
            in.mod_ctrl = true;
        },
        .super => {
            if (in.mod_super) return error.DuplicateMod;
            in.mod_super = true;
        },
    }
}

test "input descriptor parser: good input" {
    const testing = std.testing;
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'a' } },
        try parseInputDescriptor("a"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'b' }, .mod_ctrl = true },
        try parseInputDescriptor("C-b"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'c' }, .mod_ctrl = true },
        try parseInputDescriptor("Ctrl-c"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'd' }, .mod_alt = true },
        try parseInputDescriptor("M-d"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'D' }, .mod_alt = true },
        try parseInputDescriptor("A-D"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'e' }, .mod_alt = true },
        try parseInputDescriptor("Alt-e"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'f' }, .mod_ctrl = true, .mod_alt = true },
        try parseInputDescriptor("C-M-f"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'g' }, .mod_ctrl = true, .mod_alt = true },
        try parseInputDescriptor("M-C-g"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 'h' }, .mod_ctrl = true, .mod_alt = true },
        try parseInputDescriptor("M-Ctrl-h"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .function = 1 } },
        try parseInputDescriptor("F1"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .function = 10 }, .mod_alt = true },
        try parseInputDescriptor("M-F10"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = ' ' } },
        try parseInputDescriptor("space"),
    );
    try testing.expectEqual(
        Input{ .content = .escape },
        try parseInputDescriptor("escape"),
    );
    try testing.expectEqual(
        Input{ .content = .escape, .mod_super = true },
        try parseInputDescriptor("S-escape"),
    );
    try testing.expectEqual(
        Input{ .content = .escape, .mod_super = true, .mod_alt = true },
        try parseInputDescriptor("M-S-escape"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = '\n' } },
        try parseInputDescriptor("return"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = '\n' }, .mod_super = true },
        try parseInputDescriptor("S-return"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = 127 } },
        try parseInputDescriptor("backspace"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = '\xB5' } },
        try parseInputDescriptor("µ"),
    );
    try testing.expectEqual(
        Input{ .content = .{ .codepoint = '\xB5' }, .mod_ctrl = true },
        try parseInputDescriptor("Ctrl-µ"),
    );
}

test "input descriptor parser: bad input" {
    const testing = std.testing;
    try testing.expectError(error.DuplicateMod, parseInputDescriptor("M-M-escape"));
    try testing.expectError(error.DuplicateMod, parseInputDescriptor("M-Alt-escape"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("M-"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("M-S-"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("aa"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("a-a"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("escap"));
    try testing.expectError(error.UnknownBadDescriptor, parseInputDescriptor("\xB5"));
}
