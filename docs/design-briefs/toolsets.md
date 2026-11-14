# Design brief: Tools

Change: `openspec/changes/toolsets/`. Read its design.md for the server facts; this brief is the visual and copy pass.

## Design (done)

Claude Design canvas "Hermes: Toolsets", built on the Hermes App design system: https://claude.ai/artifact/KsLQJVL4D6Xo3PGdgxC7AL (private; ask its owner for access). 39 artboards in five rows:

- Tools list on iPhone: grouped list, all on, loading, empty, couldn't load, offline, old server, "What's the difference?" sheet.
- Switching a tool: saving, failed and rolled back, not allowed, answer lost (checking), the Terminal confirmation, switched on with an installer started.
- Tool detail and setup: Web needing setup with a key typed, key saved, key save failed, key save answer lost, a provider that needs a sign-in on the server (with Advanced open), setup loading, setup couldn't load, Image generation (already set up) and its model picker.
- Terminal and Computer use: Terminal with "Where commands run", the Local confirmation, Computer use missing a permission, the Allow access confirmation, driver missing, the install confirmation, installing, install failed.
- Dark, largest text, iPad, Mac, Android: list and Web detail in dark, the list at the largest text size, iPad list beside Terminal, Mac list beside Web, Android list, Terminal detail and confirmation.

Where this brief and the canvas differ, the sections below have been brought in line with the canvas.

Decisions taken in the design pass:

