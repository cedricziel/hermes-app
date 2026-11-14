---
name: design-pass
description: Use before any new screen or redesign in hermes-app, to run the Claude Design pass on the Hermes App design system and record its decisions in the change's design.md and docs/design-briefs/ before Widgetbook work starts.
---

# Design pass

A new screen or a redesign gets a design pass before the catalog
(`component-catalog` skill) and before any screen code. The pass is a Claude
Design canvas built on the "Hermes App" design system. Its decisions are
written into the repo, because later agents cannot open the canvas.

Server care is the worked example: `openspec/changes/server-care/design.md`
holds the server facts and state machines, and `docs/design-briefs/server-care.md`
holds the design brief and the decisions of the pass.

Both links below are private artifacts of the repo owner. Ask for access if
they do not open.

- Design type: https://claude.ai/artifact/QKN21svewxgyPb6SYRqWnd
- "Hermes App" design system: https://claude.ai/artifact/8wJ2qmYz2fnmpHYGakH9mM

## Order of work

1. The change exists in `openspec/changes/<change>/` with a `design.md` (facts,
   states, errors).
2. Write the brief: `docs/design-briefs/<change>.md`. Who uses it and why,
   the shared kit to reuse, navigation, each screen's job, accessibility,
   differences by platform.
3. Run the design pass (below). Bring the brief in line with the canvas.
4. Record the decisions (see "Record it").
5. Build in the catalog, then wire the screen.

## Run the pass

Work in your scratchpad directory (the folder the Artifact `read` saves into
by default); call it `S`.

### 1. Create the canvas

1. Call the Artifact tool with `action: "quickstart"`, `intent: "design"`,
   `design_systems: false`. It names the Design type.
2. Read the design system: Artifact `read` of the design system URL with
   `path: "project/README.md"`. Component docs are at
   `project/components/<group>/<Name>/<Name>.prompt.md`. Some are under
   `project/docs/components/...` (SettingsScaffold, GroupedRow, GroupedSection,
   GroupedListView, GroupedSwitchRow, SettingsSearchField). Use `paths: [...]` to
   read several in one call. `project/tokens.json` is not served.
3. Create the canvas: Artifact with `type_url` set to the Design type link,
   `title: "Hermes: <feature>"`, `auto_open: "after_first_write"` and no files.
   Use the returned `url` from then on.
4. Write `S/canvas/project/canvas.json` first. It holds `v: 3`,
   `createdOnFiles: {v: 1, at: <now>}`, `title`, `launch: {view: "canvas"}`,
   `pages: []`, `boards`, `order`, `notes` and
   `designSystems: [{"title": "Hermes App", "namespace": "hermesui", "artifact": "<design system URL>", "version": "1792838541-f89d", "copiedAt": <now>}]`
   (use the version an existing canvas or the design system's listing shows;
   this value was current when written).
   - `boards` has one entry per file: `{x, y, w, h, title}`. Sizes: phone 390 x
     844 or taller, iPad 1180 x 820, Mac 1280 x 800, Android 412 wide. Leave 80
     px between frames and about 300 px between rows, for titles and notes.
   - A row title is `{"kind": "title1", "x", "y": rowY - 300, "text", "maxW"}`.
   - The one-line decision under each artboard is a sticky:
     `{"x", "y": boardY + h + 24, "w": 390, "fill": "gray" | "orange", "size": "s", "text"}`.
     Valid fills are gray, red, orange, green, teal, blue, purple and pink.
     Yellow breaks the file.
5. First publish, in one call: `canvas.json`, `Main.dc.html` and the design
   system install.

```
Artifact {url, root: "S/canvas", file_path: "S/canvas/project/canvas.json", files: {
 "project/Main.dc.html": "project/Main.dc.html",
 "project/ds/hermesui/styles.css": {"artifact": "<design system URL>", "path": "project/styles.css"},
 "project/ds/hermesui/fonts/fonts.css": {"artifact": "<same>", "path": "project/fonts/fonts.css"},
 "project/ds/hermesui/_ds_bundle.css": {"artifact": "<same>", "path": "project/_ds_bundle.css"},
 "project/ds/hermesui/_ds_bundle.js": {"artifact": "<same>", "path": "project/_ds_bundle.js"},
 "project/ds/hermesui/fonts/CupertinoIcons.ttf": {"artifact": "<same>", "path": "project/fonts/CupertinoIcons.ttf"}}}
```

### 2. Artboards

Each artboard is `S/canvas/project/<Name>.dc.html`. A formatter re-indents
files after every Write; that is harmless. A minimal working artboard:

