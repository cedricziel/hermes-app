# Design brief: Cupertino sheets with detents

Openspec change: `openspec/changes/cupertino-detent-sheets` (audit item D6, roadmap F.231). The design pass ran (below). This brief says what to decide and where; the facts and the recommendation are in that change's `design.md`. Kanban's task sheet is the existing example of the look.

## Design pass

Canvas: https://claude.ai/artifact/LDMhPqNsZKuVda2BaFUTex (private; ask its owner for access). Row 3, five artboards at 393 x 852 and 852 x 393. Each recommendation awaits the owner's decision; the alternative is named after it.

- **fit, restore confirmation:** opens at its content's height. Recommended: the grabber on every iOS sheet, and Kanban's 12 pt corners with the overlay hairline (alternatives: grabber only where a sheet resizes; a larger iOS radius). Cancel is the default and Restore files is an outlined destructive button, never filled; both 50 pt tall.
- **mediumLarge at medium, model picker:** half of the height under the top safe inset, as Kanban (recommended; alternative: another fraction). The list scrolls inside, Reasoning effort stays pinned at the sheet's bottom, and Done (44 pt) stays in the content.
- **mediumLarge at large:** the full height under the safe inset over a scrim, the presenter not scaled (recommended). Alternative: a native page sheet with the presenter peeking, which would move `large` to `showCupertinoSheet`.
- **large, provider form:** opens at large only, with Cancel and Connect in its own bar row; a swipe or barrier tap goes through `PopScope`, so a busy form snaps back. The key field follows the secret-field rule.
- **Landscape 852 x 393:** under 500 pt of height every sheet is large, at most 640 pt wide and centred, with the grabber.
- **Not drawn, decided:** no sheet changes profile from the proposal's table.

New components needed: the iOS sheet container (rounded top, hairline, scrim, detent height) and the grabber (36 x 5 in a 17 pt band, an adjustable control on `mediumLarge`), both plain markup on the canvas; the closest existing piece is `KanbanDetentSheet`. The design system's `Button` is 40 px tall on Apple touch, under the 44 pt rule; the canvas raises sheet actions to 50 pt, and the build must too.

## Proposed:

On iPhone, every sheet opened through `showAdaptiveSheet` gets rounded top corners, a grabber and one of three detents: `fit` for confirmations and short menus, `mediumLarge` for lists and details that grow, `large` for flows with text fields. iPad, Mac and wide layouts keep their dialog. Android keeps its Material sheet.

### Who and why

People on an iPhone, who expect to drag a sheet to full height, and to dismiss it by swiping down, as they do in every other iOS app and in the app's own Kanban task.

### Kit to reuse

`showAdaptiveSheet`, `KanbanDetentSheet` (the grabber and corner treatment), `hermesOverlayEdge`, the existing sheet contents (`McpCommandReview`, `ToolsetModelSheet`, `FileSizeSheet`, the restore and compress confirmations, the provider forms). No sheet content changes.

### Screens and widths for the canvas

| Screen                              | Platform                          | Width                  | States                                             |
| ----------------------------------- | --------------------------------- | ---------------------- | -------------------------------------------------- |
| `fit`: restore confirmation         | iPhone                            | 393 pt, light and dark | rest; at 320 x 568 with scale 2.0 (grows, scrolls) |
| `fit`: attach menu                  | iPhone                            | 393 pt                 | rest                                               |
| `fit`: compress with its text field | iPhone                            | 393 pt                 | keyboard up (moves to large)                       |
| `mediumLarge`: model picker         | iPhone                            | 393 pt                 | medium, dragged to large, with search focused      |
| `mediumLarge`: folder picker        | iPhone                            | 393 pt                 | medium and large                                   |
| `mediumLarge`: skill job status     | iPhone                            | 393 pt                 | medium and large                                   |
| `large`: provider connect form      | iPhone                            | 393 pt                 | at rest and with the keyboard                      |
| `large`: MCP install                | iPhone                            | 393 pt                 | busy state while installing                        |
| Any `mediumLarge` sheet             | iPhone                            | 852 x 393 landscape    | full height only                                   |
| Kanban task                         | iPhone                            | 393 pt                 | unchanged look, now from the shared sheet          |
| Any sheet, for contrast             | iPad 1024 pt, Mac, Android 412 dp |                        | dialog; dialog; Material sheet with its handle     |

### Decisions to take

- Is the grabber shown on `fit` sheets (one look for every iOS sheet) or only where a sheet can be resized?
- Medium height: half of the height below the safe inset (Kanban), or a different fraction.
- The gap at the top of a large sheet: the full safe height, or an iOS-style gap with the presenter peeking.
- Corner radius and edge: Kanban's 12 pt with the overlay hairline, or a larger iOS radius.
- Whether a scrim and the presenter scaling of a native page sheet are wanted for `large` (this would move the `large` profile to `showCupertinoSheet`).
- Which sheets, if any, belong in a different profile than the proposal's table gives them. The table is in the proposal.

### Accessibility

The grabber has an accessible name and, on `mediumLarge` sheets, increase and decrease actions. Every sheet keeps a Close, Cancel or Done of at least 44 pt in its content. A sheet never clips at large text: it opens taller and scrolls. VoiceOver's escape gesture dismisses a sheet through the pop guard, so a busy sheet stays open.

### Differences by platform

iOS compact only. iPad regular width and macOS keep the dialog. Android keeps `showModalBottomSheet` with its handle and height cap. Windows and Linux keep what they have.
