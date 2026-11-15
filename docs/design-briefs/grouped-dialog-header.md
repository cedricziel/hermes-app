# Grouped dialog header at large text

Follow-up to the iPhone/iPad platform fixes record (`ios-ipad-platform-fixes.md`, D2). Applies to the iOS and macOS header of `GroupedDialog`.

## Decisions

- D2: when the title and Done do not fit on one line, Done gets its own 44 pt row at the end and the title wraps under it. The header grows. At the default size nothing changes.
- Rows win: the header may grow only while the rows keep at least the height they have on main for the same viewport, keyboard and text scale. Whenever growing would give the rows less, the header falls back to the one-line form (52 pt on iOS, 44 on macOS, or Done's own height when taller, so Done is always whole) and the title is cut by an ellipsis.
- A cut title is never lost: the full text is the heading's semantics label and a long-press or hover tooltip (excluded from semantics, so it is not read twice).
- The header never takes more than 40% of the room the dialog really gets (keyboard included); past that the title scrolls, with a fade at the bottom edge.
- Reading order is title, Done, rows, whatever the layout.

## Known limits

- A landscape keyboard at the largest text leaves less room than the fixed footer needs, with or without this header; that is unchanged from before.
