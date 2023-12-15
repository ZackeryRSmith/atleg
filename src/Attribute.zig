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

// TODO: implement legacy color use for rgb colors like (0, 0, 0), (255, 0, 0), etc...
//       (this is already implemented for 256 colors)

const Self = @This();

pub const Color = union(enum) {
    none,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    bright_black,
    bright_red,
    bright_green,
    bright_yellow,
    bright_blue,
    bright_magenta,
    bright_cyan,
    bright_white,
    // NOTE: atleg will convert 256 & rgb colors to legacy color sequences if given the chance
    //       like an rgb of (255, 0, 0) gets converted to a legacy red
    @"256": u8,
    rgb: [3]u8,
};

fg: Color = .{ .@"256" = 15 },
bg: Color = .none,

bold: bool = false,
dimmed: bool = false,
italic: bool = false,
underline: bool = false,
blinking: bool = false,
reverse: bool = false,
hidden: bool = false,
overline: bool = false,
strikethrough: bool = false,

/// Check if 2 colors are equal
pub fn eql(self: Self, other: Self) bool {
    inline for (@typeInfo(Self).Struct.fields) |field| {
        if (@field(self, field.name) != @field(other, field.name)) return false;
    }
    return true;
}

/// Applies ANSI escape codes for text styling and writes to the specified `writer`.
///
/// For ANSI escape codes reference, see: https://en.wikipedia.org/wiki/ANSI_escape_code
pub fn dump(self: Self, writer: anytype) !void {
    // TODO: minimize this code, please...
    try writer.writeAll("\x1B[0"); // reset all
    if (self.bold) try writer.writeAll(";1");
    if (self.dimmed) try writer.writeAll(";2");
    if (self.italic) try writer.writeAll(";3");
    if (self.underline) try writer.writeAll(";4");
    if (self.blinking) try writer.writeAll(";5");
    if (self.reverse) try writer.writeAll(";7");
    if (self.hidden) try writer.writeAll(";8");
    if (self.overline) try writer.writeAll(";53");
    if (self.strikethrough) try writer.writeAll(";9");
    switch (self.fg) {
        .none => {},
        .black => try writer.writeAll(";30"),
        .red => try writer.writeAll(";31"),
        .green => try writer.writeAll(";32"),
        .yellow => try writer.writeAll(";33"),
        .blue => try writer.writeAll(";34"),
        .magenta => try writer.writeAll(";35"),
        .cyan => try writer.writeAll(";36"),
        .white => try writer.writeAll(";37"),
        .bright_black => try writer.writeAll(";90"),
        .bright_red => try writer.writeAll(";91"),
        .bright_green => try writer.writeAll(";92"),
        .bright_yellow => try writer.writeAll(";93"),
        .bright_blue => try writer.writeAll(";94"),
        .bright_magenta => try writer.writeAll(";95"),
        .bright_cyan => try writer.writeAll(";96"),
        .bright_white => try writer.writeAll(";97"),
        .@"256" => {
            switch (self.fg.@"256") {
                // special cases
                0 => try writer.writeAll(";30"), // black
                1 => try writer.writeAll(";31"), // red
                2 => try writer.writeAll(";32"), // green
                3 => try writer.writeAll(";33"), // yellow
                4 => try writer.writeAll(";34"), // blue
                5 => try writer.writeAll(";35"), // magenta
                6 => try writer.writeAll(";36"), // cyan
                7 => try writer.writeAll(";37"), // white
                8 => try writer.writeAll(";90"), // bright black
                9 => try writer.writeAll(";91"), // bright red
                10 => try writer.writeAll(";92"), // bright green
                11 => try writer.writeAll(";93"), // bright yellow
                12 => try writer.writeAll(";94"), // bright blue
                13 => try writer.writeAll(";95"), // bright magenta
                14 => try writer.writeAll(";96"), // bright cyan
                15 => try writer.writeAll(";97"), // bright white

                else => {
                    try writer.writeAll(";38;5"); // start fg 256 color
                    try writer.print(";{d}", .{self.fg.@"256"});
                },
            }
        },
        .rgb => {
            try writer.writeAll(";38;2"); // start fg rgb color
            try writer.print(";{d};{d};{d}", .{
                self.fg.rgb[0],
                self.fg.rgb[1],
                self.fg.rgb[2],
            });
        },
    }
    switch (self.bg) {
        .none => {},
        .black => try writer.writeAll(";40"),
        .red => try writer.writeAll(";41"),
        .green => try writer.writeAll(";42"),
        .yellow => try writer.writeAll(";43"),
        .blue => try writer.writeAll(";44"),
        .magenta => try writer.writeAll(";45"),
        .cyan => try writer.writeAll(";46"),
        .white => try writer.writeAll(";74"),
        .bright_black => try writer.writeAll(";100"),
        .bright_red => try writer.writeAll(";101"),
        .bright_green => try writer.writeAll(";102"),
        .bright_yellow => try writer.writeAll(";103"),
        .bright_blue => try writer.writeAll(";104"),
        .bright_magenta => try writer.writeAll(";105"),
        .bright_cyan => try writer.writeAll(";106"),
        .bright_white => try writer.writeAll(";107"),
        .@"256" => {
            switch (self.bg.@"256") {
                // special cases
                0 => try writer.writeAll(";40"), // black
                1 => try writer.writeAll(";41"), // red
                2 => try writer.writeAll(";42"), // green
                3 => try writer.writeAll(";43"), // yellow
                4 => try writer.writeAll(";44"), // blue
                5 => try writer.writeAll(";45"), // magenta
                6 => try writer.writeAll(";46"), // cyan
                7 => try writer.writeAll(";74"), // white
                8 => try writer.writeAll(";100"), // bright black
                9 => try writer.writeAll(";101"), // bright red
                10 => try writer.writeAll(";102"), // bright green
                11 => try writer.writeAll(";103"), // bright yellow
                12 => try writer.writeAll(";104"), // bright blue
                13 => try writer.writeAll(";105"), // bright magenta
                14 => try writer.writeAll(";106"), // bright cyan
                15 => try writer.writeAll(";107"), // bright white

                else => {
                    try writer.writeAll(";48;5"); // start bg 256 color
                    try writer.print(";{d}", .{self.bg.@"256"});
                },
            }
        },
        .rgb => {
            try writer.writeAll(";48;2"); // start bg rgb color
            try writer.print(";{d};{d};{d}", .{
                self.bg.rgb[0],
                self.bg.rgb[1],
                self.bg.rgb[2],
            });
        },
    }
    try writer.writeAll("m");
}