```text
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Server, healthy</title>
<script src="./support.js"></script>
<link rel="stylesheet" href="ds/hermesui/styles.css">
<script src="ds/hermesui/_ds_bundle.js"></script></head><body><x-dc>
<helmet><style>body{margin:0}</style></helmet>
<div style="width: 390px; height: 844px; position: relative; overflow: hidden;">
<x-import component-from-global-scope="HermesUI.HermesProvider" platform="apple" fill="{{yes}}">
<x-import component-from-global-scope="HermesUI.SettingsScaffold" title="Logs" subtitle="default · newest first"
  back-label="Server" on-back="{{noop}}" actions="{{barActions}}" tabs="{{tabs}}" active-tab="{{zero}}" search="{{search}}">
<x-import component-from-global-scope="HermesUI.GroupedListView">
 <x-import component-from-global-scope="HermesUI.GroupedSection" header="Hermes" footer="…">
  <x-import component-from-global-scope="HermesUI.GroupedRow" title="Disk" value="38 GB free" subtitle="62% used" chevron="{{no}}"></x-import>
 </x-import>
 <x-import component-from-global-scope="HermesUI.StateMessage" icon="search_off" title="No lines match" detail="…" action="{{clear}}"></x-import>
</x-import></x-import></x-import></div></x-dc>
<script type="text/x-dc" data-dc-script data-props='{"$preview":{"width":390,"height":844}}'>
class Component extends DCLogic { renderVals() { const noop = () => {};
 return { yes: true, no: false, zero: 0, noop, tabs: ['Errors','Agent','Gateway'],
  search: { hint: 'Search these logs', query: 'telegram' },
  barActions: [{ icon: 'refresh', label: 'Refresh', onClick: noop },
               { icon: 'more_horiz', label: 'More', menu: [{ label: 'Copy shown lines', icon: 'content_copy' }] }],
  clear: React.createElement(window.HermesUI.Button, { variant: 'outlined' }, 'Clear filters') }; } }
</script></body></html>
```

- Pass booleans, numbers, arrays, objects and functions as `{{holes}}`
  returned by `renderVals()`. Write attribute names in kebab-case (`on-back`,
  `full-width`, `type-ramp="default"` for a Mac).
- Use `platform="material"` for Android. Pass `device="mac"` on SettingsScaffold
  and GroupedListView for a Mac.
- To show an alert over another artboard, mount that artboard as the background
  inside the provider, then add the alert after it:
  `<div style="position:relative;width:390px;height:844px;overflow:hidden"><dc-import name="UpdatePage" hint-size="390px,844px"></dc-import><x-import component-from-global-scope="HermesUI.AlertDialog" title="…" message="…" actions="{{actions}}"></x-import></div>`
  with `actions: [{label: 'Cancel', isDefault: true}, {label: 'Update'}]`.
- Anything the design system lacks (a headline card, a step list, a chart, a
  log line) is plain markup using `var(--h-*)` tokens only, never hex. List each
  one under "New components needed" in the hand-back.

### 3. Publish updates

- New artboard: Write the file, then in the same message call
  `Artifact {url, root: "S/canvas", file_path: "<abs path of the file>"}`. Write
  one file and publish it before writing the next.
- Small change: `Artifact {url, root: "S/canvas", file_path: <abs>, edits: [{old_str, new_str}]}`.
  `old_str` must match the formatted file exactly; find it with Grep first.
  Several file publishes can go in one message; they run in order.
- Change to `canvas.json`: use `edits` too. Inside JSON strings use `'` rather
  than unescaped `"`, or the file stops being valid JSON and the edit is refused.

### 4. Render locally (headless Chrome)

Needs a Chrome binary (`google-chrome`, or `/opt/pw-browsers/chromium` in a
cloud session) and ImageMagick `montage` on PATH. If either is missing, skip
this section and say in the hand-back that nothing was rendered locally.

1. Ask the Artifact tool to read the canvas with `paths`:
   `artifact-type/dc-runtime.js`, `project/ds/hermesui/_ds_bundle.js`,
   `project/ds/hermesui/_ds_bundle.css`, `project/ds/hermesui/styles.css`,
   `project/ds/hermesui/fonts/fonts.css`,
   `project/ds/hermesui/fonts/CupertinoIcons.ttf`. Each lands under
   `S/artifact-files/<artifact id>/<path>`; call that folder `A`.
2. Copy and wire it up:
   ```
   mkdir -p $S/render $S/shots && cp -r $S/canvas/project $S/render/
   cp $A/artifact-type/dc-runtime.js $S/render/project/support.js
   mkdir -p $S/render/project/ds/hermesui && cp -r $A/project/ds/hermesui/. $S/render/project/ds/hermesui/
   ```
   The runtime bundles React and boots `<x-dc>`.
3. Serve it in the background (`dc-import` fetches its files over HTTP):
   `cd $S/render/project && python3 -I -m http.server 8765 --bind 127.0.0.1`
