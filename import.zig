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

pub const version = "0.1.0";

pub const sequences = @import("src/sequences.zig");
pub const Attribute = @import("src/Attribute.zig");

pub const Term = @import("src/Term.zig");

pub const Input = @import("src/input.zig").Input;
pub const inputParser = @import("src/input.zig").inputParser;
pub const InputContent = @import("src/input.zig").InputContent;
