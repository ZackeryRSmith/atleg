const atleg = @import("atleg");

/// Draws the demos header (title and description)
pub fn renderHeader(
    rc: *atleg.Term.RenderContext,
    width: usize,
    comptime test_name: []const u8,
    comptime test_desc: []const u8,
) !void {
    try rc.moveCursorTo(0, 0);

    var line = rc.lineWriter(width);
    var title_attr: atleg.Attribute = .{ .fg = .bright_white, .bg = .red };

    try rc.setAttribute(title_attr);

    // to center the text
    // (len_left / 2) - (("atleg demo program: ".len + test_name.len) / 2)
    //  ^ Half total len.  ^ Total amount of space                    ^ Half that.
    try line.padAmount((line.len_left / 2) - ((23 + test_name.len) / 2));

    title_attr.bold = true;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll("atleg");

    title_attr.bold = false;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll(" demo program:");

    title_attr.italic = true;
    try rc.setAttribute(title_attr);
    try line.writer().writeAll(" " ++ test_name);

    try line.pad();
    try line.finish();

    try rc.resetAttribute();

    try rc.moveCursorTo(1, 0);
    line = rc.lineWriter(width);
    try line.padAmount((line.len_left / 2) - (test_desc.len / 2));
    try line.writer().writeAll(test_desc);
    try line.finish();
    try rc.moveCursorTo(3, 0);
}
