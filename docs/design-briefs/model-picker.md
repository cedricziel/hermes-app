# Design brief: Model picker

Change: the default row that names the server model (#1129) and the desktop popover (roadmap item 6). This brief records what the design pass decided; the code follows it.

## Design (done)

Claude Design canvas "Hermes: Model picker", built on the Hermes App design system: https://claude.ai/artifact/Xrj3DpomeetrBkPq6CSbjm (private; ask its owner for access). 18 artboards, each in light and dark where it says so. Covers two changes to the model picker the composer's model pill opens: the default row that names the server's model (#1129) and the desktop popover (roadmap item 6).

Artboards:

- iPhone bottom sheet, light and dark, 390 x 844 (8): default checked with the default row naming the model; explicit pick checked (with effort pills) while the default row still names the model; long ids cut in the middle (default subtitle and a model row); server reports no default (plain row).
- Android Material sheet, light and dark, 412 x 892 (2): explicit pick, leading radios, round effort pills.
- iPhone at the largest text size, light and dark (2). The canvas draws it by zooming the sheet 1.5x; the app scales text only.
- Mac 1280 x 800, light and dark (2): anchored popover above the composer's model pill, with search (more than 8 models), the default row, one row with the keyboard focus ring, the effort block pinned.
- Mac about 800 x 700 (the default Mac window), light and dark (2): the same popover, no search, so it is a popover at any width, not the bottom sheet the picker opens today.
- Mac, no anchor, light and dark (2): the adaptive dialog (440 pt, title and search on one line), for callers that have no pill (Profiles, Helper models, a job, Bots).

Decisions taken in the design pass:

- **Where it opens.** On macOS, Windows and Linux the picker is an anchored popover from the model pill at any window width; with no anchor it is the 440 pt dialog it already is. iOS and Android are unchanged: a bottom sheet on a phone, the dialog from `isWideLayout` (900 pt) on an iPad or a tablet. The choice is the platform first, the width second (as `showProviderSheet` already does for macOS: never a bottom sheet there). Which callers pass an anchor: the composer pill first (`ComposerModelPill`). The Kanban create screen and task panel open the picker from a row and may pass their row's rectangle later; until then, like Profiles, Helper models, Bots and a job's model field, they keep the dialog.
- **Popover geometry.** 360 pt wide, its leading edge on the pill's, 6 pt above it, no arrow (as the app's other menus). If the room above is under 240 pt it opens below; it is kept 8 pt inside the window. Tallest: the room above the pill minus 16, at most 480 pt. The provider list scrolls; the effort block stays pinned under a hairline. Escape closes it and gives focus back to the pill; a click outside closes it; a pick closes it when there is no effort block to adjust, as the sheet does today.
- **Popover content.** No visible title: the pill is the label (the accessible name stays "Model"). The search field is the first row when there are more than 8 models (the existing rule), at the leading edge, full width. A `note` is shown under it. A caller with its own title ("Compression") has no anchor and gets the dialog, so no title is lost.
- **Rows.** The Mac grouped rows as they are: 40 pt, 44 pt for the default row with its subtitle, so every pointer target is above 28 pt. 13 pt titles, 11 pt muted subtitle. The checkmark stays trailing, as the Mac dialog and every other choice row on Apple platforms draw it; a leading check would shift the text of the checked row and make a scan down the ids ragged.
- **Default row, compact.** Two lines: "Use the profile’s default", then "Uses claude-sonnet-4-5" in the muted subtitle size, one line. Checked while nothing is picked; when a model is picked the row stays and still names the server's model, so the person sees what going back to the default means. Unknown default: the one-line row, no subtitle, no placeholder text.
- **Long ids: cut in the middle.** Model ids share prefixes (`meta-llama/llama-4-…`, `claude-sonnet-4-5-2025…`) and differ at the end, so an end ellipsis hides the part that tells them apart. The model rows and the default row's subtitle are cut in the middle ("meta-llama/llama-4-m…ct-long-context"). In the subtitle the cut falls in the id, because the head half of the sentence is kept, so "Uses" always survives. The full id is the row's accessible label and, on a pointer platform, its hover text. A cut needs a balanced tail (about 40 percent of what fits, at least 8 characters); see "Corrections".
- **Largest text.** No cap. Titles and the subtitle may take two lines (a long id is broken, then cut in the middle after the second line). From a text scale of 1.3 the effort block stops being pinned and scrolls at the end of the list, so it cannot take the room the rows need; the sheet stays at 75 percent of the screen and scrolls. The default row's title wraps instead of cutting ("Use the profile’s / default").
- **Targets.** Effort pills: 44 pt hit area on iOS (36 pt drawn), 48 dp on Android (40 dp drawn), 28 pt on Mac.
- **Keyboard (Mac, Windows, Linux).** Opens with focus on the checked row (the default row when nothing is picked); Up and Down move between rows, Return picks, Tab reaches the search field and the effort pills, Escape closes and returns focus to the pill. The focus ring is drawn on the row the arrow keys reached (artboards "Mac 1280" and "Mac 800").
- **Windows and Linux** get the same popover with the Material rows (leading radio, round effort pills). Not drawn: same width, same placement.

Corrections where the brief did not work:

- The existing `MiddleEllipsisText` keeps a 3-character tail (and an extension) because it was written for file names. For model ids that gives "claude-sonnet-4-5-20…929", which is no better than an end cut. It needs a balanced tail for ids (see the code changes).
- The effort pills are 32 pt (iOS and Android) and 24 pt (Mac) today. Both are under the settled target sizes (44 pt touch, 28 pt Mac). Fixed in this design, to be fixed in code with item 6 (Mac) and with #1129 or its own fix (touch).
- The design-system `ModelPicker` and `GroupedChoiceRow` have no subtitle on the default row and no popover presentation. The canvas draws both from `GroupedSection` and `GroupedChoiceRow` plus plain markup. The design-system row cuts the one-line subtitle at the end; the app's middle cut is described above.

New components needed:

- `AnchoredPopover` (new, `lib/src/widgets/`): a surface drawn above or below an anchor rectangle, with the app's menu surface (surface colour, 1 px border, 10 pt radius, `--h-shadow`). Closest: `AdaptivePopupMenuButton` (a menu of 22 pt rows, which cannot hold a search field, section headers and the effort block).
- Middle-cut text with a balanced tail for model ids: a mode of `MiddleEllipsisText`, not a new widget.

Copy: nothing new beyond the #1129 strings.

| Key                       | en                        | de                             |
| ------------------------- | ------------------------- | ------------------------------ |
| `modelsPickerUseDefault`  | Use the profile’s default | Standard des Profils verwenden |
| `modelsPickerDefaultUses` | Uses {model}              | Verwendet {model}              |

`{model}` is the server's id with control and bidi characters made visible (`safePathText`). "Model", "Search models", "Reasoning effort" and "No models match “…”" are hard-coded English in `model_picker.dart` today, and the effort pills use `effortLabel`; they belong in the ARB files and are not part of this design (listed in the roadmap's "Found along the way").

Checked by rendering, in headless Chromium against the design system's own bundle: the 8 iPhone boards, both Android boards, both largest-text boards, and the light Mac 1280, Mac 800 and dialog boards plus the dark Mac 1280 board. The dark Mac 800 and dark dialog boards run the same file with the theme switched and were not rendered. Not checked: the canvas in the claude.ai viewer, real devices, Flutter's own rendering, and the Windows and Linux look.
