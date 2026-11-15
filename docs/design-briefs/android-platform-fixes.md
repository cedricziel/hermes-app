# Design brief: Android platform fixes

Four small fixes from the Android audit (E3, E11, E5, E7). No openspec change: these are audit fixes to existing behaviour, with no new capability or spec delta. Each lands as its own small PR; this brief is the one design pass behind them.

## Design (done)

Claude Design canvas "Hermes: Android platform fixes", built on the Hermes App design system: https://claude.ai/artifact/66qYkpUfr4Y9fV5bb8ynXZ (private; ask its owner for access). 11 artboards, all Android 412 dp wide, light and dark where it matters.

Boards, by row:

- **E3 and E11, the glyph:** 1 status bar and notification shade, light (before: a solid white square; after: the glyph); 2 the same dark; 3 the glyph on its 24 dp canvas at 6x, 24 dp and 16 dp, the themed icon layer on the 108 dp canvas on a light and a dark tile, and the 0.82 against 0.86 check.
- **E5, notifications denied:** 4 the Notifications dialog with the "Open settings" row, light; 5 dark; 6 German.
- **E7, touch rows:** 7 the chat list as it is today (the real `ThreadSidebar`); 8 the chat list with 48 dp rows, light; 9 dark; 10 message actions before and after, light; 11 dark.

Decisions taken in the design pass:

- **E3 status icon.** A new monochrome glyph, white, as one mask: the chat bubble with the wing cut out of it (the launcher glyph in `design/icon-glyph.svgfrag` with its wing as a hole, filled `evenodd`). The current launcher icon is opaque, so Android fills the whole alpha as a white square. The 24 dp canvas keeps a 2 dp margin (20 dp live area); the wing stays readable at 16 dp. Two places in `lib/src/notifications/local_notification_service.dart` name the small icon and both change: the plugin initialisation at line 276 (`AndroidInitializationSettings('@mipmap/ic_launcher')`) and the per-notification `AndroidNotificationDetails` at line 469 (set its `icon` to the new drawable). Release builds shrink resources with R8, so keep the drawable with a keep rule in `android/app/src/main/res/raw/keep.xml` (`tools:keep`), because the plugin looks it up by name at run time.
- **E3 accent.** None. The theme has no hue (`primary` is near-black or near-white), and the system tints a small icon from its own theme, so no `setColor`. Using a colour the theme does not define would be the only alternative, and the notification would be the one place Hermes has a colour.
- **E11 themed layer.** The same glyph as a single-colour layer, drawn at 0.82 of the 108 dp canvas's glyph scale. The launcher glyph is drawn at 0.86, and its tail tip sits 316 units from the centre of 1024, past the 313 that is the 66 dp safe circle. At 0.82 it is 301. The system supplies the tile and tint colour from the wallpaper, so the layer has no colour of its own.
- **E5 Open settings.** Under the existing warning, a row inside the same "Notify me" section holding a text-style button ("Open settings", with the settings icon), 48 dp tall. Secondary, never filled and never the error colour: it is a way out, not a destructive action. Shown only while Notify me is on and the system refused (the same condition as the warning). Copy: en "Open settings", de "Einstellungen öffnen". The German warning has to fit the two lines the row allows, so its text is shortened to "In den Systemeinstellungen für Hermes aktivieren.". Mechanism: the row opens the app's notification settings page on Android (`ACTION_APP_NOTIFICATION_SETTINGS`). Which plugin or method channel does it is decided in the implementing PR, after a pub.dev check; this brief does not pick one. Localisation: the warning at `lib/src/notifications/notifications_dialog.dart:97` and the Live Activities warning at `:149` are hard-coded English strings today, so there is no German warning yet. The PR adds keys to `lib/l10n/arb/app_en.arb` and `app_de.arb` for the warning, the shortened German warning and the new row's label. It does not reuse `voiceSetupOpenSystemSettings`, which reads "Open iOS Settings" and is iOS-specific.
- **E7 rows.** Android keeps the inline "…" and the long-press menu and gets no swipe (`thread_sidebar.dart:523` is `inlineButton = housekeeping != null && !touch`, with `touch` true only on iOS chrome, so Android already shows the inline button). A swipe on Material fights the drawer edge swipe and predictive back and is not discoverable with TalkBack; iOS keeps swipe and long press. Every Android change here is gated on `TargetPlatform.android`, not on `PlatformChrome.material`, because Material chrome also covers Windows and Linux; the Mac rows stay at 28 and desktop rows are unchanged. Today a row is 32 dp tall and its "…" button 28 dp with a 16 dp glyph; the settings search field is 44 dp on Material. After: rows 48 dp minimum, the "…" target 48 x 48 with the visual glyph unchanged, the search field 48 dp.
- **E7 message actions.** Copy, Try again, Edit prompt and Branch keep their glyph (`iconSize: 16` in a 32 dp box, `lib/src/chat/widgets/message_actions.dart:129`; the first draft said 18) and gain a 48 x 48 target, on Android only. The row also carries Read aloud after Copy and its stop or status control where a reply is read, so five or more actions at 48 dp are 240 dp or more, which still fits 412 dp. Branch shows only where the chat can branch (`onBranch`).
- Status is not colour alone anywhere here: the selected chat row is bold as well as filled, a pin is a glyph, and the warning keeps its icon and words.

Kit reused: `GroupedDialog`, `GroupedSection`, `GroupedSwitchRow` (with its `warning`), `Button` (`variant="text"`), `ThreadSidebar`, `UserMessage`, `AssistantMessage`, `Icon`. Hand-drawn markup only for the glyph sheet, the status bar and shade mock, the 48 dp chat list and the 48 dp action row.

New components needed: none. Widget changes are minimum-height and hit-area changes to `_ThreadRow` / `ThreadActionsButton` (`lib/src/chat/widgets/thread_sidebar.dart`, `thread_actions_menu.dart`), `message_actions.dart` and the Notifications dialog row; the glyph is a drawable under `android/app/src/main/res/` plus a `<monochrome>` entry in `mipmap-anydpi-v26/ic_launcher.xml`.

Corrections after the pass: (a) E5's mechanism and the German string are new, see the E5 item (the warning is not localised today, so "the German warning is shortened" is a new string, not an edit); (b) E7's glyph is 16 dp, not 18; (c) every E7 change is Android-only. The canvas boards are otherwise unchanged.

Where the brief did not work: nothing beyond the corrections above. The first guess for E3 was to use the foreground mipmap with a colour; the pass showed the launcher art cannot be a status icon at all, since it is opaque, and that the safe-zone check fails at 0.86.

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