// messing around with tests

test "Color cube, 6x6x6" {
    const std = @import("std");
    const print = std.debug.print;
    const stdout = std.io.getStdOut().writer();

    // formatting issue with zig tests
    print("\n", .{});

    // TODO: need a function for resetting all color :P
    var reset_attrib: Self = Self{};
    reset_attrib.fg = Self.Color.none;
    reset_attrib.bg = Self.Color.none;

    for (0..6) |r| {
        for (0..6) |g| {
            for (0..6) |b| {
                // calculate normalized RGB values
                const norm_r: u8 = @truncate((r * 255) / 5);
                const norm_g: u8 = @truncate((g * 255) / 5);
                const norm_b: u8 = @truncate((b * 255) / 5);

                var attrib: Self = Self{};
                attrib.bg = Self.Color{ .rgb = .{ norm_r, norm_g, norm_b } };

                try attrib.dump(stdout);
                print("  ", .{});
            }
            try Self.dump(reset_attrib, stdout);
            print(" ", .{});
        }
        print("\n", .{});
    }
}

test "Grayscale ramp" {
    const std = @import("std");
    const print = std.debug.print;
    const stdout = std.io.getStdOut().writer();

    // formatting issue with zig tests
    print("\n", .{});

    // TODO: need a function for resetting all color :P
    var reset_attrib: Self = Self{};
    reset_attrib.fg = Self.Color.none;
    reset_attrib.bg = Self.Color.none;

    for (0..24) |i| {
        const gray_value: u8 = @truncate(i * 10 + 8);

        var attrib: Self = Self{};
        attrib.bg = Self.Color{ .rgb = .{ gray_value, gray_value, gray_value } };

        try attrib.dump(stdout);
        print("  ", .{});
    }

    // cleanup
    try reset_attrib.dump(stdout);
    print("\n", .{});
}
