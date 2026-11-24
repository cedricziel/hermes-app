# Design brief: Android platform fixes

Four small fixes from the Android audit (E3, E11, E5, E7). No openspec change: these are audit fixes to existing behaviour, with no new capability or spec delta. Each lands as its own small PR; this brief is the one design pass behind them.

## Design (done)

Claude Design canvas "Hermes: Android platform fixes", built on the Hermes App design system: https://claude.ai/artifact/66qYkpUfr4Y9fV5bb8ynXZ (private; ask its owner for access). 11 artboards, all Android 412 dp wide, light and dark where it matters.

Boards, by row:

- **E3 and E11, the glyph:** 1 status bar and notification shade, light (before: a solid white square; after: the glyph); 2 the same dark; 3 the glyph on its 24 dp canvas at 6x, 24 dp and 16 dp, the themed icon layer on the 108 dp canvas on a light and a dark tile, and the 0.82 against 0.86 check.
- **E5, notifications denied:** 4 the Notifications dialog with the "Open settings" row, light; 5 dark; 6 German.
- **E7, touch rows:** 7 the chat list as it is today (the real `ThreadSidebar`); 8 the chat list with 48 dp rows, light; 9 dark; 10 message actions before and after, light; 11 dark.

Decisions taken in the design pass:

- **E3 status icon.** A new monochrome glyph, white, as one mask: the chat bubble with the wing cut out of it (the launcher glyph in `design/icon-glyph.svgfrag` with its wing as a hole, filled `evenodd`). The current launcher icon is opaque, so Android fills the whole alpha as a white square. The 24 dp canvas keeps a 2 dp margin (20 dp live area); the wing stays readable at 16 dp.
- **E3 accent.** None. The theme has no hue (`primary` is near-black or near-white), and the system tints a small icon from its own theme, so no `setColor`. Using a colour the theme does not define would be the only alternative, and the notification would be the one place Hermes has a colour.
- **E11 themed layer.** The same glyph as a single-colour layer, drawn at 0.82 of the 108 dp canvas's glyph scale. The launcher glyph is drawn at 0.86, and its tail tip sits 316 units from the centre of 1024, past the 313 that is the 66 dp safe circle. At 0.82 it is 301. The system supplies the tile and tint colour from the wallpaper, so the layer has no colour of its own.
- **E5 Open settings.** Under the existing warning, a row inside the same "Notify me" section holding a text-style button ("Open settings", with the settings icon), 48 dp tall. Secondary, never filled and never the error colour: it is a way out, not a destructive action. Shown only while Notify me is on and the system refused (the same condition as the warning). Copy: en "Open settings", de "Einstellungen öffnen". The German warning has to fit the two lines the row allows, so its text is shortened to "In den Systemeinstellungen für Hermes aktivieren.".
- **E7 rows.** Android keeps the inline "…" and the long-press menu and gets no swipe (the code already has `inlineButton = !touch`). A swipe on Material fights the drawer edge swipe and predictive back and is not discoverable with TalkBack; iOS keeps swipe and long press. Today a row is 32 dp tall and its "…" button 28 dp with a 16 dp glyph; the settings search field is 44 dp on Material. After: rows 48 dp minimum, the "…" target 48 x 48 with the visual glyph unchanged, the search field 48 dp.
- **E7 message actions.** Copy, Try again, Edit prompt and Branch keep their 18 dp glyph in a 32 dp circle and gain a 48 x 48 target. Four targets are 192 dp wide, which fits 412 dp. Branch shows only where the chat can branch (`onBranch`).
- Status is not colour alone anywhere here: the selected chat row is bold as well as filled, a pin is a glyph, and the warning keeps its icon and words.

Kit reused: `GroupedDialog`, `GroupedSection`, `GroupedSwitchRow` (with its `warning`), `Button` (`variant="text"`), `ThreadSidebar`, `UserMessage`, `AssistantMessage`, `Icon`. Hand-drawn markup only for the glyph sheet, the status bar and shade mock, the 48 dp chat list and the 48 dp action row.

New components needed: none. Widget changes are minimum-height and hit-area changes to `_ThreadRow` / `ThreadActionsButton` (`lib/src/chat/widgets/thread_sidebar.dart`, `thread_actions_menu.dart`), `message_actions.dart` and the Notifications dialog row; the glyph is a drawable under `android/app/src/main/res/` plus a `<monochrome>` entry in `mipmap-anydpi-v26/ic_launcher.xml`.

Where the brief did not work: nothing needed to change. The first guess for E3 was to use the foreground mipmap with a colour; the pass showed the launcher art cannot be a status icon at all, since it is opaque, and that the safe-zone check fails at 0.86.

Not checked: the real status bar and shade (the mock is a drawn approximation), a real themed-icon launcher, TalkBack, and the largest text size on the dialog (the row uses a minimum height so it can grow).

## Who and why

People on Android phones. A notification from Hermes should be recognisable in the status bar; a device with themed icons should not show Hermes as the one odd colour tile; a person who turned notifications off needs a way back to the system switch from the dialog that tells them so; and every tap target should meet the 48 dp rule the settled design rules set.

## Per item, before and after

| Item                 | Before                                                                                    | After                                                                      |
| -------------------- | ----------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| E3 status icon       | The opaque launcher icon is the small icon, shown as a white square.                      | The white glyph mask, no accent.                                           |
| E11 themed icon      | No monochrome layer; Android 13 themed icons fall back to the unthemed tile.              | A monochrome layer with the same glyph at 0.82 scale inside the safe zone. |
| E5 permission denied | A warning line "Turn on notifications for Hermes in system settings." and nothing to tap. | The same warning and an "Open settings" text row under it.                 |
| E7 chat list         | 32 dp rows, 28 dp "…" button, 44 dp search field.                                         | 48 dp rows, 48 dp "…" target, 48 dp search field.                          |
| E7 message actions   | 32 dp buttons.                                                                            | 48 dp targets, same 32 dp look, Branch included where it applies.          |

## Accessibility

- Every icon-only button keeps its accessible name (Copy, Try again, Edit prompt, Branch, More). A larger hit area changes no label.
- The "Open settings" row is a real button with its text as its name. Its label is localised in en and de.
- Targets are at least 48 dp on Android, per the settled rule; the chat row's hit area is the whole row.
- Colour: the warning keeps an icon and words; the glyph has no colour of its own.
- Largest text size: rows and the dialog row use a minimum height, so they grow.
