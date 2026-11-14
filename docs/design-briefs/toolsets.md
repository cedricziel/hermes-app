# Design brief: Tools

Change: `openspec/changes/toolsets/`. Read its design.md for the server facts; this brief is the visual and copy pass.

## The job

"I want to know what Hermes is allowed to do for this profile, switch something on or off, and get a tool working that says it needs setup." Every screen serves one of those three and nothing else.

## Kit to reuse

`SettingsScaffold` (iOS 44 pt bar, macOS `MacToolbar`, Material 56 dp), `GroupedListView`, `GroupedSection`, `GroupedRow`, `GroupedSwitchRow`, `SettingsSearchField` (not needed: the list is short), `adaptive_sheet.dart` (sheets, dialogs), the platform alert used for sign-out confirmation, `PillSegmentedControl` (not needed), the install progress look of Bot Screen's Install on Server, the masked field of the MCP install panel, `AdaptiveMenuItem`. No new component unless listed below. The sibling screens are Skills, Plugins, MCP servers and Helper models; Tools must be indistinguishable in chrome.

New plain-model widgets: `ToolsetRow` (switch row with sentence and state), `StatusChip` (icon + text), `ProviderRow` (radio), `SecretField`, `InstallProgress`, `RiskNote`.

## Screen 1: Tools (list)

Purpose: see what the profile can use and what is not working yet.

- Title "Tools". Subtitle "work · 5 on" (profile name · count on). Bar action: none. Footer link "What's the difference?".
- Sections in this order, empty ones omitted: "Needs setup", "On", "Off".
- Row: name (bold), one sentence (secondary, wraps, up to three lines), meta "5 tools". A switch at the trailing edge. A "Needs setup" row adds a warning line "Needs setup" with icon, not colour alone. A risky toolset (see below) adds a small "Can change things" note with an icon under the sentence. Tapping the row (not the switch) opens the detail.
- Hierarchy: name, sentence, then state. The switch is the primary action; there is no other.
- Footer (below the last section): "Switching a tool on or off applies from your next chat. A chat that is already open keeps the tools it started with." then the link.

Sentences (sentence case, no jargon):

| Name | Sentence |
| --- | --- |
| Web search and scraping | Look things up on the web and read pages. |
| Browser | Open web pages, click and type in them. |
| Terminal | Run commands on the machine where Hermes runs. |
| Files | Read, create and change files on that machine. |
| Code execution | Write and run programs on that machine. |
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
- Permission denied (server answers 403): "You can't change tools on this server." and the switches disabled.
- A write in flight: the row's switch shows a small progress and is disabled; a lost answer: row caption "May have changed. Checking…".

iPhone: a normal grouped list, large title collapsing as in Skills. iPad and wide windows: list left, detail right from 900 pt. Mac: `MacToolbar` with back and title, no bottom sheets; the detail is the right pane, and below 900 pt a pushed page; ⌘[ goes back; arrow keys move in the list, Space toggles the focused switch.

## Screen 2: Tool detail

Purpose: understand one tool, get it working.

Order of content:

1. Header: name, the sentence, the switch.
2. State line: "On", "Off" or "On · needs setup" with icon.
3. "What it lets Hermes do": for risky toolsets, the sentence in a bordered note with an icon ("Can change things on your server"), see the table. Other toolsets show nothing here.
4. Set up (when it needs setup; "Change setup" when it has providers and is already set up): see screens 3 to 6.
5. "Where it applies": "Used in your chats in this app and in the terminal." or "Used in Discord chats only."
6. "Tools in this group (5)", collapsed: the tool names in a monospace list, and the helper line "These are the names you see on tool cards in a chat."

Primary action: the switch, or, when the toolset needs setup, "Set up" which scrolls to and expands section 4. Destructive: none (nothing is deleted). Mac: right pane, same content, no sheet.

## Confirmations (platform alert; dialog on Mac and wide windows)

Switch on, risky toolsets. Cancel is the default and left.

- Terminal: title "Let Hermes run commands?", body "It can run commands on the machine where Hermes runs. It applies to work. You can switch it off again here.", buttons "Cancel", "Switch on".
- Code execution: "Let Hermes run programs?", "It can write and run programs on the machine where Hermes runs. It applies to work. You can switch it off again here."
- Computer use: "Let Hermes control a computer?", "It can see a desktop's screen and move its mouse and keyboard. It applies to work. You can switch it off again here."
- Local backend: "Run commands directly on your server?", "Commands will run on the same machine as Hermes, not in a container.", "Cancel", "Use local".
- Install: "Install on your server?", "Hermes will run an installer on the server. It may download software.", "Cancel", "Install".
- Computer use permission: "Allow access on the server's Mac?", "A permission window will open on the computer that runs Hermes. Someone there has to approve it.", "Cancel", "Allow access".

The confirm button is not red (nothing is deleted) but is the non-default action; red is kept for destructive actions elsewhere in the app.

## Screen 3: Set up, provider

Purpose: choose where the tool gets its capability from.

- Section "Set up" with the footer "Hermes uses the one you choose. Applies from your next chat."
- Radio rows: provider name, tag below ("Search and extract"), badge as a small pill ("paid", "free"), status chip right: "Ready", "Needs a key", "Needs a sign-in on the server", "Needs install", otherwise "Needs setup". Selected row has a check.
- Needs-sign-in note under the row when relevant: "This needs a sign-in to Nous Portal on your server. The app can't do that for you."
- Web only: an "Advanced" disclosure "Use different providers for search and extract" opening two radio groups, "Search" and "Extract".
- States: loading "Loading setup…"; failure "Couldn't load setup." and "Try again"; nothing to set up "Nothing to set up."

## Screen 4: Set up, keys

Purpose: give the chosen provider what it needs, safely.

- For each key: label from the server (for example "Firecrawl API key"), a masked field, below it a "Get a key" link (external browser). When already saved: "Already set" with a "Replace" button instead of the field.
- Primary button "Save". Helper line under the fields: "Saved on your server for work. The app doesn't keep it."
- After saving: fields empty, a banner "Saved. Applies from your next chat." Failure: "Couldn't save the key. Type it again." Lost answer: "May have saved. Checking…".
- Removing a key: a quiet line "To remove a key, edit it on your server."
- Secrets are masked, never shown in the app switcher, and cleared when the app goes to the background.

## Screen 5: Install on server and model

- Install row "Install on server" (button, secondary) with the helper "Needed before this works." After confirm: a progress block "Installing on your server…" with the last six log lines in a monospace box (text selectable, scrollable), a live region for screen readers. Done: "Installed." Failed: "The install didn't finish." with the lines and "Try again". Unknown: "Couldn't tell whether it finished." Another install running: button disabled "Another install is running".
- Switch-started install: the same block with "Hermes is installing the driver on your server."
- Model row (image and video generation): "Model" with the current model as value; opens a list (sheet on phone, popover on Mac): name, then speed and strengths as a second line, price at the trailing edge, the default marked "Default".

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