4. List each board's size, then render each one:
   ```
   python3 -I -c "import json;d=json.load(open('canvas.json'))
   for k in d['order']: b=d['boards'][k]; print(k,b['w'],b['h'])" > $S/boards.txt
   while read f w h; do timeout 60 google-chrome --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
     --virtual-time-budget=8000 --window-size=$w,$h --screenshot=$S/shots/${f%.dc.html}.png \
     http://127.0.0.1:8765/$f >/dev/null 2>&1; done < $S/boards.txt
   ```
5. Make contact sheets and look at them:
   `montage a.png b.png -tile 4x1 -geometry 390x844+8+8 -background gray50 $S/shots/sheet1.png`.
   After a fix, copy the changed file into `$S/render/project/` and render again.
   Stop the server with `pkill -f "http.server 8765"`.

This harness does not replace a look at the canvas in the claude.ai viewer.
Say so in the report.

## Defects the pass has found

- **Short values.** `GroupedRow` cuts a value off at half the row. Keep the
  value short and put the rest in the subtitle (Disk: value "38 GB free",
  subtitle "62% used"). A long state becomes the subtitle with no value.
- **Template whitespace.** The formatter indents text inside elements, so
  `white-space: pre-wrap` on a `{{hole}}` shows stray indents. Use
  `white-space: normal` for messages. For multi-line monospace text (tracebacks)
  render one line per element with `<sc-for>`, with `pre-wrap` on each.
- **Narrow segmented controls.** In a flex-wrap row, `SegmentedControl
size="inline"` shrinks and cuts its labels. Stack them on a phone; at desktop
  width use `display: grid; grid-template-columns: repeat(2, minmax(0, 1fr))`.
- **Stray icons.** Do not give one row of a section a leading icon when the
  others have none; the titles go out of line.
- **Hand-made rows behind an alert.** A `<button style="all: unset">` row drew
  blank inside a `dc-import` background behind a dimmed alert. Use real
  components for anything an alert's background shows, or accept the blank and
  say so.
- Check contrast against `_ds_bundle.css`. In light mode the warning colour
  `#92400e` and muted text `#6b6b74` pass AA on white.

## Settled design rules

These apply to every screen. Do not reopen them in a pass; put an exception in
the brief with its reason.

- **Lost answers.** Every "checking" or lost-answer state ends within 10 s with
  "Couldn't confirm…". The action is offered again, and nothing is resent
  automatically.
- **Destructive actions.** No filled button for a destructive or removing
  action. Cancel is the default.
- **Android confirmations** are two text buttons, Cancel first.
- **Target sizes.** Mac pointer targets are at least 28 pt. Touch targets are
  at least 44 pt (48 dp on Android).
- **Status is never colour alone.** Pair a colour with an icon and a word.
- **Text size.** Honour the selected text size with no cap. Check the largest
  size.
- **Secret fields** follow the "Secret fields" paragraph in
  `docs/architecture/settings-screens.md` (use `SecretFieldRow`,
  `lib/src/widgets/secret_field_row.dart`, once it has landed; until then
  follow the rule and say in the brief which widget you assume). Point to it;
  do not restate it.
- **Reuse the shared widgets** in `lib/src/widgets/` instead of drawing new
  copies. Today: `SettingsScaffold`, `GroupedList` and its rows
  (`grouped_list.dart`, `grouped_choice_row.dart`, `grouped_form.dart`,
  `grouped_dialog.dart`), `StateMessage`, `BusyBar`, `DisclosureTile`,
  `NamedIconButton`, `NamedPopupMenuButton`, `AdaptiveTabBar`,
  `AdaptiveDialog` and `AdaptiveSheet`, `AdaptivePickers`,
  `AdaptiveBackButton`, `SettingsSearchField`, `ContentColumn`,
  `InspectorLayout`, `RowActions`, `AppBanner` (the "Banner" of the wave 4
  design records; Material owns the name `Banner`). Run `ls lib/src/widgets/` for the current
  list. A new piece goes under "New components needed" and gets built once.

## Record it

The design record lives in the repo, not in the canvas or a chat.

- `openspec/changes/<change>/design.md`: the facts and states, and a short
  note on any decision that changes behaviour.
- `docs/design-briefs/<change>.md`: a "Design (done)" section at the top with
  the canvas link (private, ask its owner for access), the artboard count and
  list, the decisions taken, the corrections where the brief did not work, and
  the copy the design added. Bring the rest of the brief in line with the
  canvas. `docs/design-briefs/server-care.md` is the model.

A design-only PR leaves `docs/roadmap.md` to the orchestrator. Report any item
whose status your change moves.

## Hand-back report

- The canvas URL.
- Every artboard, grouped by row.
- Decisions where the brief left a choice open, one line each.
- New components needed: name, what it is, the closest existing component.
- Where the brief did not work, and what you did instead.
- Copy you added.
- Which artboards you checked by rendering, and how.
- What you could not check (the claude.ai viewer, real devices).
- Any component props you guessed and did not confirm.
- If you changed the repo: branch, head sha, PR link, and the result of
  `openspec validate <change> --strict`.