- Row (`ToolsetRow`): name (semibold), the sentence (muted, up to three lines), then the risk line "Can change things" with a shield icon (in the text colour, not a warning colour), then "Needs setup" with a filled warning triangle in the warning colour, then the action count ("2 actions", "1 action") as a caption. The switch sits at the trailing edge, centred on the row. The text part is one link that opens the detail; the switch is its own control and the row's only action.
- The risk line shows for both risk levels (confirm and explain, design.md's risk table); only the confirm level asks.
- A switch moves at once, dims and shows a 16 pt spinner beside it while the write is out, but the row keeps its group until Hermes confirms and the list is read again. Rows never jump between groups under the finger.
- A failed write rolls the switch back and puts the message on that row, as an error line with the error glyph ("Couldn't change Memory. Try again.", "You can't change tools on this server."). A lost answer replaces the action count with "May have changed. Checking…" and a spinner, the switch disabled.
- Page-level problems are a `Banner` above the groups with Try again: "Couldn't load tools." (error) and "You're offline." (warning, cloud icon); the rows already loaded stay. A switch-started installer is a success banner "Computer use is on." with "Hermes started an installer on your server. Applies from your next chat." and a Show button that opens the detail.
- Loading is a centred spinner with "Loading tools…" under the bar; empty and old server use `StateMessage` (old server with an outlined Back).
- Detail header (`ToolsetHeader`): a card with the name as the page heading (22 pt semibold, wraps), the switch beside it, the sentence, and the state line with an icon: "On" (filled check, success colour), "Off" (empty circle, muted), "On · needs setup" (warning triangle, warning colour). The bar title is the name too; the bar truncates a long name, the header shows it in full.
- No separate "Set up" button: when a toolset needs setup, the Set up section is open directly under the header (and risk note), so the key form's Save is the screen's one filled button. When the toolset is set up, "Change setup" is a collapsed row with the active provider as its value.
- Risk note (`RiskNote`): a card with a 1 pt border in the text colour, a shield icon, a bold title and the plain sentence, placed before anything the user can change. Confirm-level toolsets add "Hermes asks before you switch it on." Titles: "Can change things on your server" (terminal, code execution, files, computer use), "Can act on web pages for you" (browser), "Can act on its own" (scheduled tasks, delegation), "Can change your Discord server" (Discord admin).
- Provider and backend rows (`ProviderRow`): a radio row with the name and its badge ("paid", "subscription") as an outlined tag, the tag line ("Search and extract") or description muted under it, the status chip on its own line under that, then any note ("This needs a sign-in to Nous Portal on your server. The app can't do that for you.", "From Hermes: …", the warning "Commands will fail until this is set up on your server."). Apple: a check mark in the link colour at the trailing edge of the picked row. Material: a leading radio.
- Status chips (`StatusChip`) are the kit's badge with an icon: Ready (check, success), Needs a key (key, warning), Needs a sign-in on the server (sign-in arrow, warning), Needs install (download, warning), Needs setup (warning, warning), Can't be used (block, neutral).
- Web's "Advanced" is the last row of the Set up section, titled "Use different providers for search and extract"; opened, it shows two choice sections "Search" and "Extract" with the footer "Most people use one provider for both."
- Keys (`SecretField`): a section headed "Key for <provider>" holding the kit's text field with the server's label, obscured, then the helper, "Get a key" (link colour, external-link icon, 44 pt tall), the full-width filled Save and the quiet "To remove a key, edit it on your server." There is no show/hide control: the key is pasted, and a value that can be revealed can be captured on screen. When saved: "Firecrawl API key" with "Already set" (success check) and a compact outlined Replace. After a failed save the field is empty, shows the error under it and Save is disabled until something is typed. A lost answer replaces Save with a spinner and "May have saved. Checking…".
- Install (`InstallProgress`): a section "Install on server" with a spinner and the title, one muted line ("You can leave this screen. The install keeps going."), the last six log lines as separate selectable monospace lines in a surface-high box, and, after a failure, a full-width filled Try again. "Install on server" is the filled main button (download icon) when the toolset does not work without it, with the helper "Needed before this works. Hermes asks before it runs anything."
- Computer use readiness (`ReadinessRow`): label left, the value right with a filled icon: check in the success colour ("macOS, supported", "Installed", "Allowed"), a cross in the warning colour and semibold ("Not installed", "Not allowed", "No"), a question mark muted ("Couldn't tell"). "Details" is the section's last row. "Allow access" is a full-width filled button (open-lock icon) under the section, with "A permission window opens on the Mac that runs Hermes. Someone there has to approve it."
- Model picker: a bottom sheet titled "Model" with Done, rows from the kit's choice row: name, "Default" as muted meta after it, and speed, strengths and price on the second line. The footer says "Prices are per image and come from the provider, FAL. Applies from your next chat."
- "What's the difference?" is a bottom sheet (popover on a Mac) with the title, Done, and the four terms bold at the start of each paragraph.
- Confirmations are the platform alert with Cancel first and the default; the confirming action is plain, never red. Android uses the Material dialog with the same words.
- Largest text: rows stack; the switch moves under the text on its own line with the state in words ("On", "Off") before it.
- iPad from 900 pt: the list (420 pt) left with the selected row filled in the border colour, the detail right without a Back button. Mac: the same two panes, 13 pt rows and the small switch.

Corrections where this brief did not work:

- "Set up" as the primary action of a detail that needs setup made two filled buttons with the key form's Save. The section opens in place instead (see above).
- The status chip at the trailing edge of a provider row collides with the check mark and does not fit "Needs a sign-in on the server" at phone width; it sits under the tag line.
- The model's price at the trailing edge collides with the check mark; it ends the second line instead, and "per image" moved to the footer so the line fits.
- `StatusChip` is not a new look: it is the kit's badge with an icon, wrapped so the status-to-icon-and-word mapping lives in one place.
- The list row's state: the spec's "On · needs setup" is the detail's state line; the row shows the switch and the "Needs setup" line, which already say both.
- One more widget than listed: `ReadinessRow` (Computer use), and the header card `ToolsetHeader`.

Copy added by the design: "Hermes can run any command on the machine where Hermes runs, with that machine's permissions. Hermes asks before you switch it on." (Terminal risk note); "Hermes can see the screen of the computer that runs Hermes and use its mouse and keyboard. Switch it on only for a profile you trust with that." (Computer use risk note); "The list below may be out of date." (error banner); "Couldn't load tools. Switches show what was last saved." (offline banner); "Computer use is on." and "Show" (installer banner); "Tools Hermes offers for this profile will show here." (empty); "Updating Hermes on the server adds them." (old server); "Key for <provider>" (section header); "Saved." (key banner title); "Applies from your next chat. Settings for Docker, SSH and the others are changed on your server." (Where commands run footer); "You can leave this screen. The install keeps going."; "Nothing changed on your server. The last lines from the installer:"; "Needed before this works. Hermes asks before it runs anything."; "Most people use one provider for both."; readiness rows "Server system", "Driver", "Ready" with "macOS, supported", "Installed", "Not installed", "Couldn't tell".

## The job

"I want to know what Hermes is allowed to do for this profile, switch something on or off, and get a tool working that says it needs setup." Every screen serves one of those three and nothing else.

## Kit to reuse

`SettingsScaffold` (iOS 44 pt bar, macOS `MacToolbar`, Material 56 dp), `GroupedListView`, `GroupedSection`, `GroupedRow`, `GroupedSwitchRow`, `SettingsSearchField` (not needed: the list is short), `adaptive_sheet.dart` (sheets, dialogs), the platform alert used for sign-out confirmation, `PillSegmentedControl` (not needed), the install progress look of Bot Screen's Install on Server, the masked field of the MCP install panel, `AdaptiveMenuItem`. No new component unless listed below. The sibling screens are Skills, Plugins, MCP servers and Helper models; Tools must be indistinguishable in chrome.

New plain-model widgets: `ToolsetRow` (switch row with sentence and state), `ToolsetHeader` (detail header card), `StatusChip` (the kit's badge with icon and text), `ProviderRow` (radio with status and notes, also used for terminal backends), `SecretField`, `InstallProgress`, `RiskNote`, `ReadinessRow`. The design pass settled each (see "Design (done)").

## Screen 1: Tools (list)

Purpose: see what the profile can use and what is not working yet.

- Title "Tools". Subtitle "work · 5 on" (profile name · count on). Bar action: none. Footer link "What's the difference?".
- Sections in this order, empty ones omitted: "Needs setup", "On", "Off".
- Row: name (bold), one sentence (secondary, wraps, up to three lines), meta "5 actions". A switch at the trailing edge. A "Needs setup" row adds a warning line "Needs setup" with icon, not colour alone. A risky toolset (see below) adds a small "Can change things" note with an icon under the sentence. Tapping the row (not the switch) opens the detail.
- Hierarchy: name, sentence, then state. The switch is the primary action; there is no other.
- Footer (below the last section): "Switching a tool on or off applies from your next chat. A chat that is already open keeps the tools it started with." then the link.

Sentences (sentence case, no jargon):

| Name | Sentence |
| --- | --- |
| Web search and scraping | Look things up on the web and read pages. |
| Browser | Open web pages, click and type in them. |
| Terminal | Run commands on the machine where Hermes runs. |
| Files | Read, create and change files on the machine where Hermes runs. |
| Code execution | Write and run programs on the machine where Hermes runs. |
| Image analysis | Look at pictures and describe them. |
| Video analysis | Watch videos and describe them. |
| Image generation | Make pictures from a description. |
| Video generation | Make short videos from a description. |
| X search | Search posts on X. |
| Text to speech | Read answers aloud. |
| Speech to text | Turn voice messages into text. |
| Skills | Find and use the skills you have. |
| Task planning | Keep a to-do list while working. |
| Kanban | Use the task board. |
| Memory | Remember things between chats. |
| Context engine | Use the add-on that manages long chats. |
| Session search | Search your past chats. |
| Connections | Use accounts you have connected. |
| Clarifying questions | Ask you a question when something is unclear. |
| Delegation | Start helper agents that work on their own. |
| Scheduled tasks | Create tasks that run later without you. |
| Discord | Read and join Discord conversations. |
| Discord admin | Manage a Discord server's channels and roles. |
| Computer use | See a desktop's screen and move its mouse and keyboard. |

Names not in the table: the server's label and description as given.

States:

- Loading: the section area shows "Loading tools…" with a progress indicator (skeleton rows are fine on desktop).
- Empty: "This profile has no tools to set up." No action.
- Error: "Couldn't load tools." with "Try again". Rows already loaded stay.
- Offline: the same as error, with "You're offline." as its first line.
- Old server: the entry does not exist; if the screen was open, "This server doesn't offer tools settings." and Back.
- Not allowed (a write answers 401 or 403): "You can't change tools on this server." and the switch returns.
- A write in flight: the row's switch shows the new position, a small progress beside it, and is disabled; the row stays in its group until the list is read again; a lost answer: row caption "May have changed. Checking…".

iPhone: a normal grouped list, large title collapsing as in Skills. iPad and wide windows: list left, detail right from 900 pt. Mac: `MacToolbar` with back and title, no bottom sheets; the detail is the right pane, and below 900 pt a pushed page; ⌘[ goes back; arrow keys move in the list, Space toggles the focused switch.

## Screen 2: Tool detail

Purpose: understand one tool, get it working.

Order of content:

1. Header: name, the sentence, the switch.
2. State line: "On", "Off" or "On · needs setup" with icon.
3. "What it lets Hermes do": for risky toolsets, the sentence in a bordered note with an icon ("Can change things on your server"), see the table. Other toolsets show nothing here.
4. Set up (when it needs setup; "Change setup" when it has providers and is already set up): see screens 3 to 6.
5. "Where it applies": "Used in your chats in this app and in the terminal." or "Used in Discord chats only."
6. "What's inside (5)", collapsed: the tool names in a monospace list, and the helper line "These are the names you see on tool cards in a chat."

Primary action: the switch. When the toolset needs setup, section 4 is open under the header and its Save is the one filled button (no separate "Set up" button; see "Design (done)"). Destructive: none (nothing is deleted). Mac: right pane, same content, no sheet.

## Confirmations (platform alert; dialog on Mac and wide windows)

Switch on, risky toolsets. Cancel is the default and left.

- Terminal: title "Let Hermes run commands?", body "It can run commands on the machine where Hermes runs. It applies to work. You can switch it off again here.", buttons "Cancel", "Switch on".
- Browser: "Let Hermes use a browser?", "It can open web pages, click and type in them, and may install a browser on the server. It applies to work. You can switch it off again here.", "Cancel", "Switch on".
- Code execution: "Let Hermes run programs?", "It can write and run programs on the machine where Hermes runs. It applies to work. You can switch it off again here."
- Computer use: "Let Hermes control a computer?", "It can see a desktop's screen and move its mouse and keyboard. It applies to work. You can switch it off again here."
- Local backend: "Run commands directly on your server?", "Commands will run on the same machine as Hermes, not in a container.", "Cancel", "Use local".
- Install: "Install on your server?", "Hermes will run an installer on the server. It may download software.", "Cancel", "Install".
- Computer use permission: "Allow access on the server's Mac?", "A permission window will open on the computer that runs Hermes. Someone there has to approve it.", "Cancel", "Allow access".

The confirm button is not red (nothing is deleted) but is the non-default action; red is kept for destructive actions elsewhere in the app.

## Screen 3: Set up, provider

Purpose: choose where the tool gets its capability from.

- Section "Set up" with the footer "Hermes uses the one you choose. Applies from your next chat."
- Radio rows: provider name, tag below ("Search and extract"), badge as a small pill ("paid", "free"), status chip on its own line under the tag: "Ready", "Needs a key", "Needs a sign-in on the server", "Needs install", otherwise "Needs setup". Selected row has a check.
- Needs-sign-in note under the row when relevant: "This needs a sign-in to Nous Portal on your server. The app can't do that for you."
- Web only: an "Advanced" disclosure "Use different providers for search and extract" opening two radio groups, "Search" and "Extract".
- States: loading "Loading setup…"; failure "Couldn't load setup." and "Try again"; nothing to set up "Nothing to set up."

## Screen 4: Set up, keys

Purpose: give the chosen provider what it needs, safely.

- For each key: label from the server (for example "Firecrawl API key"), a masked field (no show/hide control), below it a "Get a key" link (external browser). When already saved: "Already set" with a "Replace" button instead of the field.
- Primary button "Save". Helper line under the fields: "Saved on your server for work. The app doesn't keep it."
- After saving: fields empty, a banner "Saved. Applies from your next chat." Failure: "Couldn't save the key. Type it again." Lost answer: "May have saved. Checking…".
- Removing a key: a quiet line "To remove a key, edit it on your server."
- Secrets are masked, never shown in the app switcher, and cleared when the app goes to the background.

## Screen 5: Install on server and model

- Install row "Install on server" (the filled main button when the tool does not work without it; under "Advanced" as "Run the install step again" otherwise) with the helper "Needed before this works. Hermes asks before it runs anything." After confirm: a progress block "Installing on your server…" with the last six log lines in a monospace box (text selectable, scrollable), a live region for screen readers. Done: "Installed." Failed: "The install didn't finish." with the lines and "Try again". Unknown: "Couldn't tell whether it finished." Another install running: button disabled "Another install is running".
- Switch-started install: the same block with "Hermes is installing the driver on your server."
- Model row (image and video generation): "Model" with the current model as value; opens a list (sheet on phone, popover on Mac): name with "Default" after it for the default, then speed, strengths and price as a second line, the current one checked.

## Screen 6: Terminal, where commands run

- Section "Where commands run" in the Terminal detail, radio rows: label, description, chip "Ready", "Needs setup", "Can't be used". For a backend that is not ready: "From Hermes:" followed by its text, and when picked, "Commands will fail until this is set up on your server."
- Primary action: picking a row. Local asks first (see Confirmations).
- States: loading "Checking where commands can run…", failure "Couldn't read where commands run." and "Try again".

## Screen 7: Computer use readiness

- Section "Readiness": rows with icon + text, not colour alone: "Server system: supported", "Driver: installed" (or "Not installed" with "Install on server"), "Ready: yes / no / couldn't tell". On a Mac server: "Accessibility: allowed / not allowed", "Screen recording: allowed / not allowed". "Details" disclosure with the checks. Error line under it when Hermes sent one.
- "Allow access" button when something is missing on a Mac server.
- "Open the bot's screen" row (chevron) only when the profile has one; it opens the live view that exists today. Nothing else about the screen is built here.
- Helper line: "This tool drives a computer's desktop. Switch it on only for a profile you trust with that."

## What's the difference?

Sheet on iPhone and iPad, popover on Mac, title "Tools, skills, plugins and MCP servers", four rows (term bold, one sentence):

- Tools: what Hermes can do by itself, such as run commands, search the web or make images. You switch them on or off here.
- Skills: written instructions Hermes follows for a kind of job.
- Plugins: add-ons installed on the server. Some bring their own tools.
- MCP servers: outside programs or services that give Hermes extra tools.

Close button "Done". The same link, "What's the difference?", is the last line of the footer on Skills, Plugins, MCP servers and Helper models.

## Platform differences

- iPhone: pushed pages, large title, alerts for confirmations, keyboard avoids the key field, no pane.
- iPad and desktop widths (900 pt): list and detail panes; confirmations as dialogs; the key form in the detail pane.
- Mac: `MacToolbar`, hover states on rows, Space toggles, ⌘[ back, popovers instead of sheets, no bottom sheets anywhere.
- Android: Material 3 bar and switch, back gesture pops the detail, dialogs for confirmations.

## Accessibility

44 pt / 48 dp targets, text wraps at the largest size, chips have text and icon, switch label "<name>, on/off", progress and results are announced, reduced motion removes the progress animation, focus order list then detail, contrast AA in both themes.
